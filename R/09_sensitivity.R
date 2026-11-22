# 09_sensitivity.R -- how much do the conclusions depend on the choices made?
#
#   Rscript --vanilla R/09_sensitivity.R
#
# The selected uptake model is refitted under alternative data choices. For
# each variant the table reports the three predictor associations (hazard ratio
# per standard deviation, 95% credible interval) and the variance components.
# Output: outputs/tables/sensitivity.csv

source("R/_common.R")
source("R/_models.R")
options(width = 220, scipen = 999)
M <- FINAL_MODEL
W <- build_graph()
flags <- fread(file.path(DIR_DERIVED, "county_flags.csv"), colClasses = list(character = "fips"))

summarise_fit <- function(r, d, y, id, what) {
  fx <- fixed_table(r); hy <- hyper_table(r)
  g <- function(tm, col) exp(fx[fx$term == tm, ][[col]])
  h <- function(par, col = "median") { v <- hy[hy$parameter == par, ][[col]]; if (length(v)) v else NA_real_ }
  data.table(variant = id, description = what,
             counties = uniqueN(d$fips[!is.na(y)]), county_intervals = sum(!is.na(y)),
             hr_age = g("z_age", "median"), hr_age_lo = g("z_age", "q025"), hr_age_hi = g("z_age", "q975"),
             hr_income = g("z_income", "median"), hr_income_lo = g("z_income", "q025"), hr_income_hi = g("z_income", "q975"),
             hr_cases = g("z_cases", "median"), hr_cases_lo = g("z_cases", "q025"), hr_cases_hi = g("z_cases", "q975"),
             sd_county = h("SD of cid"), phi_spatial = h("Phi for cid"),
             sd_trajectory = h("SD of tid2"), sd_county_interval = h("SD of oid"),
             seconds = as.numeric(r$cpu.used[["Total"]]))
}
run <- function(id, what, d, y = d$y_model, ...) {
  msg("Variant %s: %s", id, what)
  r <- tryCatch(fit_model(d, M, W, y = y, compute_scores = FALSE, ...), error = function(e) e)
  if (inherits(r, "error")) { msg("  variant %s failed: %s", id, conditionMessage(r)); return(NULL) }
  s <- summarise_fit(r, d, y, id, what)
  print(s[, .(variant, counties, county_intervals, hr_age = round(hr_age, 3), hr_income = round(hr_income, 3),
              hr_cases = round(hr_cases, 3), sd_county = round(sd_county, 3), phi_spatial = round(phi_spatial, 2))])
  s
}
# Recompute which rows can enter the likelihood for a changed denominator
usable_y <- function(d, pop, county_rule = TRUE) {
  at_risk <- pop - d$cum_start
  cov_s <- 100 * d$cum_start / pop
  mx <- tapply(100 * d$cum_end / pop, d$fips, max)        # highest recorded coverage per county
  bad_county <- if (county_rule) d$fips %in% names(mx)[mx > COUNTY_MAX_COVERAGE] else rep(FALSE, nrow(d))
  ok <- !bad_county & cov_s < COVERAGE_CEILING & d$y <= at_risk
  list(at_risk = at_risk, y = ifelse(ok, pmax(d$y, 0L), NA_integer_))
}

d <- load_panel("panel.csv")
res <- list()
res[["S0"]] <- run("S0", "Main analysis", d)

d1 <- load_panel("panel_early.csv")
res[["S1"]] <- run("S1", "Adds the interval 23 April - 24 May 2021 (before county re-assignments had settled)", d1)

d2 <- load_panel("panel_fine.csv")
res[["S2"]] <- run("S2", "Keeps every near-monthly edition after May 2022 (18 intervals instead of 12)", d2)

d3 <- copy(d); u <- usable_y(d3, d3$dshs_pop16); d3[, at_risk := u$at_risk]
res[["S3"]] <- run("S3", "Denominator: the 2019 Census estimate of residents aged 16+ printed in the DSHS workbook", d3, u$y)

d4 <- copy(d); u <- usable_y(d4, d4$pop16, county_rule = FALSE)
res[["S4"]] <- run("S4", "Keeps the 16 flagged counties until their recorded coverage reaches 95%", d4, u$y)

d5 <- copy(d); d5[, z_cases := z_cases_confirmed]
res[["S5"]] <- run("S5", "Case rate from confirmed cases only (probable cases left out)", d5)

d6 <- copy(d); d6[, z_age := z_age_acs]
res[["S6"]] <- run("S6", "Age composition from the ACS 2019-2023 instead of the population estimates", d6)

res[["S7"]] <- run("S7", "Drops the county-intervals where a fall in the recorded count was set to zero", d,
                   ifelse(d$y_floored, NA_integer_, d$y_model))

d8 <- copy(d); d8[, at_risk := pop16]
res[["S8"]] <- run("S8", "Rate per adult resident instead of per adult not yet vaccinated", d8)

ed <- fread(file.path(DIR_DERIVED, "tx_adjacency_edges.csv"), colClasses = "character")
near <- unique(ed[fips %in% flags[excl_county == TRUE, fips], nb_fips])
res[["S9"]] <- run("S9", sprintf("Also leaves out the %d kept counties that border a flagged county",
                                 length(setdiff(near, flags[excl_county == TRUE, fips]))), d,
                   ifelse(d$fips %in% near, NA_integer_, d$y_model))

res[["S10"]] <- run("S10", "Ends on 30 May 2022 (drops the two half-year intervals)", d, ifelse(d$k > 10, NA_integer_, d$y_model))

res[["S11"]] <- run("S11", "Leaves out counties with fewer than 1,000 adults", d, ifelse(d$pop16 < 1000, NA_integer_, d$y_model))

# The approximation itself: R-INLA's older "classic" mode with the simplified
# Laplace strategy, instead of the default compact mode.
res[["S12"]] <- run("S12", "Same data, R-INLA classic mode with simplified Laplace approximation", d,
                    inla_mode = "classic", control_inla = list(strategy = "simplified.laplace"))

# ---------------------------------------------------------------------------
# Do the predictor associations change over the study? Same model, with each
# predictor's coefficient allowed to differ between three periods.
# ---------------------------------------------------------------------------
periods <- list(P1 = 1:4, P2 = 5:9, P3 = 10:12)
dp <- copy(d)
pv <- character()
for (p in names(periods)) for (v in c("z_age", "z_income", "z_cases")) {
  nm <- paste0(v, "_", p)
  set(dp, j = nm, value = ifelse(dp$k %in% periods[[p]], dp[[v]], 0))
  pv <- c(pv, nm)
}
msg("Period-specific associations")
rp <- fit_model(dp, M, W, covars = pv, compute_scores = FALSE)
iv <- unique(d[, .(k, data_from, data_to)])
pt <- fixed_table(rp)[term %in% pv]
pt[, `:=`(period = sub(".*_", "", term), predictor = sub("_P[0-9]$", "", term))]
pt[, period_label := sapply(period, function(p) sprintf("%s to %s", format(min(iv[k %in% periods[[p]], data_from]), "%d %b %Y"),
                                                       format(max(iv[k %in% periods[[p]], data_to]), "%d %b %Y")))]
pt <- pt[, .(period, period_label, predictor, hazard_ratio = exp(median), lo = exp(q025), hi = exp(q975))]
fwrite(pt, file.path(DIR_TAB, "period_specific_associations.csv"))
print(pt)

out <- rbindlist(res)
fwrite(out, file.path(DIR_TAB, "sensitivity.csv"))
print(out[, .(variant, counties, county_intervals,
              age = sprintf("%.2f (%.2f-%.2f)", hr_age, hr_age_lo, hr_age_hi),
              income = sprintf("%.2f (%.2f-%.2f)", hr_income, hr_income_lo, hr_income_hi),
              cases = sprintf("%.2f (%.2f-%.2f)", hr_cases, hr_cases_lo, hr_cases_hi),
              sd_county = round(sd_county, 2), phi = round(phi_spatial, 2), sd_traj = round(sd_trajectory, 2),
              sd_ci = round(sd_county_interval, 2))])
msg("Done.")
