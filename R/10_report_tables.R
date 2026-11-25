# 10_report_tables.R -- build docs/02_report.md from its template and the result files.
#
#   Rscript --vanilla R/10_report_tables.R
#
# 1. Formats every result table quoted in the report -> outputs/tables/report_tables.md
# 2. Computes the model-dependent numbers quoted in the text -> outputs/tables/report_values.csv
# 3. Fills docs/02_report_template.md ({{TABLE:title}} and {{v:key}} markers) -> docs/02_report.md
#
# The report therefore cannot drift from the result files: rerunning the
# analysis and this script rewrites every table and model-dependent number.

source("R/_common.R")
source("R/_report.R")          # rd, md, ci, f1, pct0, fill_template
options(scipen = 999)
out <- character()
tables <- list()
add <- function(title, lines) { out <<- c(out, "", paste0("### ", title), "", lines); tables[[title]] <<- lines }

# 1. Statewide by interval
sw <- rd("statewide_by_interval.csv")
add("Recorded first doses and coverage by interval",
    md(sw[, .(Interval = k, Records = label, Days = days, `New first doses, all counties` = new_first_doses,
              `Coverage at end, all counties (%)` = cov_end, `Uptake per 30 days, all counties (%)` = uptake30_pct,
              `Coverage at end, 238 counties (%)` = cov_end_kept, `Uptake per 30 days, 238 counties (%)` = uptake30_pct_kept)],
       digits = list(Interval = 0, Days = 0, `New first doses, all counties` = 0)))

er <- rd("statewide_early_rollout.csv")
add("Statewide first doses by month of vaccination, before the baseline",
    md(er[, .(`Month of vaccination` = format(as.Date(paste0(month, "-01")), "%B %Y"), `First doses` = first_doses,
              `Texans 16+ with a first dose at month end (%)` = coverage_end_pct,
              `Uptake among those not yet vaccinated, per 30 days (%)` = uptake30_pct,
              `Coverage the state reported at the time (%)` = reported_then_pct)],
       digits = list(`First doses` = 0, `Texans 16+ with a first dose at month end (%)` = 1,
                     `Uptake among those not yet vaccinated, per 30 days (%)` = 1, `Coverage the state reported at the time (%)` = 1)))

# 2. Gap measures
gp <- rd("fig04_gap_over_time.csv")
g2 <- gp[as.Date(as_of) %in% GRIDS$main[c(1, 5, 10, 11, 13)]]
add("Recorded 16+ coverage across the 238 counties kept in the model",
    md(g2[, .(`Records through` = format(as.Date(data_through), "%d %b %Y"), `10th percentile` = p10, `25th` = p25, Median = median,
              `75th` = p75, `90th percentile` = p90, `Gap 90th - 10th (points)` = gap_p90_p10, `Standard deviation` = sd,
              `Pooled coverage` = pooled)], digits = list()))
add("Gap summary", md(rd("gap_summary.csv"), digits = list(value = 2)))

# 3. Model comparison
if (file.exists(file.path(DIR_TAB, "model_comparison.csv"))) {
  mc <- rd("model_comparison.csv")
  v <- rd("fig05_validation_summary.csv")
  v[, experiment := gsub("\n", " ", experiment)]
  add("Out-of-sample performance (lower CRPS and errors are better; higher log score and correlation are better)",
      md(v[, .(Experiment = experiment, Model = model, `County-intervals` = rows, `Mean CRPS (points)` = mean_crps_pp,
               `Mean absolute error (points)` = mae_pp, `Mean log score` = mean_log_score,
               `95% interval coverage` = coverage95, `Mean 95% interval width (points)` = mean_width95_pp,
               `Relative log-hazard RMSE` = rmse_relative_log_hazard, `Relative log-hazard correlation` = cor_relative_log_hazard,
               `End coverage: counties` = end_counties, `End coverage: mean abs. error (points)` = end_coverage_mae_pp,
               `End coverage: inside 95% interval` = end_coverage_in95)],
         digits = list(`County-intervals` = 0, `Mean CRPS (points)` = 3, `Mean absolute error (points)` = 3, `Mean log score` = 3,
                       `95% interval coverage` = 3, `Relative log-hazard RMSE` = 3, `Relative log-hazard correlation` = 3,
                       `End coverage: counties` = 0, `End coverage: inside 95% interval` = 3)))
  add("In-sample statistics", md(mc[, .(Model = label, WAIC = waic, `Mean log CPO` = mean_log_cpo, `CPO values flagged` = cpo_failures,
                                         `Seconds to fit` = seconds)],
                                 digits = list(WAIC = 0, `Mean log CPO` = 3, `CPO values flagged` = 0, `Seconds to fit` = 0)))
}
if (file.exists(file.path(DIR_TAB, "validation_later_by_origin.csv"))) {
  e <- rd("validation_later_by_origin.csv")
  add("Experiment C by origin: mean CRPS (points)", md(dcast(e, origin ~ model, value.var = "mean_crps_pp"), digits = list(origin = 0)))
  add("Experiment C by origin: coverage on 9 May 2023 predicted for the withheld counties, mean absolute error (points)",
      md(dcast(e, origin ~ model, value.var = "end_coverage_mae_pp"), digits = list(origin = 0)))
  h <- rd("validation_later_by_horizon.csv")
  add("Experiment C by horizon: mean CRPS (points)", md(dcast(h, hgroup ~ model, value.var = "mean_crps_pp")))
}
if (file.exists(file.path(DIR_TAB, "validation_forecast_by_origin.csv"))) {
  e <- rd("validation_forecast_by_origin.csv")
  # The forecast from origin k - 1 is for interval k
  fl <- sw[, .(origin = k - 1L, `Interval forecast` = label,
               `Pooled recorded uptake in the interval before (%)` = shift(uptake30_pct_kept),
               `Pooled recorded uptake in this interval (%)` = uptake30_pct_kept)]
  dtab <- function(col) merge(fl, dcast(e, origin ~ model, value.var = col), by = "origin")[order(origin)][, origin := NULL]
  add("Experiment D by forecast interval: mean CRPS (points)", md(dtab("mean_crps_pp")))
  add("Experiment D by forecast interval: mean error, predicted minus recorded (points per 30 days)", md(dtab("bias_pp")))
}
PD <- NULL
if (file.exists(file.path(DIR_TAB, "validation_paired_differences.csv"))) {
  PD <- rd("validation_paired_differences.csv")
  ci3 <- function(m, lo, hi) ifelse(is.na(m), "", nz(sprintf("%.3f (%.3f to %.3f)", m, lo, hi)))
  pair <- function(e, s, a, b) data.table(experiment = e, subset = s, first = a, second = b)
  want <- rbind(pair("A", "all", c("M0", "M1", "M1"), c("M1", "M2", "M4")),
                pair("B", "all", c("M0", "M1"), c("M1", "M4")),
                pair("C", "all", c("M0", "M1", "M1", "M3"), c("M1", "M3", "M4", "M4")),
                pair("C", "1 interval ahead", c("M1", "M1", "M3"), c("M3", "M4", "M4")),
                pair("C", "2-3 ahead", c("M1", "M1", "M3"), c("M3", "M4", "M4")),
                pair("C", "4 or more ahead", c("M1", "M1", "M3"), c("M3", "M4", "M4")),
                pair("D", "all", c("M0", "M1", "M3"), c("M1", "M4", "M4")))
  pw2 <- merge(want, PD, by = c("experiment", "subset", "first", "second"), sort = FALSE)
  add("Differences between models on the same county-intervals (second model minus first, 95% bootstrap interval)",
      md(pw2[, .(Experiment = experiment, `County-intervals` = fifelse(subset == "all", "all scored", subset),
                 Comparison = paste(second, "minus", first),
                 `Mean CRPS (points)` = ci3(diff_crps_pp, diff_crps_lo, diff_crps_hi),
                 `Mean log score` = ci3(diff_log_score, diff_log_score_lo, diff_log_score_hi),
                 `End coverage: mean abs. error (points)` = ci3(diff_end_coverage_mae_pp, diff_end_coverage_mae_lo,
                                                                diff_end_coverage_mae_hi))]))
}

# 4. Parameters of the fitted models
fx <- fread(file.path(DIR_MOD, "fixed_effects.csv")); hy <- fread(file.path(DIR_MOD, "hyperparameters.csv"))
fx <- fx[term %in% c("z_age", "z_income", "z_cases")]
fx[, est := ci(exp(median), exp(q025), exp(q975))]
plab <- c(z_age = "Share of adults aged 65+", z_income = "Median household income", z_cases = "Cases in previous 30 days")
fw <- dcast(fx, model ~ term, value.var = "est")
add("Hazard ratios per standard deviation, all uptake models",
    md(fw[, .(Model = model, `Share of adults aged 65+` = z_age, `Median household income` = z_income, `Cases in previous 30 days` = z_cases)]))
hy[, est := ci(median, q025, q975)]
hlab <- c("SD of cid" = "County effect, standard deviation",
          "Phi for cid" = "County effect, spatially structured share",
          "SD of tid" = "Shared time effect, standard deviation",
          "SD of cid2" = "County slope per year, standard deviation (M2)",
          "SD of tid2" = "County-specific course, standard deviation (M3, M4)",
          "Phi for tid2" = "County-specific course, mean-reversion rate per month (M4)",
          "SD of oid" = "County-interval deviation, standard deviation")
hw <- dcast(hy, parameter ~ model, value.var = "est", fill = "")
hw <- hw[match(names(hlab), parameter)][!is.na(parameter)]
hw[, parameter := hlab[parameter]]
setnames(hw, "parameter", "Parameter (log-hazard scale)")
add("Variance parameters of the fitted models (posterior median, 95% credible interval)", md(hw))
as <- rd("fig10_predictor_associations.csv")
add("Predictor associations, selected model and baseline model",
    md(as[, .(Outcome = outcome, Predictor = predictor, Contrast = contrast, Measure = measure, Estimate = ci(ratio, lo, hi))]))
if (file.exists(file.path(DIR_TAB, "period_specific_associations.csv"))) {
  ptab <- rd("period_specific_associations.csv")
  ptab[, est := ci(hazard_ratio, lo, hi)]
  pw <- dcast(ptab, predictor ~ period, value.var = "est")
  setnames(pw, sort(unique(ptab$period)), ptab[, .(l = period_label[1]), keyby = period]$l)
  pw <- pw[match(names(plab), predictor)]
  pw[, predictor := plab[predictor]]
  setnames(pw, "predictor", "Predictor")
  add("Hazard ratios per standard deviation by period", md(pw))
}
bf <- fread(file.path(DIR_MOD, "baseline_hyperparameters.csv")); bf[, est := ci(median, q025, q975)]
add("Baseline coverage model hyperparameters", md(dcast(bf, parameter ~ model, value.var = "est", fill = "")))

# 5. Counties
ct <- rd("county_results.csv", colClasses = list(character = "fips"))
k <- ct[excl_county == FALSE]
fmt <- function(x) x[, .(County = county, `Adults 16+` = pop16, `Coverage 24 May 2021 (%)` = cov_baseline,
                         `Coverage 9 May 2023 (%)` = cov_end, `Change (points)` = change_pp,
                         `Relative uptake (95% CrI)` = ci(rel_uptake, rel_uptake_lo, rel_uptake_hi))]
add("Largest recorded gains (kept counties)", md(fmt(k[order(-change_pp)][1:10]), digits = list(`Adults 16+` = 0, `Coverage 24 May 2021 (%)` = 1, `Coverage 9 May 2023 (%)` = 1, `Change (points)` = 1)))
add("Smallest recorded gains (kept counties)", md(fmt(k[order(change_pp)][1:10]), digits = list(`Adults 16+` = 0, `Coverage 24 May 2021 (%)` = 1, `Coverage 9 May 2023 (%)` = 1, `Change (points)` = 1)))
add("Lowest recorded coverage on 9 May 2023 (kept counties)", md(fmt(k[order(cov_end)][1:10]), digits = list(`Adults 16+` = 0, `Coverage 24 May 2021 (%)` = 1, `Coverage 9 May 2023 (%)` = 1, `Change (points)` = 1)))
add("Ten most populous kept counties", md(fmt(k[order(-pop16)][1:10]), digits = list(`Adults 16+` = 0, `Coverage 24 May 2021 (%)` = 1, `Coverage 9 May 2023 (%)` = 1, `Change (points)` = 1)))
add("Counties left out of the models (recorded count exceeds population estimate)",
    md(ct[excl_county == TRUE][order(-cov_end), .(County = county, `Adults 16+` = pop16, `Recorded coverage 24 May 2021 (%)` = cov_baseline,
                                                  `Recorded coverage 9 May 2023 (%)` = cov_end)],
       digits = list(`Adults 16+` = 0, `Recorded coverage 24 May 2021 (%)` = 1, `Recorded coverage 9 May 2023 (%)` = 1)))
add("Modelled versus recorded change in coverage (kept counties)",
    md(k[, .(Counties = .N, `Median absolute difference (points)` = median(abs(modelled_change_pp - change_pp), na.rm = TRUE),
             `Largest absolute difference (points)` = max(abs(modelled_change_pp - change_pp), na.rm = TRUE),
             `Recorded change inside modelled 95% interval (%)` = 100 * mean(change_pp >= modelled_change_lo & change_pp <= modelled_change_hi, na.rm = TRUE))],
       digits = list(Counties = 0, `Median absolute difference (points)` = 3)))

# 6. Smoothing and sensitivity
add("Recorded versus modelled uptake by county size",
    md(rd("smoothing_recorded_vs_modelled.csv")[, .(
         `County size` = size, `County-intervals` = county_intervals, Counties = counties,
         `Median absolute difference (points per 30 days)` = median_abs_diff_pp,
         `95th percentile of the difference (points)` = p95_abs_diff_pp,
         `Median difference as % of the recorded rate` = median_abs_rel_diff_pct,
         `Recorded rate inside the modelled 95% interval (%)` = recorded_inside_95_interval_pct,
         `Median width of the 95% interval (points)` = median_interval_width_pp,
         `Correlation, recorded and modelled` = cor_recorded_modelled,
         `Correlation, recorded and modelled without the county-interval deviation` = cor_recorded_structural)],
       digits = list(`County-intervals` = 0, Counties = 0, `Median absolute difference (points per 30 days)` = 3,
                     `95th percentile of the difference (points)` = 3, `Median difference as % of the recorded rate` = 1,
                     `Recorded rate inside the modelled 95% interval (%)` = 1, `Correlation, recorded and modelled` = 4,
                     `Correlation, recorded and modelled without the county-interval deviation` = 4)))
ss <- rd("smoothing_summary.csv")
add("Smoothing summary", md(ss[, .(item, value = ifelse(abs(value) < 1e-3 & value != 0, formatC(value, format = "e", digits = 1),
                                                         formatC(value, format = "f", digits = 3)))]))
lc <- rd("smoothing_local_contrasts.csv")
add("Counties most different from the mean of their neighbours (residual county effect ratio)",
    md(rbind(lc[1:8], lc[(.N - 7):.N])[, .(County = county, `Adults 16+` = pop16, `Ratio to neighbours (95% CrI)` = ci(local_ratio, local_lo, local_hi),
                                           `Coverage 9 May 2023 (%)` = cov_end)], digits = list(`Adults 16+` = 0, `Coverage 9 May 2023 (%)` = 1)))
if (file.exists(file.path(DIR_TAB, "sensitivity.csv"))) {
  s <- rd("sensitivity.csv")
  add("Sensitivity analysis", md(s[, .(Variant = variant, Description = description, Counties = counties, `County-intervals` = county_intervals,
                                       `Age 65+ share` = ci(hr_age, hr_age_lo, hr_age_hi), Income = ci(hr_income, hr_income_lo, hr_income_hi),
                                       `Recent cases` = ci(hr_cases, hr_cases_lo, hr_cases_hi), `SD county` = sd_county,
                                       `Spatial share (phi)` = phi_spatial, `SD trajectory` = sd_trajectory, `SD county-interval` = sd_county_interval)],
                                 digits = list(Counties = 0, `County-intervals` = 0)))
}
bl <- rd("baseline_vs_later_uptake.csv")
add("Baseline coverage and later modelled uptake", md(bl))
rb <- NULL
if (file.exists(file.path(DIR_TAB, "relative_uptake_model_robustness.csv"))) {
  rb <- rd("relative_uptake_model_robustness.csv")
  add("County relative uptake under the other models, compared with the selected model",
      md(rb[, .(Model = model, `Compared with` = compared_with, Counties = counties, `Correlation (log scale)` = correlation_log_scale,
                `Median absolute difference (%)` = median_abs_diff_pct, `95th percentile (%)` = p95_abs_diff_pct,
                `Largest (%)` = max_abs_diff_pct, `County with the largest difference` = max_diff_county,
                `Its adults 16+` = max_diff_county_adults)],
         digits = list(Counties = 0, `Correlation (log scale)` = 4, `Its adults 16+` = 0)))
}
writeLines(out, file.path(DIR_TAB, "report_tables.md"))
msg("Wrote %s (%d lines)", file.path(DIR_TAB, "report_tables.md"), length(out))

# ---------------------------------------------------------------------------
# Model-dependent numbers quoted in the text ({{v:key}} in the template)
# ---------------------------------------------------------------------------
V <- list(final = FINAL_MODEL, spatial = SPATIAL_MODEL)
FM <- FINAL_MODEL

u <- rd("fig06_uptake_by_interval.csv")
for (kk in u$k) {
  V[[sprintf("pool_k%d", kk)]] <- f1(u[k == kk, recorded_pooled]); V[[sprintf("med_k%d", kk)]] <- f1(u[k == kk, county_median])
  V[[sprintf("p10_k%d", kk)]] <- f1(u[k == kk, county_p10]); V[[sprintf("p90_k%d", kk)]] <- f1(u[k == kk, county_p90])
}
V$rel_p10 <- f1(quantile(k$rel_uptake, 0.10), 2); V$rel_p90 <- f1(quantile(k$rel_uptake, 0.90), 2)
V$rel_ratio <- f1(quantile(k$rel_uptake, 0.90) / quantile(k$rel_uptake, 0.10), 1)
V$rel_min_county <- k[which.min(rel_uptake), county]; V$rel_min <- k[which.min(rel_uptake), ci(rel_uptake, rel_uptake_lo, rel_uptake_hi)]
V$rel_max_county <- k[which.max(rel_uptake), county]; V$rel_max <- k[which.max(rel_uptake), ci(rel_uptake, rel_uptake_lo, rel_uptake_hi)]
V$n_kept <- nrow(k); V$n_low <- k[rel_uptake_hi < 1, .N]; V$n_high <- k[rel_uptake_lo > 1, .N]
V$n_mid <- V$n_kept - V$n_low - V$n_high
big <- k[order(-pop16)][1:6]
V$rel_big <- paste(sprintf("%s %s", big$county, f1(big$rel_uptake, 1)), collapse = ", ")
V$chg_med <- f1(median(abs(k$modelled_change_pp - k$change_pp), na.rm = TRUE), 2)
V$chg_max <- f1(max(abs(k$modelled_change_pp - k$change_pp), na.rm = TRUE), 1)

hv <- function(m, p, d = 2) { x <- hy[model == m & parameter == p]; if (nrow(x)) x[, ci(median, q025, q975, d)] else "n/a" }
hm <- function(m, p) { x <- hy[model == m & parameter == p, median]; if (length(x)) x else NA_real_ }
V$phi_m1 <- hv("M1", "Phi for cid"); V$phi_m1_pct <- pct0(100 * hm("M1", "Phi for cid"))
V$phi_final <- hv(FM, "Phi for cid")
V$sd_county_m0 <- hv("M0", "SD of cid"); V$sd_county_m1 <- hv("M1", "SD of cid"); V$sd_county_final <- hv(FM, "SD of cid")
V$sd_dev_m1 <- hv("M1", "SD of oid"); V$sd_dev_final <- hv(FM, "SD of oid"); V$sd_time_final <- hv(FM, "SD of tid")
V$sd_path_final <- hv(FM, if (FM == "M2") "SD of cid2" else "SD of tid2")
ou <- hy[model == "M4" & parameter == "Phi for tid2"]
V$ou_halflife <- if (nrow(ou)) sprintf("%.1f months (95%% CrI %.1f to %.1f)", log(2) / ou$median, log(2) / ou$q975, log(2) / ou$q025) else "n/a"
V$county_fold_m1 <- f1(exp(1.96 * hm("M1", "SD of cid")) / exp(-1.96 * hm("M1", "SD of cid")), 1)

ga <- function(pred, con, meas) { x <- as[predictor == pred & grepl(con, contrast, fixed = TRUE) & measure == meas]; x[1, ci(ratio, lo, hi)] }
V$hr_age <- ga("Share of adults aged 65+", "per 1 SD", "hazard ratio"); V$hr_age_5 <- ga("Share of adults aged 65+", "per 5 points", "hazard ratio")
V$hr_inc <- ga("Median household income", "per 1 SD", "hazard ratio"); V$hr_inc_10 <- ga("Median household income", "per 10%", "hazard ratio")
V$hr_case <- ga("Cases in previous 30 days", "per 1 SD", "hazard ratio"); V$hr_case_dbl <- ga("Cases in previous 30 days", "per doubling", "hazard ratio")
V$or_age <- ga("Share of adults aged 65+", "per 1 SD", "odds ratio"); V$or_inc <- ga("Median household income", "per 1 SD", "odds ratio")
V$or_case <- ga("Cumulative cases before 14 Dec 2020", "per 1 SD", "odds ratio")
sc <- fread(file.path(DIR_DERIVED, "covariate_scaling.csv"))
V$sd_age_pts <- f1(sc[variable == "pct65_of_16plus", sd]); V$sd_inc_pct <- pct0(100 * (exp(sc[variable == "log_med_hh_income", sd]) - 1))
V$sd_case_fold <- f1(exp(sc[variable == "log_case_rate_prev30_plus10", sd]))
V$base_cor <- bl[1, ci(median, lo, hi)]; V$base_hr10 <- bl[2, ci(median, lo, hi)]
V$base_cor_pt <- f1(bl[1, median], 2); V$base_hr10_pt <- f1(bl[3, median], 2)
V$base_hr10_ols <- bl[3, sprintf("%.2f to %.2f", lo, hi)]
bh <- fread(file.path(DIR_MOD, "baseline_hyperparameters.csv"))
V$base_phi <- bh[model == "B1" & parameter == "Phi for cid", ci(median, q025, q975)]
V$base_sd <- bh[model == "B1" & parameter == "SD of cid", ci(median, q025, q975)]
fxa <- fread(file.path(DIR_MOD, "fixed_effects.csv"))
for (m in unique(fxa$model)) for (tm in c("z_age", "z_income", "z_cases")) {
  V[[sprintf("hr_%s_%s", sub("z_", "", tm), m)]] <- fxa[model == m & term == tm, ci(exp(median), exp(q025), exp(q975))]
}
if (exists("ptab")) for (i in seq_len(nrow(ptab))) V[[sprintf("hr_%s_%s", sub("z_", "", ptab$predictor[i]), ptab$period[i])]] <- ptab$est[i]
if (exists("ptab")) for (p in unique(ptab$period)) V[[paste0("label_", p)]] <- ptab[period == p, period_label][1]

if (file.exists(file.path(DIR_TAB, "fig05_validation_summary.csv"))) {
  v <- rd("fig05_validation_summary.csv"); v[, ex := substr(experiment, 1, 1)]
  val <- function(e, m, col) { x <- v[ex == e & model == m][[col]]; if (length(x)) x[1] else NA_real_ }
  for (e in c("A", "B", "C", "D")) for (m in paste0("M", 0:4)) {
    V[[sprintf("crps_%s_%s", e, m)]] <- if (is.na(val(e, m, "mean_crps_pp"))) "not run" else f1(val(e, m, "mean_crps_pp"), 2)
    V[[sprintf("cov_%s_%s", e, m)]] <- if (is.na(val(e, m, "coverage95"))) "not run" else pct0(100 * val(e, m, "coverage95"))
    V[[sprintf("cov1_%s_%s", e, m)]] <- if (is.na(val(e, m, "coverage95"))) "not run" else sprintf("%.1f%%", 100 * val(e, m, "coverage95"))
    V[[sprintf("end_%s_%s", e, m)]] <- if (e == "D" || is.na(val(e, m, "end_coverage_mae_pp"))) "not run" else f1(val(e, m, "end_coverage_mae_pp"), 1)
    V[[sprintf("cor_%s_%s", e, m)]] <- if (is.na(val(e, m, "cor_relative_log_hazard"))) "not run" else f1(val(e, m, "cor_relative_log_hazard"), 2)
    V[[sprintf("width_%s_%s", e, m)]] <- if (is.na(val(e, m, "mean_width95_pp"))) "not run" else f1(val(e, m, "mean_width95_pp"), 1)
  }
  for (e in c("A", "B", "C", "D")) for (w in c("crps", "cov", "end", "cor", "width")) {
    V[[sprintf("%s_%s_final", w, e)]] <- V[[sprintf("%s_%s_%s", w, e, FM)]]
  }
  impr <- function(e, m, ref) pct0(100 * (1 - val(e, m, "mean_crps_pp") / val(e, ref, "mean_crps_pp")))
  V$worse_A_M4 <- pct0(100 * (val("A", "M4", "mean_crps_pp") / val("A", "M1", "mean_crps_pp") - 1))
  V$worse_A_M2 <- pct0(100 * (val("A", "M2", "mean_crps_pp") / val("A", "M1", "mean_crps_pp") - 1))
  V$worse_B_M4 <- pct0(100 * (val("B", "M4", "mean_crps_pp") / val("B", "M1", "mean_crps_pp") - 1))
  V$impr_A_M1 <- impr("A", "M1", "M0"); V$impr_B_M1 <- impr("B", "M1", "M0")
  V$impr_C_final <- impr("C", FM, "M1"); V$impr_D_final <- impr("D", FM, "M1"); V$impr_A_final <- impr("A", FM, "M0")
  V$impr_C_M2 <- impr("C", "M2", "M1"); V$impr_C_M3 <- impr("C", "M3", "M1"); V$impr_C_M4 <- impr("C", "M4", "M1")
  V$endin_A_final <- pct0(100 * val("A", FM, "end_coverage_in95")); V$endin_C_final <- pct0(100 * val("C", FM, "end_coverage_in95"))
  for (e in c("A", "B", "C")) for (m in paste0("M", 0:4)) {
    V[[sprintf("endin_%s_%s", e, m)]] <- if (is.na(val(e, m, "end_coverage_in95"))) "not run" else pct0(100 * val(e, m, "end_coverage_in95"))
    V[[sprintf("ls_%s_%s", e, m)]] <- if (is.na(val(e, m, "mean_log_score"))) "not run" else f1(val(e, m, "mean_log_score"), 2)
  }
  for (m in paste0("M", 0:4)) V[[sprintf("ls_D_%s", m)]] <- if (is.na(val("D", m, "mean_log_score"))) "not run" else f1(val("D", m, "mean_log_score"), 2)
  if (file.exists(file.path(DIR_TAB, "validation_later_by_horizon.csv"))) {
    hz <- rd("validation_later_by_horizon.csv")
    for (i in seq_len(nrow(hz))) {
      tag <- c("1 interval ahead" = "C1", "2-3 ahead" = "C23", "4 or more ahead" = "C4")[[hz$hgroup[i]]]
      V[[sprintf("crps_%s_%s", tag, hz$model[i])]] <- f1(hz$mean_crps_pp[i], 2)
      V[[sprintf("cov_%s_%s", tag, hz$model[i])]] <- pct0(100 * hz$coverage95[i])
    }
    V$impr_C1_final <- pct0(100 * (1 - hz[hgroup == "1 interval ahead" & model == FM, mean_crps_pp] /
                                     hz[hgroup == "1 interval ahead" & model == "M1", mean_crps_pp]))
  }
  V$bias_D_final <- f1(val("D", FM, "bias_pp"), 2)
}
if (!is.null(rb)) for (i in seq_len(nrow(rb))) {
  m <- rb$model[i]
  V[[paste0("rob_med_", m)]] <- sprintf("%.1f%%", rb$median_abs_diff_pct[i])
  V[[paste0("rob_p95_", m)]] <- sprintf("%.1f%%", rb$p95_abs_diff_pct[i])
  V[[paste0("rob_max_", m)]] <- sprintf("%.0f%%", rb$max_abs_diff_pct[i])
  V[[paste0("rob_maxcounty_", m)]] <- sprintf("%s County, %s adults", rb$max_diff_county[i],
                                              format(rb$max_diff_county_adults[i], big.mark = ","))
}
fst <- fread(file.path(DIR_MOD, "fit_statistics.csv"))
V$waic_spread <- f1(max(fst$waic) - min(fst$waic), 0)
V$waic_level <- formatC(round(mean(fst$waic), -2), format = "d", big.mark = ",")
V$waic_worst <- fst[which.max(waic), model]
V$pwaic <- formatC(round(mean(fst$p_waic), -2), format = "d", big.mark = ",")
V$n_usable <- formatC(fread(file.path(DIR_DERIVED, "panel.csv"))[usable == TRUE, .N], format = "d", big.mark = ",")
for (i in seq_len(nrow(fst))) {
  V[[paste0("cpo_fail_", fst$model[i])]] <- fst$cpo_failures[i]
  V[[paste0("lcpo_", fst$model[i])]] <- f1(fst$mean_log_cpo[i], 3)
  V[[paste0("secs_", fst$model[i])]] <- f1(fst$seconds[i], 0)
}
# Paired differences: d_<score>_<experiment + horizon tag>_<first>_<second>
if (!is.null(PD)) {
  tagmap <- c("all" = "", "1 interval ahead" = "1", "2-3 ahead" = "23", "4 or more ahead" = "4")
  for (i in seq_len(nrow(PD))) {
    tg <- sprintf("%s%s_%s_%s", PD$experiment[i], tagmap[[PD$subset[i]]], PD$first[i], PD$second[i])
    V[[paste0("d_crps_", tg)]] <- ci(PD$diff_crps_pp[i], PD$diff_crps_lo[i], PD$diff_crps_hi[i], 3)
    V[[paste0("d_ls_", tg)]] <- ci(PD$diff_log_score[i], PD$diff_log_score_lo[i], PD$diff_log_score_hi[i], 3)
    if (!is.na(PD$diff_end_coverage_mae_pp[i])) {
      V[[paste0("d_end_", tg)]] <- ci(PD$diff_end_coverage_mae_pp[i], PD$diff_end_coverage_mae_lo[i], PD$diff_end_coverage_mae_hi[i], 2)
    }
  }
}
sm <- rd("smoothing_recorded_vs_modelled.csv")
V$sm_small <- f1(sm[1, median_abs_diff_pp], 2); V$sm_mid <- f1(sm[2, median_abs_diff_pp], 2); V$sm_large <- f1(sm[3, median_abs_diff_pp], 3)
V$sm_small_rel <- pct0(sm[1, median_abs_rel_diff_pct]); V$sm_mid_rel <- sprintf("%.1f%%", sm[2, median_abs_rel_diff_pct])
V$n_local <- nrow(lc); V$n_distinct <- lc[distinct == TRUE, .N]
V$n_distinct_low <- lc[distinct == TRUE & local_ratio < 1, .N]; V$n_distinct_high <- lc[distinct == TRUE & local_ratio > 1, .N]
V$moran <- f1(ss[item %like% "Moran", value], 2)
if (file.exists(file.path(DIR_TAB, "fig11_heldout_county_prediction.csv"))) {
  ho <- rd("fig11_heldout_county_prediction.csv")
  V$ho_n <- nrow(ho); V$ho_mae <- f1(mean(abs(ho$err)), 1); V$ho_median <- f1(median(abs(ho$err)), 1)
  V$ho_over5 <- ho[abs(err) > 5, .N]; V$ho_over10 <- ho[abs(err) > 10, .N]
  V$ho_worst <- ho[which.max(abs(err)), sprintf("%s (predicted %.0f%%, recorded %.0f%%)", county, pred_cov_end, obs_cov_end)]
  V$ho_in95 <- pct0(100 * ho[, mean(obs_cov_end >= lo & obs_cov_end <= hi)])
}
if (exists("s")) {
  rng <- function(x) sprintf("%.2f to %.2f", min(x), max(x))
  V$sens_age <- rng(s$hr_age); V$sens_inc <- rng(s$hr_income); V$sens_case <- rng(s$hr_cases); V$sens_n <- nrow(s) - 1
  V$sens_phi <- rng(s$phi_spatial)
  for (i in seq_len(nrow(s))) {
    id <- s$variant[i]
    V[[sprintf("s_%s_age", id)]] <- ci(s$hr_age[i], s$hr_age_lo[i], s$hr_age_hi[i])
    V[[sprintf("s_%s_inc", id)]] <- ci(s$hr_income[i], s$hr_income_lo[i], s$hr_income_hi[i])
    V[[sprintf("s_%s_case", id)]] <- ci(s$hr_cases[i], s$hr_cases_lo[i], s$hr_cases_hi[i])
    V[[sprintf("s_%s_n", id)]] <- s$counties[i]
  }
}
xa <- rd("cdc_vs_dshs_coverage_check.csv"); xc <- xa[.N]
V$cdc_n <- xc$counties; V$cdc_cor <- f1(xc$correlation, 2); V$cdc_rank <- f1(xc$rank_correlation, 2)
V$cdc_medabs <- f1(xc$median_abs_diff_points, 1)
V$cdc_over5 <- xc$counties_diff_over_5_points; V$cdc_over10 <- xc$counties_diff_over_10_points
V$cdc0_cor <- f1(xa$correlation[1], 2); V$cdc0_medabs <- f1(xa$median_abs_diff_points[1], 1); V$cdc0_over5 <- xa$counties_diff_over_5_points[1]
vals <- data.table(name = names(V), value = vapply(V, function(x) as.character(x)[1], character(1)))
fwrite(vals, file.path(DIR_TAB, "report_values.csv"))

# ---------------------------------------------------------------------------
# Fill the template
# ---------------------------------------------------------------------------
# the figures of the rerun check are quoted in the limitations; they are kept out of report_values.csv,
# which that check compares between runs
fill_template("docs/02_report_template.md", "docs/02_report.md", tables, c(V, rerun_values()))
