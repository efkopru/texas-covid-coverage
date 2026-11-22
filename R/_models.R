# _models.R -- model definitions shared by the fitting and validation scripts.
#
# Outcome model (county i, interval k of length d_k days)
#
#   y_ik ~ Binomial(n_ik, pi_ik)
#   cloglog(pi_ik) = log(d_k / 30) + eta_ik
#   eta_ik = a + b_age * age_i + b_inc * income_i + b_case * cases_ik
#            + g_k + c_i + [county-specific trajectory] + e_ik
#
#   y_ik  new first-dose recipients aged 16+ recorded in the interval
#   n_ik  residents aged 16+ not yet recorded as vaccinated at its start
#   exp(eta_ik) is the uptake hazard per 30 days; 1 - exp(-exp(eta_ik)) is the
#   share of the remaining unvaccinated adults vaccinated per 30 days.
#
#   g_k   shared time effect: first-order random walk on the interval midpoints
#   c_i   county effect: independent (M0) or BYM2 (M1-M4)
#   e_ik  county-interval deviation (independent normal), which also absorbs
#         extra-binomial variation
#   M2    adds a county-specific linear slope in time
#   M3    adds a county-specific random walk in time, constrained to sum to
#         zero within each county (Knorr-Held type II interaction)
#   M4    adds a county-specific mean-reverting process in continuous time
#         (Ornstein-Uhlenbeck: correlation exp(-phi * months apart))
#
#   Every time effect is indexed by the interval midpoint in months, not by the
#   interval number, so the unequal spacing of the intervals is respected:
#   R-INLA's rw1 gives an increment over a gap of d months the variance d / tau,
#   and the Ornstein-Uhlenbeck correlation depends on the months apart.
#
# Priors: penalised-complexity priors, P(sd > 1) = 0.01 for every standard
# deviation (log-hazard scale); BYM2 mixing parameter P(phi < 0.5) = 2/3;
# INLA defaults for fixed effects (normal, mean 0, precision 0.001; flat
# intercept) and for the log of the Ornstein-Uhlenbeck rate (normal, mean 0,
# precision 0.2).

suppressMessages({library(data.table); library(Matrix); library(INLA)})

INLA_THREADS <- Sys.getenv("TXCOV_THREADS", "6:1")
H_SD  <- list(prec = list(prior = "pc.prec", param = c(1, 0.01)))
H_BYM <- list(prec = list(prior = "pc.prec", param = c(1, 0.01)),
              phi  = list(prior = "pc", param = c(0.5, 2 / 3)))

# County adjacency as a sparse 0/1 matrix in FIPS order
build_graph <- function() {
  ed <- fread(file.path(DIR_DERIVED, "tx_adjacency_edges.csv"), colClasses = "character")
  fips <- sort(unique(c(ed$fips, ed$nb_fips)))
  W <- sparseMatrix(i = match(ed$fips, fips), j = match(ed$nb_fips, fips), x = 1,
                    dims = c(length(fips), length(fips)), dimnames = list(fips, fips))
  stopifnot(isSymmetric(W), inla.read.graph(W)$cc$n == 1)
  W
}

# Panel with the index columns the formulas use
load_panel <- function(file = "panel.csv") {
  d <- fread(file.path(DIR_DERIVED, file), colClasses = list(character = "fips"))
  for (v in c("start_asof", "end_asof", "data_from", "data_to", "mid")) set(d, j = v, value = as.Date(d[[v]]))
  setorder(d, fips, k)
  fips <- sort(unique(d$fips))
  d[, cid := match(fips, ..fips)]                  # county index 1..254
  d[, `:=`(cid2 = cid, cid3 = cid)]
  d[, tid := as.numeric(mid - min(start_asof)) / 30.4375]   # interval midpoint, months since baseline
  d[, tid2 := tid]
  d[, tc := (tid - mean(unique(tid))) / 12]        # centred time in years
  d[, oid := .I]
  d[, off := log(days / 30)]
  d[]
}

model_formula <- function(model, covars = c("z_age", "z_income", "z_cases"), W_name = "W") {
  rhs <- c("1", covars,
           "f(tid, model = 'rw1', scale.model = TRUE, constr = TRUE, hyper = H_SD)",
           "f(oid, model = 'iid', hyper = H_SD)",
           "offset(off)")
  county <- switch(model,
    M0 = "f(cid, model = 'iid', hyper = H_SD)",
    sprintf("f(cid, model = 'bym2', graph = %s, scale.model = TRUE, constr = TRUE, hyper = H_BYM)", W_name))
  extra <- switch(model,
    M2 = "f(cid2, tc, model = 'iid', hyper = H_SD)",
    M3 = "f(tid2, model = 'rw1', replicate = cid3, scale.model = TRUE, constr = TRUE, hyper = H_SD)",
    M4 = "f(tid2, model = 'ou', replicate = cid3, hyper = H_SD)",
    NULL)
  as.formula(paste("y ~", paste(c(rhs, county, extra), collapse = " + ")))
}

MODEL_LABELS <- c(M0 = "M0 non-spatial county effects",
                  M1 = "M1 BYM2 county effects",
                  M2 = "M2 BYM2 + county linear trends",
                  M3 = "M3 BYM2 + county random-walk trajectories",
                  M4 = "M4 BYM2 + county mean-reverting trajectories")

# Fit one model. `y` may contain NA for rows to be predicted.
# `inla_mode` and `control_inla` are left at R-INLA's defaults except in the
# sensitivity check of the approximation itself.
fit_model <- function(d, model, W, y = d$y_model, covars = c("z_age", "z_income", "z_cases"),
                      compute_scores = TRUE, inla_mode = NULL, control_inla = NULL) {
  dat <- as.data.frame(d)
  dat$y <- y
  environment(model_formula) <- environment()
  fm <- model_formula(model, covars)
  environment(fm) <- environment()
  a <- list(formula = fm, family = "binomial", Ntrials = dat$at_risk, data = dat,
            control.family = list(control.link = list(model = "cloglog")),
            control.predictor = list(compute = TRUE, link = 1),
            control.compute = list(config = TRUE, waic = compute_scores, dic = compute_scores, cpo = compute_scores),
            num.threads = INLA_THREADS, verbose = FALSE)
  if (!is.null(inla_mode)) a$inla.mode <- inla_mode
  if (!is.null(control_inla)) a$control.inla <- control_inla
  do.call(inla, a)
}

# Posterior summaries of standard deviations (from precisions) and other hyperparameters
hyper_table <- function(r) {
  out <- rbindlist(lapply(names(r$marginals.hyperpar), function(nm) {
    m <- r$marginals.hyperpar[[nm]]
    if (grepl("^Precision", nm)) {
      m <- inla.tmarginal(function(x) 1 / sqrt(x), m)
      nm <- sub("^Precision for", "SD of", nm)
    }
    q <- inla.qmarginal(c(0.025, 0.5, 0.975), m)
    data.table(parameter = nm, mean = inla.emarginal(function(x) x, m), q025 = q[1], median = q[2], q975 = q[3])
  }))
  out
}

fixed_table <- function(r) {
  f <- as.data.table(r$summary.fixed, keep.rownames = "term")
  f[, .(term, mean, sd, q025 = `0.025quant`, median = `0.5quant`, q975 = `0.975quant`)]
}

fit_stats <- function(r) {
  data.table(waic = r$waic$waic, p_waic = r$waic$p.eff, dic = r$dic$dic, p_dic = r$dic$p.eff,
             mean_log_cpo = mean(log(r$cpo$cpo), na.rm = TRUE),
             cpo_failures = sum(r$cpo$failure > 0, na.rm = TRUE),
             mlik = r$mlik[1, 1], seconds = as.numeric(r$cpu.used[["Total"]]))
}

# Joint posterior samples of the linear predictor (rows = panel rows, columns = draws).
# The linear predictor returned by INLA already contains the offset log(d/30).
sample_eta <- function(r, rows, n = 1000, seed = 20211022L) {
  s <- inla.posterior.sample(n, r, selection = list(Predictor = rows), seed = seed, num.threads = "1:1")
  vapply(s, function(z) z$latent[, 1], numeric(length(rows)))
}

cloglog_inv <- function(eta) -expm1(-exp(eta))            # 1 - exp(-exp(eta)), stable for small values
