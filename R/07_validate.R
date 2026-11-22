# 07_validate.R -- out-of-sample checks.
#
#   Rscript --vanilla R/07_validate.R counties [models]   # A. held-out counties, 10 random folds
#   Rscript --vanilla R/07_validate.R regions  [models]   # B. held-out public health regions (spatial blocks)
#   Rscript --vanilla R/07_validate.R later    [models]   # C. later intervals of half the counties
#   Rscript --vanilla R/07_validate.R forecast [models]   # D. next interval of every county
#   Rscript --vanilla R/07_validate.R summary             # rebuild the summary tables only
#
# [models] is an optional comma-separated list such as "M0,M1".
#
# A and B ask how well uptake in a county with no data can be predicted from
#   other counties (its neighbours, for the spatial models) and its predictors.
# C withholds every interval after an origin for a random half of the counties
#   while the other half stays observed. The statewide level of the later
#   intervals is then known and the test isolates what the model knows about
#   each county's own course.
# D withholds everything after an origin for all counties and scores the next
#   interval only: a true forecast, dominated by how well the statewide level
#   can be extrapolated.
#
# In every experiment the withheld outcomes are set to missing, the model is
# refitted, and the withheld county-intervals are scored against 1,000 joint
# posterior predictive draws. Results are stored per experiment and model in
# outputs/tables/validation_<experiment>_rows_<model>.csv; a model that already
# has a results file is skipped, so interrupted runs can be resumed.

source("R/_common.R")
source("R/_models.R")
options(width = 200, scipen = 999)
args <- commandArgs(trailingOnly = TRUE)
task <- if (length(args)) args[1] else "summary"
arg_models <- if (length(args) > 1) strsplit(args[2], ",")[[1]] else NULL
N_DRAWS <- 1000
vfile <- function(task, what, m) file.path(DIR_TAB, sprintf("validation_%s_%s_%s.csv", task, what, m))
pending <- function(task, models) models[!file.exists(vfile(task, "rows", models))]
models_for <- function(default) if (is.null(arg_models)) default else arg_models

d <- load_panel("panel.csv")
W <- build_graph()
K <- d[, max(k)]

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------
# Log predictive probability of the observed count: the binomial likelihood
# integrated against a normal approximation to the predictive distribution of
# the linear predictor (mean m, sd s taken from the posterior draws).
# The integrand (likelihood x normal density) is log-concave in the linear
# predictor. It is located by a one-dimensional search, rescaled to peak at 1,
# and integrated over 15 curvature-widths either side of the peak, so the
# result stays accurate for very large counts and for very small densities.
lpd_one <- function(y, n, m, s) {
  logf <- function(e) dbinom(y, n, cloglog_inv(e), log = TRUE) + dnorm(e, m, s, log = TRUE)
  if (y > 0) {
    e_hat <- log(-log1p(-min(y / n, 1 - 1e-12)))         # where the likelihood alone peaks
    br <- c(min(e_hat, m) - 1e-6, max(e_hat, m) + 1e-6)
  } else {
    br <- c(m - 40 * s, m)                               # likelihood decreases in e when y = 0
  }
  e0 <- optimize(logf, br, maximum = TRUE, tol = 1e-10)$maximum
  u <- exp(e0)
  gprime <- if (u < 1e-5) -0.5 + u / 6 else ((exp(u) - 1) - u * exp(u)) / (exp(u) - 1)^2
  curv <- y * u * gprime - (n - y) * u - 1 / s^2         # second derivative of logf at the peak
  h <- 1 / sqrt(-curv)
  top <- logf(e0)
  v <- tryCatch(integrate(function(e) exp(logf(e) - top), e0 - 15 * h, e0 + 15 * h,
                          rel.tol = 1e-9, subdivisions = 500L, stop.on.error = FALSE)$value,
                error = function(e) NA_real_)
  if (is.na(v) || v <= 0) NA_real_ else top + log(v)
}
crps_sample <- function(x, obs) {
  x <- sort(x); S <- length(x)
  mean(abs(x - obs)) - sum((2 * seq_len(S) - S - 1) * x) / S^2
}
# eta: matrix (rows = test rows, cols = draws) of linear predictors including the offset
score_rows <- function(test, eta, seed = 1L) {
  set.seed(seed)
  S <- ncol(eta)
  out <- lapply(seq_len(nrow(test)), function(i) {
    y <- test$y_model[i]; n <- test$at_risk[i]; dd <- test$days[i]
    pr <- cloglog_inv(eta[i, ])
    yrep <- rbinom(S, n, pr)
    to30 <- function(p) 100 * (1 - (1 - p)^(30 / dd))
    urep <- to30(yrep / n); uobs <- to30(y / n)
    q <- quantile(yrep, c(0.025, 0.25, 0.5, 0.75, 0.975), names = FALSE)
    m <- mean(eta[i, ]); s <- sd(eta[i, ])
    data.table(lpd = lpd_one(y, n, m, s),
               crps_pp = crps_sample(urep, uobs),
               abs_err_pp = abs(median(urep) - uobs),
               err_pp = median(urep) - uobs,
               pred_median_pp = median(urep), obs_pp = uobs,
               in95 = y >= q[1] & y <= q[5], in50 = y >= q[2] & y <= q[4],
               width95_pp = diff(quantile(urep, c(0.025, 0.975), names = FALSE)),
               pred_mean_eta = m, pred_sd_eta = s)
  })
  cbind(test[, .(fips, county, k, label, days, off, y_model, at_risk, pop16)], rbindlist(out))
}
# Coverage at the end of the study implied by the predicted interval
# probabilities for intervals k_from..K, starting from the recorded number of
# adults not yet vaccinated at the start of interval k_from. Computed draw by
# draw, so the interval reflects the dependence between a county's intervals.
end_coverage <- function(test, eta, k_from) {
  test <- copy(test)[, row := .I]
  ok <- test[, .(n = .N, all_usable = all(usable)), by = fips][n == (K - k_from + 1) & all_usable == TRUE, fips]
  rbindlist(lapply(ok, function(f) {
    r <- test[fips == f][order(k)]
    surv <- apply(1 - cloglog_inv(eta[r$row, , drop = FALSE]), 2, prod)
    pred <- 100 * (r$pop16[1] - r$at_risk[1] * surv) / r$pop16[1]
    obs <- r$cov_end[nrow(r)]
    lo <- quantile(pred, 0.025, names = FALSE); hi <- quantile(pred, 0.975, names = FALSE)
    data.table(fips = f, county = r$county[1], pop16 = r$pop16[1], cov_at_origin = r$cov_start[1],
               obs_cov_end = obs, pred_cov_end = median(pred), lo = lo, hi = hi,
               abs_err_pp = abs(median(pred) - obs), in95 = obs >= lo & obs <= hi)
  }))
}
# One refit: `heldout` rows are set to missing; rows in `heldout & score` are scored.
run_split <- function(m, heldout, tag, score = heldout, k_from = NULL) {
  y <- d$y_model
  y[heldout] <- NA
  test_idx <- which(heldout & score & d$usable)
  test <- d[test_idx]
  t0 <- Sys.time()
  r <- fit_model(d, m, W, y = y, compute_scores = FALSE)
  eta <- sample_eta(r, test_idx, N_DRAWS)
  out <- list(rows = cbind(model = m, split = tag, score_rows(test, eta)), endcov = NULL)
  if (!is.null(k_from)) {
    out$endcov <- cbind(model = m, split = tag,
                        end_coverage(test[k >= k_from], eta[test$k >= k_from, , drop = FALSE], k_from))
  }
  msg("  %s %s: %d test rows, %.0f s", tag, m, length(test_idx), as.numeric(difftime(Sys.time(), t0, units = "secs")))
  rm(r); gc()
  out
}
save_model <- function(task, m, out) {
  fwrite(rbindlist(lapply(out, `[[`, "rows")), vfile(task, "rows", m))
  e <- rbindlist(lapply(out, `[[`, "endcov"))
  if (nrow(e)) fwrite(e, vfile(task, "endcoverage", m))
}

# ---------------------------------------------------------------------------
# Experiments (each writes one results file per model)
# ---------------------------------------------------------------------------
cty <- sort(d[usable == TRUE, unique(fips)])

if (task == "counties") {
  set.seed(20210525)
  fold <- data.table(fips = cty, fold = sample(rep(1:10, length.out = length(cty))))
  fwrite(fold, file.path(DIR_TAB, "validation_county_folds.csv"))
  for (m in pending(task, models_for(c("M0", "M1", "M2", "M4")))) {
    save_model(task, m, lapply(1:10, function(f) run_split(m, d$fips %in% fold[fold == f, fips], sprintf("fold%02d", f), k_from = 1L)))
  }
}

if (task == "regions") {
  # DSHS public health regions, read from the county sheet of the last workbook
  suppressMessages(library(readxl))
  f <- file.path(DIR_RAW, "dshs_vax_wayback/workbooks",
                 fread(file.path(DIR_DERIVED, "dshs_workbook_index.csv"))[as.Date(as_of) == max(as.Date(as_of)), file])
  x <- as.data.frame(suppressMessages(read_excel(f, sheet = "By County", col_types = "text")))
  phr <- data.table(ckey = county_key(x[[1]]), phr = trimws(x[[2]]))
  lk <- unique(d[, .(fips, county)]); lk[, ckey := county_key(county)]
  phr <- merge(lk, phr, by = "ckey")[, .(fips, county, phr)]
  stopifnot(nrow(phr) == 254)
  fwrite(phr, file.path(DIR_DERIVED, "county_phr.csv"))
  for (m in pending(task, models_for(c("M0", "M1", "M2", "M4")))) {
    save_model(task, m, lapply(sort(unique(phr$phr)), function(g)
      run_split(m, d$fips %in% phr[phr == g, fips], paste0("PHR ", g), k_from = 1L)))
  }
}

if (task == "later") {
  set.seed(20220226)
  half <- data.table(fips = cty, half = sample(rep(c("A", "B"), length.out = length(cty))))
  fwrite(half, file.path(DIR_TAB, "validation_later_halves.csv"))
  origins <- c(3L, 6L, 9L)                     # last interval observed for the withheld counties
  for (m in pending(task, models_for(names(MODEL_LABELS)))) {
    save_model(task, m, unlist(lapply(origins, function(K0) lapply(c("A", "B"), function(h) {
      o <- run_split(m, d$k > K0 & d$fips %in% half[half == h, fips], sprintf("origin%02d half %s", K0, h), k_from = K0 + 1L)
      o$rows[, `:=`(origin = K0, horizon = k - K0)]
      o$endcov[, origin := K0]
      o
    })), recursive = FALSE))
  }
}

if (task == "forecast") {
  for (m in pending(task, models_for(names(MODEL_LABELS)))) {
    save_model(task, m, lapply(3:(K - 1), function(K0) {
      o <- run_split(m, d$k > K0, sprintf("origin%02d", K0), score = d$k == K0 + 1L)
      o$rows[, `:=`(origin = K0, horizon = 1L)]
      o
    }))
  }
}

# ---------------------------------------------------------------------------
# Summary tables, rebuilt from every results file present
# ---------------------------------------------------------------------------
read_all <- function(task, what) {
  f <- list.files(DIR_TAB, pattern = sprintf("^validation_%s_%s_M[0-9][.]csv$", task, what), full.names = TRUE)
  if (!length(f)) return(NULL)
  rbindlist(lapply(f, fread, colClasses = list(character = "fips")), fill = TRUE)
}
summarise_scores <- function(x, by) {
  x <- copy(x)
  # County position within its interval: observed and predicted log hazard,
  # each centred on the mean of the scored counties in the same split. This
  # removes any error that is common to all counties in an interval.
  x[, lh_obs := fifelse(y_model > 0, log(-log1p(-pmin(y_model / at_risk, 1 - 1e-12))) - off, NA_real_)]
  x[, lh_pred := pred_mean_eta - off]
  x[!is.na(lh_obs), `:=`(c_obs = lh_obs - mean(lh_obs), c_pred = lh_pred - mean(lh_pred)), by = .(model, split, k)]
  x[, .(rows = .N, counties = uniqueN(fips),
        mean_log_score = mean(lpd, na.rm = TRUE), median_log_score = median(lpd, na.rm = TRUE),
        lpd_missing = sum(is.na(lpd)),
        mean_crps_pp = mean(crps_pp), mae_pp = mean(abs_err_pp), bias_pp = mean(err_pp),
        coverage95 = mean(in95), coverage50 = mean(in50), mean_width95_pp = mean(width95_pp),
        rmse_relative_log_hazard = sqrt(mean((c_obs - c_pred)^2, na.rm = TRUE)),
        cor_relative_log_hazard = cor(c_obs, c_pred, use = "complete.obs")), by = by]
}
endsum <- function(e, by) e[, .(end_counties = .N, end_coverage_mae_pp = mean(abs_err_pp),
                                end_coverage_median_abs_err_pp = median(abs_err_pp),
                                end_coverage_in95 = mean(in95)), by = by]
show <- function(s) print(s[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)], nrows = 200)

rows <- read_all("counties", "rows")
if (!is.null(rows)) {
  s <- merge(summarise_scores(rows, "model"), endsum(read_all("counties", "endcoverage"), "model"), by = "model")
  fwrite(s, file.path(DIR_TAB, "validation_counties_summary.csv")); cat("\nA. Held-out counties\n"); show(s)
}
rows <- read_all("regions", "rows")
if (!is.null(rows)) {
  s <- merge(summarise_scores(rows, "model"), endsum(read_all("regions", "endcoverage"), "model"), by = "model")
  fwrite(s, file.path(DIR_TAB, "validation_regions_summary.csv")); cat("\nB. Held-out regions\n"); show(s)
  fwrite(summarise_scores(rows, c("split", "model")), file.path(DIR_TAB, "validation_regions_by_region.csv"))
}
rows <- read_all("later", "rows")
if (!is.null(rows)) {
  s <- merge(summarise_scores(rows, "model"), endsum(read_all("later", "endcoverage"), "model"), by = "model")
  fwrite(s, file.path(DIR_TAB, "validation_later_summary.csv")); cat("\nC. Later intervals of half the counties\n"); show(s)
  so <- merge(summarise_scores(rows, c("origin", "model")), endsum(read_all("later", "endcoverage"), c("origin", "model")),
              by = c("origin", "model"))
  fwrite(so, file.path(DIR_TAB, "validation_later_by_origin.csv"))
  sh <- summarise_scores(rows[, hgroup := fifelse(horizon == 1, "1 interval ahead", fifelse(horizon <= 3, "2-3 ahead", "4 or more ahead"))],
                         c("hgroup", "model"))
  fwrite(sh, file.path(DIR_TAB, "validation_later_by_horizon.csv"))
  show(dcast(so, origin ~ model, value.var = "end_coverage_mae_pp"))
}
rows <- read_all("forecast", "rows")
if (!is.null(rows)) {
  s <- summarise_scores(rows, "model")
  fwrite(s, file.path(DIR_TAB, "validation_forecast_summary.csv")); cat("\nD. Next interval of every county\n"); show(s)
  fwrite(summarise_scores(rows, c("origin", "model")), file.path(DIR_TAB, "validation_forecast_by_origin.csv"))
}

# ---------------------------------------------------------------------------
# Paired differences between models on the same county-intervals
# ---------------------------------------------------------------------------
# Difference in mean CRPS and mean log score (second model minus first) with a
# 95% interval from 2,000 bootstrap samples. Whole counties are resampled in
# experiments A to C, because a county's rows share data and fits. In
# experiment D every county in an interval shares the error in the statewide
# level, so whole forecast origins are resampled instead (there are only nine,
# and the intervals are correspondingly wide).
N_BOOT <- 2000L
boot_mean <- function(v, g, idx) {
  G <- nrow(idx)
  s_g <- as.numeric(tapply(v, factor(g, levels = seq_len(G)), sum))
  n_g <- tabulate(g, G)
  b <- colSums(matrix(s_g[idx], G)) / colSums(matrix(n_g[idx], G))
  c(mean(v), quantile(b, c(0.025, 0.975), names = FALSE))
}
paired_diff <- function(x, experiment, subset, cluster, value = c("crps_pp", "lpd")) {
  ms <- sort(unique(x$model))
  if (length(ms) < 2) return(NULL)
  id <- intersect(c("split", "origin", "fips", "k"), names(x))
  w <- dcast(x, as.formula(paste(paste(id, collapse = " + "), "~ model")), value.var = value)
  w <- w[complete.cases(w)]
  g <- as.integer(factor(w[[cluster]])); G <- max(g)
  set.seed(20230510)
  idx <- matrix(sample.int(G, G * N_BOOT, replace = TRUE), G, N_BOOT)
  col <- function(v, m) if (length(value) > 1) w[[paste(v, m, sep = "_")]] else w[[m]]
  pairs <- t(combn(ms, 2))
  rbindlist(lapply(seq_len(nrow(pairs)), function(i) {
    a <- pairs[i, 1]; b <- pairs[i, 2]
    o <- data.table(experiment = experiment, subset = subset, first = a, second = b,
                    rows = nrow(w), clusters = G, resampled = cluster)
    for (v in value) {
      e <- boot_mean(col(v, b) - col(v, a), g, idx)
      o[, paste0("diff_", v, c("", "_lo", "_hi")) := as.list(e)]
    }
    o
  }))
}
hgroups <- function(x) x[, hgroup := fifelse(horizon == 1, "1 interval ahead",
                                      fifelse(horizon <= 3, "2-3 ahead", "4 or more ahead"))]
pd <- list(); pe <- list()
for (tk in c("counties", "regions", "later", "forecast")) {
  rows <- read_all(tk, "rows")
  if (is.null(rows)) next
  ex <- c(counties = "A", regions = "B", later = "C", forecast = "D")[[tk]]
  pd[[tk]] <- paired_diff(rows, ex, "all", if (tk == "forecast") "split" else "fips")
  if (tk == "later") {
    hgroups(rows)
    for (h in unique(rows$hgroup)) pd[[paste(tk, h)]] <- paired_diff(rows[hgroup == h], ex, h, "fips")
  }
  e <- if (tk == "forecast") NULL else read_all(tk, "endcoverage")
  if (!is.null(e)) pe[[tk]] <- paired_diff(e, ex, "all", "fips", value = "abs_err_pp")
}
if (length(pd)) {
  pd <- rbindlist(pd)
  setnames(pd, c("diff_crps_pp", "diff_crps_pp_lo", "diff_crps_pp_hi", "diff_lpd", "diff_lpd_lo", "diff_lpd_hi"),
           c("diff_crps_pp", "diff_crps_lo", "diff_crps_hi", "diff_log_score", "diff_log_score_lo", "diff_log_score_hi"))
  if (length(pe)) {
    pe <- rbindlist(pe)[, .(experiment, subset, first, second, end_counties_rows = rows, diff_end_coverage_mae_pp = diff_abs_err_pp,
                            diff_end_coverage_mae_lo = diff_abs_err_pp_lo, diff_end_coverage_mae_hi = diff_abs_err_pp_hi)]
    pd <- merge(pd, pe, by = c("experiment", "subset", "first", "second"), all.x = TRUE, sort = FALSE)
  }
  fwrite(pd, file.path(DIR_TAB, "validation_paired_differences.csv"))
  cat("\nPaired differences (second model minus first); negative CRPS difference = second model better\n")
  show(pd[, .(experiment, subset, first, second, clusters, diff_crps_pp, diff_crps_lo, diff_crps_hi,
              diff_log_score, diff_log_score_lo, diff_log_score_hi)])
}
msg("Done: %s", task)
