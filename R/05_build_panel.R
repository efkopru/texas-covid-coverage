# 05_build_panel.R -- assemble the county-by-interval analysis dataset.
#
#   Rscript --vanilla R/05_build_panel.R
#
# Outcome  : residents aged 16+ with at least one recorded COVID-19 vaccine dose,
#            from the "By County, Age" sheet of original DSHS workbooks.
# Time grid: DSHS workbook editions listed in GRIDS (see _common.R). An edition
#            dated D holds records through 11:59 pm on D - 1.
# Outputs  : data/derived/coverage_editions.csv     recorded counts at every usable edition
#            data/derived/panel.csv                 main grid, one row per county and interval
#            data/derived/panel_early.csv, panel_fine.csv   sensitivity grids
#            data/derived/baseline.csv              one row per county at the baseline
#            data/derived/county_flags.csv          counties left out of the models, and why
#            outputs/tables/panel_exclusions.csv    rows not usable in the binomial model

source("R/_common.R")
suppressMessages(library(data.table))
options(width = 200, scipen = 999)

lk   <- fread(file.path(DIR_DERIVED, "county_lookup.csv"), colClasses = list(character = "fips"))
age  <- fread(file.path(DIR_DERIVED, "dshs_county_age.csv"), colClasses = list(character = "fips"))
dshs <- fread(file.path(DIR_DERIVED, "dshs_county_total.csv"), colClasses = list(character = "fips"))
pop  <- fread(file.path(DIR_DERIVED, "pop_county_year.csv"), colClasses = list(character = "fips"))
acs  <- fread(file.path(DIR_DERIVED, "acs_county.csv"), colClasses = list(character = "fips"))
cases <- fread(file.path(DIR_DERIVED, "cases_county_daily.csv"), colClasses = list(character = "fips"))
age[, as_of := as.Date(as_of)]; dshs[, as_of := as.Date(as_of)]; cases[, date := as.Date(date)]

# ---------------------------------------------------------------------------
# 1. Recorded counts by age at every workbook edition that has a usable
#    county-by-age sheet (the 2021-05-07 edition's sheet is corrupted: race
#    rows were pasted into it and its sums do not match the county totals).
# ---------------------------------------------------------------------------
wide <- dcast(age, as_of + fips ~ age_group, value.var = "one_dose", fun.aggregate = sum, fill = 0)
for (g in c("0-4", "5-11", "12-15", "16-49", "50-64", "65-79", "80+", "Unknown")) if (!g %in% names(wide)) wide[[g]] <- 0
wide[, `:=`(n_all = `0-4` + `5-11` + `12-15` + `16-49` + `50-64` + `65-79` + `80+` + Unknown,
            # People of unknown age are kept with adults: until 13 May 2021 nobody
            # under 16 was eligible, and the group never exceeds 0.07% of the total.
            n16 = `16-49` + `50-64` + `65-79` + `80+` + Unknown,
            n12 = `12-15` + `16-49` + `50-64` + `65-79` + `80+` + Unknown,
            n65 = `65-79` + `80+`)]
tot <- dshs[source == "wayback", .(as_of, fips, one_dose_all = one_dose, dshs_pop16 = pop16, dshs_pop65 = pop65)]
ed <- merge(wide[, .(as_of, fips, n_all, n16, n12, n65)], tot, by = c("as_of", "fips"))
bad <- ed[, .(mismatch = sum(n_all != one_dose_all)), by = as_of][mismatch > 0]
msg("Editions with an unusable county-by-age sheet: %s", paste(bad$as_of, collapse = ", "))
ed <- ed[!as_of %in% bad$as_of]
ed <- merge(ed, pop[year == 2021, .(fips, pop16_2021 = pop16, pop65_2021 = pop65, pop_total_2021 = pop_total)], by = "fips")
ed <- merge(lk, ed, by = "fips")
ed[, `:=`(cov16 = 100 * n16 / pop16_2021, cov16_dshs_denominator = 100 * n16 / dshs_pop16)]
setorder(ed, as_of, fips)
fwrite(ed, file.path(DIR_DERIVED, "coverage_editions.csv"))
msg("Usable editions with county-by-age counts: %d (%s to %s)", ed[, uniqueN(as_of)], min(ed$as_of), max(ed$as_of))

# ---------------------------------------------------------------------------
# 2. Counties whose records cannot be reconciled with their resident population
# ---------------------------------------------------------------------------
flags <- ed[as_of >= min(GRIDS$main), .(pop16 = pop16_2021[1], max_cov16 = max(cov16),
                                        first_over = as_of[which(cov16 > COUNTY_MAX_COVERAGE)[1]],
                                        cov16_baseline = cov16[as_of == min(GRIDS$main)],
                                        cov16_last = cov16[as_of == max(as_of)]), by = .(fips, county)]
flags[, excl_county := max_cov16 > COUNTY_MAX_COVERAGE]
setorder(flags, -max_cov16)
fwrite(flags, file.path(DIR_DERIVED, "county_flags.csv"))
msg("Counties whose recorded 16+ count exceeds the population estimate at some edition: %d (%.1f%% of Texans aged 16+)",
    flags[, sum(excl_county)], 100 * flags[excl_county == TRUE, sum(pop16)] / flags[, sum(pop16)])
print(flags[excl_county == TRUE, .(county, pop16, cov16_baseline = round(cov16_baseline, 1), cov16_last = round(cov16_last, 1), first_over)])

# ---------------------------------------------------------------------------
# 3. County characteristics (fixed over the study)
#    Age composition: share of residents aged 16+ who are 65 or older, from the
#    Census population estimates for 1 July 2021 (complete counts; the ACS-based
#    share is sample-based and unstable in very small counties, and is kept
#    only for a sensitivity check).
#    Income: ACS 2019-2023 median household income (2023 dollars), log scale.
# ---------------------------------------------------------------------------
cv <- merge(pop[year == 2021, .(fips, pop16 = pop16, pop_total, pct65_of_16plus = 100 * pop65 / pop16)],
            acs[, .(fips, med_hh_income, med_hh_income_moe, income_imputed, median_age,
                    acs_pct65_of_adults = pct_65plus_of_adults)], by = "fips")
cv <- merge(cv, flags[, .(fips, excl_county, max_cov16)], by = "fips")
cv <- merge(cv, ed[as_of == max(as_of), .(fips, dshs_pop16)], by = "fips")
scal <- list(age = c(mean(cv$pct65_of_16plus), sd(cv$pct65_of_16plus)),
             inc = c(mean(log(cv$med_hh_income)), sd(log(cv$med_hh_income))))
cv[, `:=`(z_age = (pct65_of_16plus - scal$age[1]) / scal$age[2],
          z_income = (log(med_hh_income) - scal$inc[1]) / scal$inc[2],
          z_age_acs = as.numeric(scale(acs_pct65_of_adults)))]

cases[, new_cases := new_confirmed + new_probable]
sum_cases <- function(end_date, days, var) cases[date > end_date - days & date <= end_date,
                                                 .(n = sum(get(var), na.rm = TRUE)), by = fips]

# ---------------------------------------------------------------------------
# 4. Panel builder
# ---------------------------------------------------------------------------
build_panel <- function(grid_asof, case_scale = NULL) {
  stopifnot(all(grid_asof %in% ed$as_of))
  iv <- data.table(k = seq_len(length(grid_asof) - 1), start_asof = grid_asof[-length(grid_asof)], end_asof = grid_asof[-1])
  iv[, `:=`(days = as.integer(end_asof - start_asof), data_from = start_asof, data_to = end_asof - 1)]
  iv[, mid := data_from + days / 2]
  iv[, label := sprintf("%s - %s", format(data_from, "%d %b %Y"), format(data_to, "%d %b %Y"))]
  # reported cases in the 30 days before the interval starts
  cr <- rbindlist(lapply(seq_len(nrow(iv)), function(i) {
    e <- iv$data_from[i] - 1
    merge(sum_cases(e, 30, "new_cases")[, .(fips, cases_prev30 = n)],
          sum_cases(e, 30, "new_confirmed")[, .(fips, confirmed_prev30 = n)], by = "fips")[, k := iv$k[i]]
  }))
  p <- merge(CJ(fips = lk$fips, k = iv$k), iv, by = "k")
  p <- merge(p, ed[, .(fips, start_asof = as_of, cum_start = n16)], by = c("fips", "start_asof"))
  p <- merge(p, ed[, .(fips, end_asof = as_of, cum_end = n16)], by = c("fips", "end_asof"))
  p <- merge(p, cv, by = "fips")
  p <- merge(p, cr, by = c("fips", "k"))
  p <- merge(lk, p, by = "fips")
  p[, `:=`(y = cum_end - cum_start, at_risk = pop16 - cum_start,
           cov_start = 100 * cum_start / pop16, cov_end = 100 * cum_end / pop16,
           case_rate_prev30 = 1e5 * cases_prev30 / pop_total,
           confirmed_rate_prev30 = 1e5 * confirmed_prev30 / pop_total)]
  p[, log_case_rate := log(case_rate_prev30 + 10)]   # +10 per 100,000 keeps zero-case rows finite
  if (is.null(case_scale)) case_scale <- c(mean(p$log_case_rate), sd(p$log_case_rate))
  p[, z_cases := (log_case_rate - case_scale[1]) / case_scale[2]]
  p[, z_cases_confirmed := as.numeric(scale(log(confirmed_rate_prev30 + 10)))]
  # Rows that cannot enter a binomial likelihood, and why
  p[, exclude := fifelse(excl_county, "county: recorded count exceeds population estimate",
                 fifelse(cov_start >= COVERAGE_CEILING, "recorded coverage at or above 95% at interval start",
                 fifelse(y > at_risk, "new first doses exceed remaining population", "")))]
  p[, usable := exclude == ""]
  # A net fall between editions (record corrections outweighing new first doses)
  # is kept as zero new first doses rather than dropped, and flagged.
  p[, y_floored := usable & y < 0]
  p[, y_model := fifelse(usable, pmax(y, 0L), NA_integer_)]
  p[, uptake := fifelse(usable, y_model / at_risk, NA_real_)]
  p[, uptake30 := 1 - (1 - uptake)^(30 / days)]      # per-30-day equivalent
  setorder(p, fips, k)
  attr(p, "case_scale") <- case_scale
  p[]
}

p <- build_panel(GRIDS$main)
cs_scale <- attr(p, "case_scale")
fwrite(p, file.path(DIR_DERIVED, "panel.csv"))
fwrite(build_panel(GRIDS$early, cs_scale), file.path(DIR_DERIVED, "panel_early.csv"))
fwrite(build_panel(GRIDS$fine, cs_scale), file.path(DIR_DERIVED, "panel_fine.csv"))

ex <- p[usable == FALSE, .(fips, county, k, label, cum_start, cum_end, y, pop16, at_risk,
                           cov_start = round(cov_start, 1), exclude)]
fwrite(ex, file.path(DIR_TAB, "panel_exclusions.csv"))
msg("Main panel: %d counties x %d intervals = %d rows; usable in the binomial model: %d (%.1f%%); counties with at least one usable row: %d",
    p[, uniqueN(fips)], p[, max(k)], nrow(p), p[, sum(usable)], 100 * p[, mean(usable)], p[usable == TRUE, uniqueN(fips)])
print(p[usable == FALSE, .(rows = .N, counties = uniqueN(fips)), by = exclude])
msg("Rows where the recorded count fell and new first doses were set to zero: %d (in %d counties; total fall %d persons)",
    p[, sum(y_floored)], p[y_floored == TRUE, uniqueN(fips)], p[y_floored == TRUE, sum(y)])
print(p[y_floored == TRUE, .(rows = .N, sum_y = sum(y), min_y = min(y)), by = .(k, label)])

# ---------------------------------------------------------------------------
# 5. Baseline table for the initial-rollout coverage model
# ---------------------------------------------------------------------------
b0 <- merge(lk, ed[as_of == GRIDS$main[1], .(fips, n16, n65, pop65_2021)], by = "fips")
b0 <- merge(b0, cv, by = "fips")
pre <- cases[date <= as.Date("2020-12-13"), .(cases_pre = sum(new_cases, na.rm = TRUE)), by = fips]
b0 <- merge(b0, pre, by = "fips")
b0[, `:=`(cov0 = 100 * n16 / pop16, case_rate_pre = 1e5 * cases_pre / pop_total)]
pre_scale <- c(mean(log(b0$case_rate_pre + 10)), sd(log(b0$case_rate_pre + 10)))
b0[, z_cases_pre := (log(case_rate_pre + 10) - pre_scale[1]) / pre_scale[2]]
b0[, usable := !excl_county & n16 <= pop16]
b0[, y_model := fifelse(usable, n16, NA_integer_)]
fwrite(b0, file.path(DIR_DERIVED, "baseline.csv"))

sc <- data.table(variable = c("pct65_of_16plus", "log_med_hh_income", "log_case_rate_prev30_plus10", "log_case_rate_pre_plus10"),
                 mean = c(scal$age[1], scal$inc[1], cs_scale[1], pre_scale[1]),
                 sd = c(scal$age[2], scal$inc[2], cs_scale[2], pre_scale[2]))
fwrite(sc, file.path(DIR_DERIVED, "covariate_scaling.csv"))
print(sc)

# Statewide summary by interval: all counties, and the counties kept in the model
summ <- function(d) d[, .(days = days[1], new_first_doses = sum(y), at_risk = sum(at_risk),
                          cov_start = round(100 * sum(cum_start) / sum(pop16), 2),
                          cov_end = round(100 * sum(cum_end) / sum(pop16), 2),
                          median_case_rate_prev30 = round(median(case_rate_prev30))), by = .(k, label)][
                            , uptake30_pct := round(100 * (1 - (1 - new_first_doses / at_risk)^(30 / days)), 2)][]
sw <- merge(summ(p), summ(p[excl_county == FALSE])[, .(k, cov_start_kept = cov_start, cov_end_kept = cov_end,
                                                        uptake30_pct_kept = uptake30_pct)], by = "k")
print(sw)
fwrite(sw, file.path(DIR_TAB, "statewide_by_interval.csv"))
cat("\nUptake per 30 days across usable county-intervals:\n")
print(p[usable == TRUE, .(n = .N, min = round(100 * min(uptake30), 2), p05 = round(100 * quantile(uptake30, .05), 2),
                           median = round(100 * median(uptake30), 2), p95 = round(100 * quantile(uptake30, .95), 2),
                           max = round(100 * max(uptake30), 2)), by = k])
