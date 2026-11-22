# 06_fit_models.R -- fit the uptake models to the full panel and the
# initial-rollout coverage model to the baseline.
#
#   Rscript --vanilla R/06_fit_models.R
#
# Outputs (outputs/models/):
#   fit_statistics.csv, fixed_effects.csv, hyperparameters.csv
#   samples_<model>.rds      posterior draws used for every modelled quantity
#   baseline_*.csv, samples_baseline.rds

source("R/_common.R")
source("R/_models.R")
options(width = 200, scipen = 999)
set.seed(48)
N_DRAWS <- 1000

d <- load_panel("panel.csv")
W <- build_graph()
stopifnot(identical(rownames(W), sort(unique(d$fips))))
n_cty <- nrow(W); n_t <- d[, uniqueN(k)]
msg("Panel rows: %d; usable: %d; counties in likelihood: %d; intervals: %d", nrow(d), d[, sum(usable)],
    d[usable == TRUE, uniqueN(fips)], n_t)

# Optional argument: comma-separated models to (re)fit, e.g. "M4". Each model's
# summaries are stored on their own, and the combined tables are rebuilt from
# every model fitted so far.
args <- commandArgs(trailingOnly = TRUE)
todo <- if (length(args)) strsplit(args[1], ",")[[1]] else names(MODEL_LABELS)
stopifnot(all(todo %in% names(MODEL_LABELS)))

for (m in todo) {
  msg("Fitting %s", MODEL_LABELS[[m]])
  r <- fit_model(d, m, W)
  summ <- list(stats = cbind(model = m, label = MODEL_LABELS[[m]], fit_stats(r)),
               fixed = cbind(model = m, fixed_table(r)),
               hyper = cbind(model = m, hyper_table(r)))
  saveRDS(summ, file.path(DIR_MOD, sprintf("summary_%s.rds", m)))
  print(summ$stats); print(summ$fixed); print(summ$hyper)

  # Posterior draws: linear predictor, county-interval deviations, county
  # effects (total and spatially structured part), time effects, fixed effects.
  sel <- list(Predictor = 1:nrow(d), oid = 1:nrow(d), tid = 1:n_t,
              cid = if (m == "M0") 1:n_cty else 1:(2 * n_cty))
  for (v in rownames(r$summary.fixed)) sel[[v]] <- 1
  if (m == "M2") sel$cid2 <- 1:n_cty
  if (m %in% c("M3", "M4")) sel$tid2 <- 1:(n_cty * n_t)
  s <- inla.posterior.sample(N_DRAWS, r, selection = sel, seed = 20211022L, num.threads = "1:1")
  rn <- rownames(s[[1]]$latent)
  L <- vapply(s, function(z) z$latent[, 1], numeric(length(rn)))
  grab <- function(prefix) L[grepl(paste0("^", prefix, ":"), rn), , drop = FALSE]
  cid_draws <- grab("cid")
  draws <- list(model = m, fips = rownames(W), panel_key = d[, .(fips, k)],
                eta = grab("Predictor"),                       # includes offset log(days/30)
                eps = grab("oid"),
                gamma = grab("tid"),
                county = cid_draws[1:n_cty, , drop = FALSE],   # total county effect
                county_structured = if (m == "M0") NULL else cid_draws[(n_cty + 1):(2 * n_cty), , drop = FALSE],
                fixed = L[rn %in% paste0(rownames(r$summary.fixed), ":1"), , drop = FALSE],
                fixed_names = sub(":1$", "", rn[rn %in% paste0(rownames(r$summary.fixed), ":1")]),
                slope = if (m == "M2") grab("cid2") else NULL,
                traj = if (m %in% c("M3", "M4")) grab("tid2") else NULL,   # county by county, intervals within county
                hyper = vapply(s, function(z) z$hyperpar, numeric(length(s[[1]]$hyperpar))),
                hyper_names = names(s[[1]]$hyperpar))
  stopifnot(nrow(draws$eta) == nrow(d), nrow(draws$county) == n_cty)
  saveRDS(draws, file.path(DIR_MOD, sprintf("samples_%s.rds", m)), compress = "xz")
  rm(r, s, L, draws); gc()
}
done <- intersect(names(MODEL_LABELS), sub("^summary_(.*)[.]rds$", "\\1", list.files(DIR_MOD, pattern = "^summary_M[0-9][.]rds$")))
summ <- lapply(done, function(m) readRDS(file.path(DIR_MOD, sprintf("summary_%s.rds", m))))
fwrite(rbindlist(lapply(summ, `[[`, "stats")), file.path(DIR_MOD, "fit_statistics.csv"))
fwrite(rbindlist(lapply(summ, `[[`, "fixed")), file.path(DIR_MOD, "fixed_effects.csv"))
fwrite(rbindlist(lapply(summ, `[[`, "hyper")), file.path(DIR_MOD, "hyperparameters.csv"))
msg("Model summaries available for: %s", paste(done, collapse = ", "))
if (length(args)) quit(save = "no")     # a partial run stops here; the baseline model is fitted in a full run

# ---------------------------------------------------------------------------
# Initial-rollout coverage model (cross-section at the baseline edition)
#   n16_i ~ Binomial(pop16_i, p_i),  logit(p_i) = a + b'x_i + c_i
#   c_i BYM2 (or independent, for comparison). With one observation per county
#   the unstructured part of c_i also plays the role of extra-binomial variation.
# ---------------------------------------------------------------------------
b0 <- fread(file.path(DIR_DERIVED, "baseline.csv"), colClasses = list(character = "fips"))
setorder(b0, fips)
b0[, cid := match(fips, rownames(W))]
fb <- list(
  B0 = y_model ~ 1 + z_age + z_income + z_cases_pre + f(cid, model = "iid", hyper = H_SD),
  B1 = y_model ~ 1 + z_age + z_income + z_cases_pre +
    f(cid, model = "bym2", graph = W, scale.model = TRUE, constr = TRUE, hyper = H_BYM))
bstats <- list(); bfixed <- list(); bhyper <- list()
for (m in names(fb)) {
  msg("Fitting baseline model %s", m)
  r <- inla(fb[[m]], family = "binomial", Ntrials = b0$pop16, data = as.data.frame(b0),
            control.predictor = list(compute = TRUE, link = 1),
            control.compute = list(config = TRUE, waic = TRUE, dic = TRUE, cpo = TRUE),
            num.threads = INLA_THREADS)
  bstats[[m]] <- cbind(model = m, fit_stats(r)); bfixed[[m]] <- cbind(model = m, fixed_table(r))
  bhyper[[m]] <- cbind(model = m, hyper_table(r))
  print(bstats[[m]]); print(bfixed[[m]]); print(bhyper[[m]])
  if (m == "B1") {
    s <- inla.posterior.sample(N_DRAWS, r, selection = list(Predictor = 1:nrow(b0), cid = 1:(2 * n_cty)),
                               seed = 20211022L, num.threads = "1:1")
    rn <- rownames(s[[1]]$latent)
    L <- vapply(s, function(z) z$latent[, 1], numeric(length(rn)))
    saveRDS(list(fips = b0$fips, eta = L[grepl("^Predictor:", rn), ], county = L[grepl("^cid:", rn), ][1:n_cty, ],
                 county_structured = L[grepl("^cid:", rn), ][(n_cty + 1):(2 * n_cty), ]),
            file.path(DIR_MOD, "samples_baseline.rds"), compress = "xz")
  }
}
fwrite(rbindlist(bstats), file.path(DIR_MOD, "baseline_fit_statistics.csv"))
fwrite(rbindlist(bfixed), file.path(DIR_MOD, "baseline_fixed_effects.csv"))
fwrite(rbindlist(bhyper), file.path(DIR_MOD, "baseline_hyperparameters.csv"))
msg("Done.")
