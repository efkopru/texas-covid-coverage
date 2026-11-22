# 08_outputs.R -- tables and figures.
#
#   Rscript --vanilla R/08_outputs.R [model]
#
# [model] defaults to FINAL_MODEL in R/_common.R. Every figure has a table twin
# in outputs/tables with the numbers it shows.
#
# "Recorded" always means a number taken from the DSHS records and the Census
# population estimate. "Modelled" always means a posterior summary from the
# Bayesian model (median and 95% credible interval from 1,000 joint draws).

source("R/_common.R")
source("R/_models.R")
source("R/_plot.R")
suppressMessages(library(spdep))
options(width = 200, scipen = 999)
args <- commandArgs(trailingOnly = TRUE)
FINAL <- if (length(args)) args[1] else FINAL_MODEL
msg("Outputs for model %s", FINAL)
out <- function(x, name) fwrite(x, file.path(DIR_TAB, paste0(name, ".csv")))
qs <- function(m, p = c(0.025, 0.5, 0.975)) t(apply(m, 1, quantile, probs = p, names = FALSE))
fmt_date <- function(x) sub("^0", "", format(as.Date(x), "%d %b %Y"))

d <- load_panel("panel.csv")
W <- build_graph()
ed <- fread(file.path(DIR_DERIVED, "coverage_editions.csv"), colClasses = list(character = "fips")); ed[, as_of := as.Date(as_of)]
flags <- fread(file.path(DIR_DERIVED, "county_flags.csv"), colClasses = list(character = "fips"))
shape <- st_read(file.path(DIR_DERIVED, "tx_counties.gpkg"), quiet = TRUE)[, "fips"]
dr <- readRDS(file.path(DIR_MOD, sprintf("samples_%s.rds", FINAL)))
stopifnot(identical(dr$panel_key$fips, d$fips), identical(dr$panel_key$k, d$k))
S <- ncol(dr$eta); n_cty <- nrow(W); n_t <- d[, max(k)]
fips_all <- rownames(W)
kept <- flags[excl_county == FALSE, sort(fips)]
iv <- unique(d[, .(k, label, data_from, data_to, days, mid)])
base_date <- min(d$data_from) - 1          # last day covered by the baseline edition
end_date <- max(d$data_to)

# ===========================================================================
# 1. Modelled uptake per county and interval
# ===========================================================================
logh <- dr$eta - d$off                      # log hazard per 30 days, rows x draws
u30  <- 100 * cloglog_inv(logh)             # % of remaining unvaccinated adults vaccinated per 30 days
u30s <- 100 * cloglog_inv(logh - dr$eps)    # the same without the county-interval deviation
q1 <- qs(u30); q2 <- qs(u30s)
tab_u <- d[, .(fips, county, k, label, days, pop16, at_risk, new_first_doses = y, usable, exclude, y_floored,
               recorded_uptake30_pct = 100 * uptake30)]
tab_u[, `:=`(modelled_uptake30_pct = q1[, 2], modelled_lo = q1[, 1], modelled_hi = q1[, 3],
             structural_uptake30_pct = q2[, 2], structural_lo = q2[, 1], structural_hi = q2[, 3])]
tab_u[fips %in% flags[excl_county == TRUE, fips],
      c("modelled_uptake30_pct", "modelled_lo", "modelled_hi", "structural_uptake30_pct", "structural_lo", "structural_hi") := NA_real_]
out(tab_u, "modelled_uptake_county_interval")

# Statewide (counties kept in the model), recorded and modelled
kr <- which(d$fips %in% kept)
pi_int <- cloglog_inv(dr$eta[kr, ])                     # probability over the whole interval
dk <- d[kr]
sw <- rbindlist(lapply(iv$k, function(kk) {
  i <- which(dk$k == kk)
  p <- colSums(pi_int[i, , drop = FALSE] * dk$at_risk[i]) / sum(dk$at_risk[i])
  u <- 100 * (1 - (1 - p)^(30 / iv$days[kk]))
  rec <- sum(dk$y[i]) / sum(dk$at_risk[i])
  cq <- apply(u30[kr[i], , drop = FALSE], 2, quantile, probs = c(0.1, 0.5, 0.9))    # spread across counties, per draw
  data.table(k = kk, recorded_pooled = 100 * (1 - (1 - rec)^(30 / iv$days[kk])),
             modelled_pooled = median(u), modelled_pooled_lo = quantile(u, 0.025), modelled_pooled_hi = quantile(u, 0.975),
             county_p10 = median(cq[1, ]), county_median = median(cq[2, ]), county_p90 = median(cq[3, ]),
             county_median_lo = quantile(cq[2, ], 0.025), county_median_hi = quantile(cq[2, ], 0.975))
}))
sw <- merge(iv, sw, by = "k")
out(sw, "fig06_uptake_by_interval")

# ===========================================================================
# 2. County-level modelled quantities
# ===========================================================================
# (a) Relative uptake: the county's log hazard minus the mean of the kept
#     counties, averaged over the 12 intervals (equal weight per interval).
idx <- matrix(NA_integer_, n_cty, n_t, dimnames = list(fips_all, NULL))
idx[cbind(match(d$fips, fips_all), d$k)] <- seq_len(nrow(d))
kept_i <- match(kept, fips_all)
dev <- array(NA_real_, c(length(kept), S))
for (kk in 1:n_t) {
  lk <- logh[idx[kept_i, kk], ]
  lk <- sweep(lk, 2, colMeans(lk))
  dev <- if (kk == 1) lk else dev + lk
}
dev <- dev / n_t
qD <- qs(exp(dev))
# The same quantity (posterior median) from every fitted model, to show how
# much the modelled county differences depend on the choice of model.
rel_by_model <- function(m) {
  x <- if (m == FINAL) dr else readRDS(file.path(DIR_MOD, sprintf("samples_%s.rds", m)))
  stopifnot(identical(x$panel_key$fips, d$fips), identical(x$panel_key$k, d$k))
  lh <- x$eta - d$off
  dv <- 0
  for (kk in 1:n_t) { lk <- lh[idx[kept_i, kk], ]; dv <- dv + sweep(lk, 2, colMeans(lk)) }
  apply(exp(dv / n_t), 1, median)
}
if (all(file.exists(file.path(DIR_MOD, sprintf("samples_%s.rds", names(MODEL_LABELS)))))) {
  rel_all <- sapply(names(MODEL_LABELS), rel_by_model)
  rob <- merge(unique(d[, .(fips, county, pop16)]), data.table(fips = kept, rel_all), by = "fips")
  out(rob, "relative_uptake_by_model")
  robs <- rbindlist(lapply(setdiff(names(MODEL_LABELS), FINAL), function(m) {
    pd <- 100 * abs(rob[[m]] / rob[[FINAL]] - 1)
    w <- which.max(pd)
    data.table(model = m, compared_with = FINAL, counties = nrow(rob),
               correlation_log_scale = cor(log(rob[[m]]), log(rob[[FINAL]])),
               median_abs_diff_pct = median(pd), p95_abs_diff_pct = quantile(pd, 0.95, names = FALSE),
               max_abs_diff_pct = pd[w], max_diff_county = rob$county[w], max_diff_county_adults = rob$pop16[w],
               median_abs_diff_pct_over_5000_adults = median(pd[rob$pop16 >= 5000]),
               max_abs_diff_pct_over_5000_adults = max(pd[rob$pop16 >= 5000]))
  }))
  out(robs, "relative_uptake_model_robustness")
  print(robs)
}
# (b) County effect not explained by the predictors, and its spatially smooth part
resid_eff <- dr$county
if (FINAL == "M4") {
  tr <- dr$traj                                           # rows: county 1 intervals 1..T, county 2 ...
  stopifnot(nrow(tr) == n_cty * n_t)
  resid_eff <- resid_eff + t(sapply(seq_len(n_cty), function(i) colMeans(tr[(i - 1) * n_t + 1:n_t, , drop = FALSE])))
}
qB <- qs(exp(resid_eff))
# The spatially smooth part is taken from SPATIAL_MODEL, where the county
# effect is the only county-level term and its two parts are cleanly separated.
dsp <- readRDS(file.path(DIR_MOD, sprintf("samples_%s.rds", SPATIAL_MODEL)))
hp <- dsp$hyper; rownames(hp) <- dsp$hyper_names
scale_s <- sqrt(hp["Phi for cid", ] / hp["Precision for cid", ])
smooth_eff <- sweep(dsp$county_structured, 2, scale_s, "*")
qSm <- qs(exp(smooth_eff))
rm(dsp)
# (c) Cumulative change implied by the modelled interval probabilities
chg <- rbindlist(lapply(kept, function(f) {
  r <- idx[f, ]
  surv <- apply(1 - cloglog_inv(dr$eta[r, , drop = FALSE]), 2, prod)
  x <- 100 * d$at_risk[r[1]] * (1 - surv) / d$pop16[r[1]]
  data.table(fips = f, modelled_change_pp = median(x), modelled_change_lo = quantile(x, 0.025), modelled_change_hi = quantile(x, 0.975))
}))

mid_asof <- as.Date("2022-02-26")
cov_at <- function(a) ed[as_of == a, .(fips, cov = cov16)]
ct <- merge(flags[, .(fips, county, pop16, excl_county, max_cov16)], unique(d[, .(fips, pct65_of_16plus, med_hh_income, income_imputed)]), by = "fips")
ct <- merge(ct, cov_at(GRIDS$main[1])[, .(fips, cov_baseline = cov)], by = "fips")
ct <- merge(ct, cov_at(mid_asof)[, .(fips, cov_feb2022 = cov)], by = "fips")
ct <- merge(ct, cov_at(max(GRIDS$main))[, .(fips, cov_end = cov)], by = "fips")
ct[, `:=`(change_pp = cov_end - cov_baseline, change_to_feb2022_pp = cov_feb2022 - cov_baseline)]
ct <- merge(ct, data.table(fips = kept, rel_uptake = qD[, 2], rel_uptake_lo = qD[, 1], rel_uptake_hi = qD[, 3],
                           prob_below_average = rowMeans(dev < 0)), by = "fips", all.x = TRUE)
ct <- merge(ct, data.table(fips = fips_all, residual_effect = qB[, 2], residual_lo = qB[, 1], residual_hi = qB[, 3]), by = "fips")
ct <- merge(ct, data.table(fips = fips_all, smooth_effect = qSm[, 2]), by = "fips")
ct <- merge(ct, chg, by = "fips", all.x = TRUE)
ct[excl_county == TRUE, c("residual_effect", "residual_lo", "residual_hi", "smooth_effect") := NA_real_]
setorder(ct, fips)
out(ct, "county_results")
msg("County table written: %d counties, %d with modelled quantities", nrow(ct), ct[!is.na(rel_uptake), .N])

# ===========================================================================
# 3. Did the gaps between counties widen or narrow? (recorded coverage)
# ===========================================================================
wq <- function(x, w, p) { o <- order(x); cw <- cumsum(w[o]) / sum(w); x[o][which(cw >= p)[1]] }
gp <- ed[as_of >= GRIDS$main[1] & fips %in% kept, .(
  counties = .N, mean = mean(cov16), sd = sd(cov16),
  p10 = quantile(cov16, 0.10), p25 = quantile(cov16, 0.25), median = median(cov16),
  p75 = quantile(cov16, 0.75), p90 = quantile(cov16, 0.90), min = min(cov16), max = max(cov16),
  pooled = 100 * sum(n16) / sum(pop16_2021),
  sd_pop_weighted = sqrt(sum(pop16_2021 * (cov16 - sum(pop16_2021 * cov16) / sum(pop16_2021))^2) / sum(pop16_2021)),
  p10_person = wq(cov16, pop16_2021, 0.10), p90_person = wq(cov16, pop16_2021, 0.90)), by = as_of]
gp[, `:=`(data_through = as_of - 1, gap_p90_p10 = p90 - p10, iqr = p75 - p25, gap_person = p90_person - p10_person,
          cv = sd / mean)]
setorder(gp, as_of)
out(gp, "fig04_gap_over_time")
ck <- ct[excl_county == FALSE]
conv <- lm(change_pp ~ cov_baseline, data = ck)
q5 <- function(x) cut(x, quantile(x, 0:5 / 5), include.lowest = TRUE, labels = 1:5)
ck[, `:=`(q_base = q5(cov_baseline), q_end = q5(cov_end))]
gap_summary <- data.table(
  measure = c("Counties", "Gap between 90th and 10th percentile county, baseline (points)", "Gap, end (points)",
              "Standard deviation across counties, baseline (points)", "Standard deviation, end (points)",
              "Population-weighted standard deviation, baseline", "Population-weighted standard deviation, end",
              "Slope of change on baseline coverage (points per point)", "Slope, 95% confidence interval low", "Slope, high",
              "Correlation of baseline coverage with change", "Rank correlation of baseline with end coverage",
              "Bottom-fifth counties at baseline still in bottom fifth at end (%)",
              "Unvaccinated share ratio, 10th vs 90th percentile county, baseline", "Unvaccinated share ratio, end"),
  value = c(nrow(ck), gp[1, gap_p90_p10], gp[.N, gap_p90_p10], gp[1, sd], gp[.N, sd], gp[1, sd_pop_weighted], gp[.N, sd_pop_weighted],
            coef(conv)[2], confint(conv)[2, 1], confint(conv)[2, 2], cor(ck$cov_baseline, ck$change_pp),
            cor(ck$cov_baseline, ck$cov_end, method = "spearman"),
            100 * ck[q_base == 1, mean(q_end == 1)],
            (100 - gp[1, p10]) / (100 - gp[1, p90]), (100 - gp[.N, p10]) / (100 - gp[.N, p90])))
out(gap_summary, "gap_summary")
print(gap_summary)
# Modelled link between where a county started and its later uptake hazard
cb <- ck[match(kept, fips), cov_baseline]
rho <- apply(dev, 2, function(x) cor(x, cb))
slope <- apply(dev, 2, function(x) coef(lm(x ~ cb))[2])
msg("Correlation of baseline coverage with modelled relative uptake: %.2f (95%% CrI %.2f to %.2f); hazard ratio per 10 points of baseline coverage: %.2f (%.2f to %.2f)",
    median(rho), quantile(rho, 0.025), quantile(rho, 0.975), exp(10 * median(slope)), exp(10 * quantile(slope, 0.025)), exp(10 * quantile(slope, 0.975)))
# Rows 1-2: posterior of the descriptive statistic; their intervals carry only
# the uncertainty in the modelled county rates, which is small. Row 3: the
# same slope fitted by least squares to the posterior medians, with the usual
# 95% confidence interval from the scatter between counties, which is the
# interval to quote when asking how firmly the relationship is established.
ols <- lm(apply(dev, 1, median) ~ cb)
out(data.table(quantity = c("correlation of baseline coverage with modelled relative uptake (interval: uncertainty in modelled county rates only)",
                            "hazard ratio per 10 points higher baseline coverage (interval: uncertainty in modelled county rates only)",
                            "hazard ratio per 10 points higher baseline coverage, least squares across counties (95% confidence interval from scatter between counties)"),
               median = c(median(rho), exp(10 * median(slope)), exp(10 * coef(ols)[[2]])),
               lo = c(quantile(rho, 0.025), exp(10 * quantile(slope, 0.025)), exp(10 * confint(ols)[2, 1])),
               hi = c(quantile(rho, 0.975), exp(10 * quantile(slope, 0.975)), exp(10 * confint(ols)[2, 2]))), "baseline_vs_later_uptake")

# ===========================================================================
# 4. Predictor associations
# ===========================================================================
sc <- fread(file.path(DIR_DERIVED, "covariate_scaling.csv"))
fx <- dr$fixed; rownames(fx) <- dr$fixed_names
# Medians and 95% limits are the quantiles of R-INLA's posterior marginal of
# each coefficient (the same source as fixed_effects.csv and the sensitivity
# table), rescaled to the stated contrast; the posterior draws are used only
# for the probability that the ratio exceeds 1.
fxm <- as.data.frame(fread(file.path(DIR_MOD, "fixed_effects.csv"))[model == FINAL])
rownames(fxm) <- fxm$term
conv_tab <- function(tm, name, unit_label, factor) {
  stopifnot(factor > 0)
  data.table(predictor = name, contrast = unit_label, ratio = exp(fxm[tm, "median"] * factor),
             lo = exp(fxm[tm, "q025"] * factor), hi = exp(fxm[tm, "q975"] * factor),
             prob_ratio_above_1 = mean(fx[tm, ] > 0))
}
sd_age <- sc[variable == "pct65_of_16plus", sd]; sd_inc <- sc[variable == "log_med_hh_income", sd]
sd_case <- sc[variable == "log_case_rate_prev30_plus10", sd]
assoc <- rbind(
  conv_tab("z_age", "Share of adults aged 65+", sprintf("per 1 SD (%.1f points)", sd_age), 1),
  conv_tab("z_age", "Share of adults aged 65+", "per 5 points", 5 / sd_age),
  conv_tab("z_income", "Median household income", sprintf("per 1 SD (%.0f%% higher)", 100 * (exp(sd_inc) - 1)), 1),
  conv_tab("z_income", "Median household income", "per 10% higher", log(1.1) / sd_inc),
  conv_tab("z_cases", "Cases in previous 30 days", sprintf("per 1 SD (%.1f-fold)", exp(sd_case)), 1),
  conv_tab("z_cases", "Cases in previous 30 days", "per doubling", log(2) / sd_case))
assoc[, `:=`(model = FINAL, outcome = "Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023", measure = "hazard ratio")]
bf <- fread(file.path(DIR_MOD, "baseline_fixed_effects.csv"))[model == "B1" & term != "(Intercept)"]
assoc_b <- bf[, .(predictor = c(z_age = "Share of adults aged 65+", z_income = "Median household income",
                                z_cases_pre = "Cumulative cases before 14 Dec 2020")[term],
                  contrast = "per 1 SD", ratio = exp(median), lo = exp(q025), hi = exp(q975), prob_ratio_above_1 = NA_real_,
                  model = "B1", outcome = "Coverage reached by 24 May 2021", measure = "odds ratio")]
assoc <- rbind(assoc, assoc_b)
out(assoc, "fig10_predictor_associations")
print(assoc[, .(outcome = substr(outcome, 1, 30), predictor, contrast, ratio = round(ratio, 3), lo = round(lo, 3), hi = round(hi, 3))])

# ===========================================================================
# 5. Does smoothing hide local differences?
# ===========================================================================
us <- tab_u[usable == TRUE & fips %in% kept]
us[, size := cut(pop16, c(0, 5000, 50000, Inf), labels = c("Fewer than 5,000 adults", "5,000 to 50,000", "More than 50,000"))]
us[, `:=`(abs_diff_pp = abs(modelled_uptake30_pct - recorded_uptake30_pct),
          rel_diff = (modelled_uptake30_pct - recorded_uptake30_pct) / pmax(recorded_uptake30_pct, 1e-9),
          inside = recorded_uptake30_pct >= modelled_lo & recorded_uptake30_pct <= modelled_hi,
          width = modelled_hi - modelled_lo)]
shr <- us[, .(county_intervals = .N, counties = uniqueN(fips),
              median_abs_diff_pp = median(abs_diff_pp), p95_abs_diff_pp = quantile(abs_diff_pp, 0.95),
              median_abs_rel_diff_pct = 100 * median(abs(rel_diff[recorded_uptake30_pct > 0])),
              recorded_inside_95_interval_pct = 100 * mean(inside), median_interval_width_pp = median(width),
              cor_recorded_modelled = cor(recorded_uptake30_pct, modelled_uptake30_pct),
              cor_recorded_structural = cor(recorded_uptake30_pct, structural_uptake30_pct)), by = size][order(size)]
out(shr, "smoothing_recorded_vs_modelled")
print(shr)
# Local contrast: a county's residual effect minus the mean of its neighbours'
# (neighbours that are themselves modelled; flagged counties are not used)
nbl <- lapply(seq_len(n_cty), function(i) intersect(which(W[i, ] > 0), kept_i))
loc <- t(sapply(seq_len(n_cty), function(i) {
  if (!length(nbl[[i]])) return(rep(NA_real_, S))
  resid_eff[i, ] - colMeans(resid_eff[nbl[[i]], , drop = FALSE])
}))
qL <- t(apply(loc, 1, function(x) if (anyNA(x)) rep(NA_real_, 3) else quantile(exp(x), c(0.025, 0.5, 0.975), names = FALSE)))
lc <- data.table(fips = fips_all, local_ratio = qL[, 2], local_lo = qL[, 1], local_hi = qL[, 3],
                 prob_above_neighbours = rowMeans(loc > 0), n_neighbours = lengths(nbl))
lc <- merge(ct[, .(fips, county, pop16, excl_county, cov_baseline, cov_end, rel_uptake)], lc, by = "fips")[excl_county == FALSE & n_neighbours > 0]
lc[, distinct := prob_above_neighbours > 0.975 | prob_above_neighbours < 0.025]
setorder(lc, local_ratio)
out(lc, "smoothing_local_contrasts")
msg("Counties whose effect differs from the mean of their neighbours with 95%% posterior probability: %d of %d (%d lower, %d higher)",
    lc[, sum(distinct)], nrow(lc), lc[distinct == TRUE & local_ratio < 1, .N], lc[distinct == TRUE & local_ratio > 1, .N])
# Spatial pattern left in non-spatial county effects (Moran's I)
d0 <- readRDS(file.path(DIR_MOD, "samples_M0.rds"))
lw <- mat2listw(W[kept_i, kept_i], style = "W", zero.policy = TRUE)
mi <- moran.test(rowMeans(d0$county)[kept_i], lw, zero.policy = TRUE)
msg("Moran's I of the county effects from the non-spatial model (kept counties): %.3f, p = %.2g", mi$estimate[1], mi$p.value)
hy <- fread(file.path(DIR_MOD, "hyperparameters.csv"))
out(data.table(item = c("Moran's I, county effects of the non-spatial model", "p-value", "counties significantly different from neighbours (95%)",
                        "of which lower", "of which higher"),
               value = c(mi$estimate[1], mi$p.value, lc[, sum(distinct)], lc[distinct == TRUE & local_ratio < 1, .N],
                         lc[distinct == TRUE & local_ratio > 1, .N])), "smoothing_summary")

# ===========================================================================
# 6. Cross-check of recorded adult coverage against the CDC county file
#    DSHS: 16+ count / 16+ population. CDC: 18+ count / 18+ population.
#    Same Census Vintage 2025 denominators (1 July 2021) for both.
# ===========================================================================
cdc <- fread(file.path(DIR_DERIVED, "cdc_county.csv"), colClasses = list(character = "fips")); cdc[, date := as.Date(date)]
pop21 <- fread(file.path(DIR_DERIVED, "pop_county_year.csv"), colClasses = list(character = "fips"))[year == 2021]
xc <- rbindlist(lapply(as.Date(c("2021-10-26", "2022-05-31", "2023-05-10")), function(a) {
  x <- merge(ed[as_of == a, .(fips, county, dshs16 = n16)], cdc[date == a, .(fips, cdc18 = administered_dose1_recip_18plus)], by = "fips")
  x <- merge(x, pop21[, .(fips, pop16, pop18)], by = "fips")
  x[, `:=`(as_of = a, cov_dshs16 = 100 * dshs16 / pop16, cov_cdc18 = 100 * cdc18 / pop18)]
}))
xc[, diff := cov_cdc18 - cov_dshs16]
xc <- merge(xc, flags[, .(fips, excl_county)], by = "fips")
xs <- xc[excl_county == FALSE & cdc18 > 0, .(counties = .N, correlation = cor(cov_dshs16, cov_cdc18),
                                             rank_correlation = cor(cov_dshs16, cov_cdc18, method = "spearman"),
                                             median_diff_points = median(diff), median_abs_diff_points = median(abs(diff)),
                                             counties_diff_over_5_points = sum(abs(diff) > 5),
                                             counties_diff_over_10_points = sum(abs(diff) > 10)), by = as_of]
out(xs, "cdc_vs_dshs_coverage_check")
out(xc[as_of == max(as_of)][order(-abs(diff)), .(fips, county, excl_county, cov_dshs16, cov_cdc18, diff)], "cdc_vs_dshs_coverage_by_county")
print(xs)
ct <- merge(ct, xc[as_of == max(as_of), .(fips, cdc18_coverage_end = cov_cdc18, cdc_minus_dshs_points = diff)], by = "fips", all.x = TRUE)
out(ct, "county_results")

# ===========================================================================
# 7. Statewide rollout before the baseline, by month of vaccination
#    From the "By Vaccination Date" sheet of the last DSHS edition. Everyone
#    vaccinated before 13 May 2021 was 16 or older, so these months can be set
#    against the 16+ population. Statewide only: the sheet has no county detail.
# ===========================================================================
vd <- fread(file.path(DIR_DERIVED, "dshs_state_by_vaxdate.csv")); vd[, `:=`(as_of = as.Date(as_of), vax_date = as.Date(vax_date))]
vdl <- vd[as_of == max(as_of) & vax_date < as.Date("2021-05-01")]
pop16_tx <- pop21[, sum(pop16)]
em <- vdl[, .(first_doses = sum(one_dose, na.rm = TRUE)), by = .(month = format(vax_date, "%Y-%m"))][order(month)]
em[, days := as.integer(month_end(as.Date(paste0(month, "-01"))) - as.Date(paste0(month, "-01")) + 1)]
em[month == "2020-12", days := as.integer(as.Date("2020-12-31") - min(vdl$vax_date) + 1)]
em[, cumulative := cumsum(first_doses)]
em[, at_risk_start := pop16_tx - shift(cumulative, fill = 0)]
em[, `:=`(coverage_end_pct = 100 * cumulative / pop16_tx, uptake30_pct = 100 * (1 - (1 - first_doses / at_risk_start)^(30 / days)))]
# what the state row showed at the time (edition dated the first day of the next month, where it exists)
so <- fread(file.path(DIR_TAB, "verify_13a_unassigned_daily.csv")); so[, as_of := as.Date(as_of)]
em[, reported_then := sapply(month, function(m) {
  t <- month_end(as.Date(paste0(m, "-01"))) + 1
  x <- so[as_of == t, state_row_one_dose]; if (length(x)) x else NA_real_ })]
em[, reported_then_pct := 100 * reported_then / pop16_tx]
out(em, "statewide_early_rollout")
print(em)

# ===========================================================================
# 8. Figures
# ===========================================================================
msg("Figures")
cap_src <- "Source: Texas DSHS county vaccine workbooks (Internet Archive captures); U.S. Census Bureau Vintage 2025 population estimates."
cap_src2 <- "Source: Texas DSHS county vaccine workbooks (Internet Archive captures);\nU.S. Census Bureau Vintage 2025 population estimates."

# ---- Figure 1: why county counts before mid-April 2021 are not used ---------
un <- fread(file.path(DIR_TAB, "verify_13a_unassigned_daily.csv")); un[, as_of := as.Date(as_of)]
un <- un[!as_of %in% as.Date(c("2021-03-12", "2021-10-06")) & as_of >= as.Date("2021-01-13")]
lump <- fread(file.path(DIR_TAB, "verify_13b_reassignment_by_county.csv"))
p1a <- ggplot(un, aes(as_of, unassigned_pct)) +
  geom_line(colour = PAL$blue, linewidth = 0.8, lineend = "round") +
  annotate("segment", x = DSHS_COUNTY_FIX_DATE, xend = DSHS_COUNTY_FIX_DATE, y = 0, yend = 11.4, colour = PAL$axis, linewidth = 0.3) +
  annotate("text", x = DSHS_COUNTY_FIX_DATE + 5, y = 10.9, hjust = 0, vjust = 1, family = FONT, size = 3.3, colour = PAL$ink2, lineheight = 1.05,
           label = "Edition of 15 Apr 2021: 662,780 people\nmoved into counties in one day") +
  annotate("segment", x = GRIDS$main[1], xend = GRIDS$main[1], y = 0, yend = 6.4, colour = PAL$axis, linewidth = 0.3) +
  annotate("text", x = GRIDS$main[1] + 5, y = 6.1, hjust = 0, vjust = 1, family = FONT, size = 3.3, colour = PAL$ink2, lineheight = 1.05,
           label = "Edition of 25 May 2021:\nbaseline of this study") +
  scale_x_date(date_breaks = "1 month", date_labels = "%b\n%Y", expand = expansion(mult = c(0.01, 0.03))) +
  scale_y_continuous(limits = c(0, 11.5), breaks = seq(0, 10, 2), labels = function(x) paste0(x, "%"), expand = c(0, 0)) +
  labs(title = "Until mid-April 2021, 5-11% of vaccinated Texans had no county on record",
       subtitle = "First-dose recipients not assigned to any county, as a share of the state total, by DSHS edition date",
       x = NULL, y = NULL) + theme_tx()
p1b <- ggplot(lump, aes(reassigned_pct_of_prior_count)) +
  geom_histogram(breaks = seq(-5, 35, 2.5), fill = PAL$blue, colour = PAL$surface, linewidth = 0.6) +
  scale_x_continuous(breaks = seq(-5, 35, 5), labels = function(x) paste0(x, "%")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(title = "The correction was far from even across counties",
       subtitle = "Counties by how much the 15 April 2021 edition added to their previous first-dose count",
       x = "People added, as a share of the county's count in the previous edition", y = "Counties",
       caption = paste("Each edition holds records through the previous day. Two faulty daily editions (12 March and 6 October 2021) are left out.",
                       "Source: daily copies of the Texas DSHS county vaccine workbook, verified against the original workbooks.", sep = "\n")) +
  theme_tx()
save_fig(p1a / p1b + plot_layout(heights = c(1.1, 1)), "fig01_unassigned_records", 8.2, 8.4)

# ---- Figure 2: recorded coverage maps ---------------------------------------
cov_breaks <- c(-Inf, 40, 50, 60, 70, 80, Inf)
cov_labels <- c("Under 40%", "40-50%", "50-60%", "60-70%", "70-80%", "80% or more")
m2 <- rbindlist(lapply(c(GRIDS$main[1], mid_asof, max(GRIDS$main)), function(a)
  ed[as_of == a, .(fips, cov16, panel = paste("Through", fmt_date(a - 1)))]))
m2[, panel := factor(panel, levels = unique(panel))]
m2 <- merge(m2, flags[, .(fips, flag = excl_county)], by = "fips")
m2[, cls := as.character(cut(cov16, cov_breaks, cov_labels, right = FALSE))]
m2[flag == TRUE, cls := "Records exceed population"]
m2[, cls := factor(cls, levels = c(cov_labels, "Records exceed population"))]
g2 <- merge(shape, m2, by = "fips")
p2 <- ggplot(g2) + geom_sf(aes(fill = cls), colour = PAL$surface, linewidth = 0.1, show.legend = TRUE) + facet_wrap(~panel, nrow = 1) +
  scale_fill_manual(values = setNames(c(PAL$seq6, PAL$flag), levels(m2$cls)), drop = FALSE, name = NULL,
                    guide = guide_legend(nrow = 1, label.position = "bottom", keywidth = unit(2.6, "lines"), keyheight = unit(0.6, "lines"))) +
  coord_sf(datum = NA) +
  labs(title = "Recorded first-dose coverage of residents aged 16 and over",
       subtitle = "People recorded with at least one dose, as a share of the county's 1 July 2021 population estimate",
       caption = paste("Grey: 16 counties whose recorded count exceeds their adult population at some point; their records cannot be read as resident coverage.",
                       cap_src, sep = "\n")) +
  theme_tx_map()
save_fig(p2, "fig02_recorded_coverage_maps", 11.5, 5.3)
out(dcast(m2, fips ~ panel, value.var = "cov16"), "fig02_recorded_coverage")

# ---- Figure 3: change in recorded coverage ----------------------------------
ch_breaks <- c(-Inf, 15, 20, 25, 30, 35, Inf)
ch_labels <- c("Under 15", "15-20", "20-25", "25-30", "30-35", "35 or more")
m3 <- ct[, .(fips, flag = excl_county, change_pp)]
m3[, cls := as.character(cut(change_pp, ch_breaks, ch_labels, right = FALSE))]
m3[flag == TRUE, cls := "Records exceed population"]
m3[, cls := factor(cls, levels = c(ch_labels, "Records exceed population"))]
p3 <- ggplot(merge(shape, m3, by = "fips")) + geom_sf(aes(fill = cls), colour = PAL$surface, linewidth = 0.12, show.legend = TRUE) +
  scale_fill_manual(values = setNames(c(PAL$seq6, PAL$flag), levels(m3$cls)), drop = FALSE, name = "Percentage points",
                    guide = guide_legend(nrow = 1, label.position = "bottom", title.position = "top",
                                         keywidth = unit(2.6, "lines"), keyheight = unit(0.6, "lines"))) +
  coord_sf(datum = NA) +
  labs(title = "Change in recorded coverage, 24 May 2021 to 9 May 2023",
       subtitle = "Percentage-point gain in the share of residents aged 16+ recorded with at least one dose",
       caption = paste("Grey: counties whose recorded count exceeds their adult population.", cap_src2, sep = "\n")) +
  theme_tx_map()
save_fig(p3, "fig03_coverage_change_map", 7.4, 6.9)

# ---- Figure 6: uptake over time ----------------------------------------------
terc <- ck[, .(fips, tercile = cut(cov_baseline, quantile(cov_baseline, 0:3 / 3), include.lowest = TRUE,
                                   labels = c("Lowest third at baseline", "Middle third", "Highest third at baseline")))]
tu <- merge(d[usable == TRUE], terc, by = "fips")[, .(u = 100 * (1 - (1 - sum(y_model) / sum(at_risk))^(30 / days[1]))),
                                                   by = .(tercile, k)]
tu <- merge(tu, iv, by = "k")
out(tu[, .(tercile, k, label, uptake30_pct = u)], "fig06b_uptake_by_baseline_third")
lab_sw <- sw[k == 3]
p4a <- ggplot(sw) +
  geom_rect(aes(xmin = data_from, xmax = data_to + 1, ymin = county_p10, ymax = county_p90), fill = PAL$blue, alpha = 0.12) +
  geom_segment(aes(x = data_from, xend = data_to + 1, y = county_median, yend = county_median), colour = PAL$blue, linewidth = 0.9, lineend = "round") +
  geom_segment(aes(x = data_from, xend = data_to + 1, y = recorded_pooled, yend = recorded_pooled), colour = PAL$ink2, linewidth = 0.9, lineend = "round") +
  annotate("text", x = lab_sw$data_to + 8, y = lab_sw$recorded_pooled + 0.5, label = "All 238 counties pooled (recorded)", hjust = 0, family = FONT, size = 3.2, colour = PAL$ink2) +
  annotate("text", x = lab_sw$data_to + 8, y = lab_sw$county_median - 0.6, label = "Median county (modelled); band: 10th to 90th percentile county", hjust = 0, family = FONT, size = 3.2, colour = PAL$ink2) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y", expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Uptake among adults not yet vaccinated, per 30 days",
       subtitle = "Each bar spans one interval between DSHS editions; 238 counties",
       x = NULL, y = NULL) + theme_tx()
tcol <- setNames(c(PAL$orange, PAL$aqua, PAL$blue), levels(terc$tercile))
p4b <- ggplot(tu, aes(colour = tercile)) +
  geom_segment(aes(x = data_from, xend = data_to + 1, y = u, yend = u), linewidth = 0.9, lineend = "round") +
  geom_line(aes(x = mid, y = u), linewidth = 0.3, alpha = 0.55) +
  scale_colour_manual(values = tcol, name = NULL) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y", expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Counties that started behind were also slower afterwards",
       subtitle = "Recorded uptake per 30 days, counties grouped by recorded coverage on 24 May 2021",
       x = NULL, y = NULL, caption = cap_src) + theme_tx()
save_fig(p4a / p4b, "fig06_uptake_curves", 8.6, 9.2)

# ---- Figure 7: recorded and modelled uptake in six counties of different size
pick <- c("48201", "48303", "48165", "48351", "48263", "48269")       # Harris, Lubbock, Gaines, Newton, Kent, King
e11 <- tab_u[fips %in% pick]
e11 <- merge(e11, iv[, .(k, data_from, data_to, mid)], by = "k")
e11[, lab := sprintf("%s County (%s adults)", county, trimws(format(pop16, big.mark = ",")))]
e11[, lab := factor(lab, levels = unique(e11[order(-pop16), lab]))]
p11 <- ggplot(e11) +
  geom_rect(aes(xmin = data_from, xmax = data_to + 1, ymin = modelled_lo, ymax = modelled_hi), fill = PAL$blue, alpha = 0.18) +
  geom_segment(aes(x = data_from, xend = data_to + 1, y = modelled_uptake30_pct, yend = modelled_uptake30_pct),
               colour = PAL$blue, linewidth = 0.8, lineend = "round") +
  geom_point(aes(x = mid, y = recorded_uptake30_pct), colour = PAL$surface, size = 2.6) +
  geom_point(aes(x = mid, y = recorded_uptake30_pct), colour = PAL$ink, size = 1.5) +
  facet_wrap(~lab, ncol = 2, scales = "free_y") +
  scale_x_date(date_breaks = "6 months", date_labels = "%b\n%Y") +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Recorded and modelled uptake in six counties, from largest to smallest",
       subtitle = "Uptake per 30 days among adults not yet vaccinated. Dots: recorded. Blue line and band: modelled median and 95% credible interval",
       x = NULL, y = NULL, caption = cap_src) + theme_tx()
save_fig(p11, "fig07_county_examples", 9.4, 9.2)

# ---- Figure 8: modelled relative uptake --------------------------------------
hr_breaks <- c(0, 0.6, 0.75, 0.9, 1 / 0.9, 1 / 0.75, 1 / 0.6, Inf)
hr_labels <- c("Under 0.60", "0.60-0.75", "0.75-0.90", "0.90-1.11", "1.11-1.33", "1.33-1.67", "Over 1.67")
mk <- function(v, title) {
  x <- ct[, .(fips, flag = excl_county, val = get(v))]
  x[, cls := as.character(cut(val, hr_breaks, hr_labels, right = FALSE))]
  x[flag == TRUE, cls := "Not modelled"]
  x[, cls := factor(cls, levels = c(hr_labels, "Not modelled"))]
  x[, panel := title]
  x
}
m5 <- rbind(mk("rel_uptake", sprintf("Relative uptake, all sources of difference (model %s)", FINAL)),
            mk("smooth_effect", sprintf("Spatially smooth county effect (model %s)", SPATIAL_MODEL)))
m5[, panel := factor(panel, levels = unique(panel))]
p5 <- ggplot(merge(shape, m5, by = "fips")) + geom_sf(aes(fill = cls), colour = PAL$surface, linewidth = 0.1, show.legend = TRUE) +
  facet_wrap(~panel, nrow = 1) +
  scale_fill_manual(values = setNames(c(PAL$div7, PAL$flag), levels(m5$cls)), drop = FALSE,
                    name = "Uptake hazard relative to the average county (1 = average)",
                    guide = guide_legend(nrow = 1, label.position = "bottom", title.position = "top",
                                         keywidth = unit(2.6, "lines"), keyheight = unit(0.6, "lines"))) +
  coord_sf(datum = NA) +
  labs(title = "Modelled uptake among unvaccinated adults, relative to the average county",
       subtitle = paste("Posterior medians, 25 May 2021 to 9 May 2023. Right: the part of a county's effect that it shares",
                        "with its neighbours and that the three predictors do not explain", sep = "\n"),
       caption = paste("Grey: counties left out of the model because their records exceed their population.", cap_src, sep = "\n")) +
  theme_tx_map()
save_fig(p5, "fig08_relative_uptake_maps", 11, 6.4)

# ---- Figure 9: counties with the highest and lowest relative uptake ---------
ex <- ct[!is.na(rel_uptake)][order(rel_uptake)]
ex <- rbind(ex[1:12][, grp := "Lowest 12"], ex[(.N - 11):.N][, grp := "Highest 12"])
ex[, lab := sprintf("%s (%s adults)", county, trimws(format(pop16, big.mark = ",")))]
ex[, lab := factor(lab, levels = lab)]
ex[, grp := factor(grp, levels = c("Highest 12", "Lowest 12"))]
p6 <- ggplot(ex, aes(y = lab)) +
  geom_vline(xintercept = 1, colour = PAL$axis, linewidth = 0.4) +
  geom_segment(aes(x = rel_uptake_lo, xend = rel_uptake_hi, yend = lab), colour = PAL$blue, linewidth = 0.7, lineend = "round") +
  geom_point(aes(x = rel_uptake), colour = PAL$surface, size = 3.4) +
  geom_point(aes(x = rel_uptake), colour = PAL$blue, size = 2.4) +
  facet_grid(grp ~ ., scales = "free_y", space = "free_y") +
  scale_x_log10(breaks = c(0.3, 0.5, 0.75, 1, 1.5, 2, 3)) +
  labs(title = "Counties at the extremes of modelled relative uptake",
       subtitle = "Uptake hazard relative to the average county: posterior median and 95% credible interval",
       x = "Relative uptake (log scale; 1 = average county)", y = NULL, caption = cap_src) +
  theme_tx() + theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = PAL$ink2))
save_fig(p6, "fig09_relative_uptake_extremes", 7.6, 7.6)

# ---- Figure 10: predictor associations ----------------------------------------
a7 <- assoc[contrast %like% "per 1 SD"]
a7[, outcome := factor(outcome, levels = c("Coverage reached by 24 May 2021", "Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023"),
                       labels = c("Coverage reached by 24 May 2021 (odds ratio)", "Uptake among unvaccinated adults, 25 May 2021 to 9 May 2023 (hazard ratio)"))]
a7[, predictor := factor(predictor, levels = rev(c("Share of adults aged 65+", "Median household income",
                                                   "Cumulative cases before 14 Dec 2020", "Cases in previous 30 days")))]
p7 <- ggplot(a7, aes(y = predictor)) +
  geom_vline(xintercept = 1, colour = PAL$axis, linewidth = 0.4) +
  geom_segment(aes(x = lo, xend = hi, yend = predictor), colour = PAL$blue, linewidth = 0.8, lineend = "round") +
  geom_point(aes(x = ratio), colour = PAL$surface, size = 4) + geom_point(aes(x = ratio), colour = PAL$blue, size = 2.8) +
  geom_text(aes(x = max(a7$hi) + 0.03, label = sprintf("%.2f (%.2f to %.2f)", ratio, lo, hi)), hjust = 0, family = FONT, size = 3.2, colour = PAL$ink2) +
  facet_wrap(~outcome, scales = "free_y", ncol = 1) +
  scale_x_continuous(limits = c(min(0.8, min(a7$lo) - 0.02), max(a7$hi) + 0.2), breaks = seq(0.7, 1.3, 0.1)) +
  labs(title = "County-level associations with coverage and uptake",
       subtitle = "Ratio per one standard deviation of each predictor: posterior median and 95% credible interval",
       x = "Ratio (1 = no association)", y = NULL,
       caption = "These are associations between county characteristics and county outcomes; they do not describe individuals.") +
  theme_tx() + theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = PAL$ink2))
save_fig(p7, "fig10_predictor_associations", 8.2, 5.2)

# ---- Figure 4: gaps between counties ------------------------------------------
g8 <- copy(gp)
lab8 <- g8[.N]
p8a <- ggplot(g8, aes(data_through)) +
  geom_ribbon(aes(ymin = p10, ymax = p90), fill = PAL$blue, alpha = 0.12) +
  geom_ribbon(aes(ymin = p25, ymax = p75), fill = PAL$blue, alpha = 0.16) +
  geom_line(aes(y = median), colour = PAL$blue, linewidth = 0.9, lineend = "round") +
  geom_point(aes(y = median), colour = PAL$surface, size = 2.6) + geom_point(aes(y = median), colour = PAL$blue, size = 1.7) +
  annotate("text", x = lab8$data_through + 12, y = c(lab8$p90, lab8$median, lab8$p10), hjust = 0, family = FONT, size = 3.2, colour = PAL$ink2,
           label = c("90th percentile", "Median county", "10th percentile")) +
  annotate("text", x = g8$data_through[1] + 6, y = g8$p90[1] + 3.2, hjust = 0, family = FONT, size = 3.2, colour = PAL$ink2,
           label = sprintf("Gap %.1f points", g8$gap_p90_p10[1])) +
  annotate("text", x = lab8$data_through - 6, y = lab8$p90 + 3.2, hjust = 1, family = FONT, size = 3.2, colour = PAL$ink2,
           label = sprintf("Gap %.1f points", lab8$gap_p90_p10)) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y", expand = expansion(mult = c(0.02, 0.2))) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "The spread of recorded coverage across counties widened",
       subtitle = "Recorded 16+ first-dose coverage at each DSHS edition, 238 counties:\nmedian county, middle half of counties (darker band), 10th to 90th percentile (lighter band)",
       x = NULL, y = NULL) + theme_tx()
p8b <- ggplot(ck, aes(cov_baseline, change_pp)) +
  geom_point(colour = PAL$surface, size = 2.6) + geom_point(colour = PAL$blue, size = 1.7, alpha = 0.85) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = PAL$ink2, linewidth = 0.6) +
  annotate("text", x = min(ck$cov_baseline), y = max(ck$change_pp), hjust = 0, vjust = 1, family = FONT, size = 3.2, colour = PAL$ink2,
           label = sprintf("Each extra point at baseline goes with %+.2f points of later gain\n(correlation %.2f; 238 counties)",
                           coef(conv)[2], cor(ck$cov_baseline, ck$change_pp))) +
  scale_x_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Later gains against starting coverage",
       subtitle = "Each dot is a county; gain in percentage points, 24 May 2021 to 9 May 2023",
       x = "Recorded coverage on 24 May 2021", y = "Percentage-point gain", caption = cap_src) + theme_tx()
save_fig(p8a / p8b, "fig04_gaps_between_counties", 8.6, 9.4)

# ---- Figure 5 and model comparison table: out-of-sample performance -----------
short <- c(M0 = "M0  Non-spatial county effects", M1 = "M1  BYM2 county effects", M2 = "M2  BYM2 + county linear trends",
           M3 = "M3  BYM2 + county random walks", M4 = "M4  BYM2 + county mean-reverting paths")
vs <- list()
exps <- c(counties = "A. Counties with no data\n(10 random folds)", regions = "B. Regions with no data\n(8 public health regions)",
          later = "C. Later intervals,\nhalf the counties withheld", forecast = "D. Next interval,\nall counties withheld")
for (e in names(exps)) {
  f <- file.path(DIR_TAB, sprintf("validation_%s_summary.csv", e))
  if (file.exists(f)) vs[[exps[[e]]]] <- fread(f)
}
if (length(vs)) {
  v9 <- rbindlist(lapply(names(vs), function(n) cbind(experiment = n, vs[[n]])), fill = TRUE)
  v9[, experiment := factor(experiment, levels = names(vs))]
  v9[, lab := factor(short[model], levels = rev(short))]
  out(v9, "fig05_validation_summary")
  p9 <- ggplot(v9, aes(mean_crps_pp, lab)) +
    geom_segment(aes(x = 0, xend = mean_crps_pp, yend = lab), colour = PAL$grid, linewidth = 0.5) +
    geom_point(colour = PAL$surface, size = 4) + geom_point(colour = PAL$blue, size = 2.8) +
    geom_text(aes(label = sprintf("%.2f", mean_crps_pp)), hjust = -0.4, family = FONT, size = 3.1, colour = PAL$ink2) +
    facet_wrap(~experiment, nrow = 1, scales = "free_x") +
    scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.35))) +
    labs(title = "Out-of-sample prediction error by model",
         subtitle = "Mean continuous ranked probability score for uptake per 30 days, in percentage points (lower is better)",
         x = NULL, y = NULL,
         caption = paste("Each model was refitted with the tested county-intervals withheld and scored on its predictive distribution for them.",
                         "Models without a dot were not run in that experiment.", sep = "\n")) +
    theme_tx() + theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = PAL$ink2, hjust = 0))
  save_fig(p9, "fig05_validation", 12.2, 3.9)
  fs <- fread(file.path(DIR_MOD, "fit_statistics.csv"))
  cmp <- dcast(v9, model ~ experiment, value.var = c("mean_crps_pp", "mean_log_score", "mae_pp", "coverage95"))
  cmp <- merge(fs[, .(model, label, waic, mean_log_cpo, cpo_failures, seconds)], cmp, by = "model", all.x = TRUE)
  out(cmp, "model_comparison")
}

# ---- Figure 11: recorded versus modelled uptake -------------------------------
scol <- setNames(c(PAL$orange, PAL$aqua, PAL$blue), levels(us$size))
p10a <- ggplot(us[recorded_uptake30_pct > 0], aes(recorded_uptake30_pct, modelled_uptake30_pct, colour = size)) +
  geom_abline(colour = PAL$axis, linewidth = 0.4) +
  geom_point(size = 1.1, alpha = 0.7) +
  scale_colour_manual(values = scol, name = "County size", guide = guide_legend(override.aes = list(size = 2.6, alpha = 1))) +
  scale_x_log10(breaks = c(0.01, 0.1, 1, 10), labels = function(x) paste0(x, "%")) +
  scale_y_log10(breaks = c(0.01, 0.1, 1, 10), labels = function(x) paste0(x, "%")) +
  labs(title = "Modelled uptake follows the records, except where numbers are tiny",
       subtitle = "Each dot is a county-interval; uptake per 30 days among unvaccinated adults, log scales; line marks equality",
       x = "Recorded", y = "Modelled (posterior median)") + theme_tx()
vf <- file.path(DIR_TAB, sprintf("validation_counties_endcoverage_%s.csv", SPATIAL_MODEL))   # the best model for this task
if (file.exists(vf)) {
  ve <- fread(vf, colClasses = list(character = "fips"))
  ve[, err := pred_cov_end - obs_cov_end]
  eb <- c(-Inf, -10, -5, -2, 2, 5, 10, Inf)
  el <- c("Under -10", "-10 to -5", "-5 to -2", "-2 to +2", "+2 to +5", "+5 to +10", "Over +10")
  m10 <- merge(flags[, .(fips, flag = excl_county)], ve[, .(fips, err)], by = "fips", all.x = TRUE)
  m10[, cls := as.character(cut(err, eb, el, right = FALSE))]
  m10[flag == TRUE | is.na(err), cls := "Not modelled"]
  m10[, cls := factor(cls, levels = c(el, "Not modelled"))]
  p10b <- ggplot(merge(shape, m10, by = "fips")) + geom_sf(aes(fill = cls), colour = PAL$surface, linewidth = 0.1, show.legend = TRUE) +
    scale_fill_manual(values = setNames(c(rev(PAL$div7), PAL$flag), levels(m10$cls)), drop = FALSE,
                      name = "Predicted minus recorded coverage on 9 May 2023, percentage points",
                      guide = guide_legend(nrow = 1, label.position = "bottom", title.position = "top",
                                           keywidth = unit(2.4, "lines"), keyheight = unit(0.6, "lines"))) +
    coord_sf(datum = NA) +
    labs(title = "What neighbours and predictors alone would have predicted",
         subtitle = sprintf("Each county's uptake was withheld and predicted from the other counties (model %s).\nBlue: the county did better than predicted. Red: it did worse.", SPATIAL_MODEL),
         caption = cap_src) + theme_tx_map()
  save_fig(p10a / p10b + plot_layout(heights = c(1, 1.35)), "fig11_smoothing_checks", 8.2, 11.6)
  out(ve[, .(fips, county, obs_cov_end, pred_cov_end, lo, hi, err)], "fig11_heldout_county_prediction")
} else {
  save_fig(p10a, "fig11_smoothing_checks", 8.2, 5.2)
}
msg("Done.")
