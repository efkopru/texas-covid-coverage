# 03_verify_vaccination.R -- checks that decide which vaccination records can be
# used, for which dates, age groups and dose definition.
#
#   Rscript --vanilla R/03_verify_vaccination.R
#
# Each check writes a table to outputs/tables/verify_*.csv and prints a short
# summary. docs/01_source_inventory.md quotes these tables.

source("R/_common.R")
suppressMessages(library(data.table))
options(width = 200, scipen = 999)

lk   <- fread(file.path(DIR_DERIVED, "county_lookup.csv"), colClasses = list(character = "fips"))
idx  <- fread(file.path(DIR_DERIVED, "dshs_workbook_index.csv"))
dshs <- fread(file.path(DIR_DERIVED, "dshs_county_total.csv"), colClasses = list(character = "fips"))
age  <- fread(file.path(DIR_DERIVED, "dshs_county_age.csv"), colClasses = list(character = "fips"))
vd   <- fread(file.path(DIR_DERIVED, "dshs_state_by_vaxdate.csv"))
cdc  <- fread(file.path(DIR_DERIVED, "cdc_county.csv"), colClasses = list(character = "fips"))
for (x in list(idx, dshs, age, vd)) x[, as_of := as.Date(as_of)]
cdc[, date := as.Date(date)]; vd[, vax_date := as.Date(vax_date)]
cdcc <- cdc[fips != "UNK"]
gh <- dshs[source == "github"]; wb <- dshs[source == "wayback"]
out <- function(x, name) fwrite(x, file.path(DIR_TAB, paste0("verify_", name, ".csv")))
hr <- function(t) cat("\n", strrep("=", 100), "\n", t, "\n", strrep("=", 100), "\n", sep = "")

# ---------------------------------------------------------------------------
hr("V1  DSHS workbook editions recovered from the Wayback Machine")
print(idx[, .(file, as_of_cell, workbook_modified_central_date, as_of, has_county_age,
              state_row_one_dose, county_sum_one_dose, other_row_one_dose, state_pop16, state_pop12)])
out(idx, "01_dshs_workbook_index")

# ---------------------------------------------------------------------------
hr("V2  Do the GitHub CSV copies reproduce the original DSHS workbooks?")
v2 <- merge(wb[, .(as_of, fips, wb_one = one_dose, wb_fully = fully, wb_doses = doses_admin)],
            gh[, .(as_of, fips, gh_one = one_dose, gh_fully = fully, gh_doses = doses_admin)],
            by = c("as_of", "fips"))
v2s <- v2[, .(counties = .N,
              one_dose_identical = sum(wb_one == gh_one),
              fully_identical = sum(wb_fully == gh_fully),
              doses_identical = sum(wb_doses == gh_doses),
              max_abs_diff_one_dose = max(abs(wb_one - gh_one))), by = as_of]
print(v2s)
cat(sprintf("Overlapping as-of dates: %d; county-date cells compared: %d; identical one-dose cells: %d (%.2f%%)\n",
            nrow(v2s), nrow(v2), sum(v2$wb_one == v2$gh_one), 100 * mean(v2$wb_one == v2$gh_one)))
out(v2s, "02_github_vs_wayback")

# ---------------------------------------------------------------------------
hr("V3  Age content of the DSHS counts")
a <- age[, .(one_dose = sum(one_dose, na.rm = TRUE)), by = .(as_of, age_group)]
aw <- dcast(a, as_of ~ age_group, value.var = "one_dose", fill = 0)
for (g in setdiff(c("0-4", "5-11", "12-15", "16-49", "50-64", "65-79", "80+", "Unknown"), names(aw))) aw[[g]] <- 0
aw[, age_sum := `0-4` + `5-11` + `12-15` + `16-49` + `50-64` + `65-79` + `80+` + Unknown]
aw <- merge(aw, wb[, .(county_total = sum(one_dose)), by = as_of], by = "as_of")
aw[, `:=`(under12 = `0-4` + `5-11`, age16plus = `16-49` + `50-64` + `65-79` + `80+`,
          age12plus = `12-15` + `16-49` + `50-64` + `65-79` + `80+`)]
aw[, `:=`(pct_under12 = round(100 * under12 / age_sum, 3), pct_12_15 = round(100 * `12-15` / age_sum, 2),
          pct_unknown_age = round(100 * Unknown / age_sum, 3),
          age_sum_minus_total = age_sum - county_total)]
print(aw[, .(as_of, county_total, age_sum, age_sum_minus_total, under12, `12-15`, age16plus, Unknown,
             pct_under12, pct_12_15, pct_unknown_age)])
out(aw, "03_dshs_age_content")
# county-level agreement between the age sheet and the county sheet
ca <- merge(age[, .(age_sum = sum(one_dose, na.rm = TRUE)), by = .(as_of, fips)],
            wb[, .(as_of, fips, one_dose)], by = c("as_of", "fips"))
cat("County rows where age-sheet sum != county-sheet total, by as-of date:\n")
print(ca[, .(counties = .N, differ = sum(age_sum != one_dose),
             max_abs_diff = max(abs(age_sum - one_dose)),
             max_rel_diff_pct = round(100 * max(abs(age_sum - one_dose) / pmax(one_dose, 1)), 2)), by = as_of])

# ---------------------------------------------------------------------------
hr("V4  DSHS workbooks versus the CDC county file on the same dates")
# Which CDC report date lines up with a DSHS 'as of' date? Compare increments
# between pairs of DSHS editions with CDC increments at lags -1, 0, +1 day.
ov <- sort(unique(wb$as_of[wb$as_of >= CDC_TX_FIRST_DATE]))
st_d <- wb[as_of %in% ov, .(dshs = sum(one_dose)), by = as_of]
st_c <- cdcc[, .(cdc = sum(administered_dose1_recip)), by = date]
lagtab <- rbindlist(lapply(-2:2, function(L) {
  m <- merge(st_d, st_c[, .(as_of = date - L, cdc)], by = "as_of")
  setorder(m, as_of)
  m[, .(lag_days = L, n_pairs = .N - 1,
        cor_increments = cor(diff(dshs), diff(cdc)),
        mean_abs_diff_increments = mean(abs(diff(dshs) - diff(cdc))),
        median_level_gap_pct = median(100 * (cdc - dshs) / dshs))]
}))
cat("CDC report date = DSHS as-of date + lag; agreement of statewide increments between editions:\n")
print(lagtab)
out(lagtab, "04a_dshs_cdc_date_alignment")

d12 <- age[age_group %in% c("12-15", "16-49", "50-64", "65-79", "80+"), .(dshs_12plus = sum(one_dose)), by = .(as_of, fips)]
d16 <- age[age_group %in% c("16-49", "50-64", "65-79", "80+"), .(dshs_16plus = sum(one_dose)), by = .(as_of, fips)]
d65 <- age[age_group %in% c("65-79", "80+"), .(dshs_65plus = sum(one_dose)), by = .(as_of, fips)]
cmp <- Reduce(function(x, y) merge(x, y, by = c("as_of", "fips"), all.x = TRUE),
              list(wb[as_of %in% ov, .(as_of, fips, county, dshs_all = one_dose)], d12, d16, d65))
cmp <- merge(cmp, cdcc[, .(as_of = date, fips, cdc_all = administered_dose1_recip,
                           cdc_12plus = administered_dose1_recip_12plus,
                           cdc_18plus = administered_dose1_recip_18plus,
                           cdc_65plus = administered_dose1_recip_65plus,
                           pop12_2019 = census2019_12pluspop)], by = c("as_of", "fips"))
cmp[, `:=`(rel_all = 100 * (cdc_all - dshs_all) / dshs_all,
           rel_12 = 100 * (cdc_12plus - dshs_12plus) / dshs_12plus,
           rel_65 = 100 * (cdc_65plus - dshs_65plus) / dshs_65plus,
           pp_12 = 100 * (cdc_12plus - dshs_12plus) / pop12_2019)]
v4 <- cmp[, .(counties = .N,
              state_dshs_all = sum(dshs_all), state_cdc_all = sum(cdc_all),
              state_gap_all_pct = round(100 * (sum(cdc_all) - sum(dshs_all)) / sum(dshs_all), 2),
              state_gap_12plus_pct = round(100 * (sum(cdc_12plus) - sum(dshs_12plus)) / sum(dshs_12plus), 2),
              state_gap_65plus_pct = round(100 * (sum(cdc_65plus) - sum(dshs_65plus)) / sum(dshs_65plus), 2),
              cdc18_over_dshs16_pct = round(100 * sum(cdc_18plus) / sum(dshs_16plus), 2),
              median_county_gap_12plus_pct = round(median(rel_12, na.rm = TRUE), 2),
              p05 = round(quantile(rel_12, 0.05, na.rm = TRUE), 2),
              p95 = round(quantile(rel_12, 0.95, na.rm = TRUE), 2),
              max_abs_gap_pp_of_pop = round(max(abs(pp_12), na.rm = TRUE), 2),
              counties_gap_over_2pp = sum(abs(pp_12) > 2, na.rm = TRUE)), by = as_of]
print(v4)
out(v4, "04b_dshs_vs_cdc_by_date")
first_ov <- min(cmp$as_of)
cat(sprintf("\nLargest county gaps (CDC 12+ minus DSHS 12+) on %s, in points of the 12+ population:\n", first_ov))
print(cmp[as_of == first_ov][order(-abs(pp_12))][1:15, .(county, dshs_12plus, cdc_12plus, rel_12 = round(rel_12, 2), pp_12 = round(pp_12, 2))])
out(cmp, "04c_dshs_vs_cdc_county")

# ---------------------------------------------------------------------------
hr("V5  Day-to-day behaviour of the cumulative counts (revisions and jumps)")
setorder(gh, fips, as_of)
gh[, `:=`(d = one_dose - shift(one_dose), gap = as.integer(as_of - shift(as_of))), by = fips]
gneg <- gh[!is.na(d) & d < 0]
cat(sprintf("DSHS daily series (GitHub): %d county-day changes; %d negative (%.3f%%); counties ever negative: %d; largest drop: %d\n",
            gh[!is.na(d), .N], nrow(gneg), 100 * nrow(gneg) / gh[!is.na(d), .N], gneg[, uniqueN(fips)], gneg[, min(d)]))
gs <- gh[, .(state = sum(one_dose)), by = as_of][order(as_of)]
gs[, `:=`(d = state - shift(state), gap = as.integer(as_of - shift(as_of)))]
cat("Statewide DSHS daily change: negative days =", gs[!is.na(d) & d < 0, .N],
    "; gaps of more than one day between snapshots:", gs[!is.na(gap) & gap > 1, .N], "\n")
print(gs[!is.na(gap) & gap > 1])
out(gs, "05a_dshs_daily_state")
out(gneg[, .(as_of, fips, county, change = d, prev_gap_days = gap)], "05b_dshs_negative_changes")

setorder(cdcc, fips, date)
cd <- cdcc[date >= CDC_TX_FIRST_DATE]
for (v in c("administered_dose1_recip", "administered_dose1_recip_12plus", "administered_dose1_recip_18plus")) {
  cd[, d := get(v) - shift(get(v)), by = fips]
  cat(sprintf("CDC %-34s: %d county-report changes; negative: %d (%.2f%%); zero-valued county rows: %d\n",
              v, cd[!is.na(d), .N], cd[!is.na(d) & d < 0, .N],
              100 * cd[!is.na(d) & d < 0, .N] / cd[!is.na(d), .N], cd[get(v) == 0 | is.na(get(v)), .N]))
}
cs <- cdcc[date >= CDC_TX_FIRST_DATE,
           .(all = sum(administered_dose1_recip), a12 = sum(administered_dose1_recip_12plus, na.rm = TRUE),
             a18 = sum(administered_dose1_recip_18plus, na.rm = TRUE),
             n_zero18 = sum(administered_dose1_recip_18plus == 0 | is.na(administered_dose1_recip_18plus)),
             n_zero12 = sum(administered_dose1_recip_12plus == 0 | is.na(administered_dose1_recip_12plus)),
             n_zero_all = sum(administered_dose1_recip == 0 | is.na(administered_dose1_recip))), by = date][order(date)]
cs[, `:=`(d_all = all - shift(all), d12 = a12 - shift(a12), d18 = a18 - shift(a18))]
cat("\nCDC report dates with a statewide (county-sum) decrease, or many zero county rows:\n")
print(cs[(!is.na(d18) & (d18 < 0 | d12 < 0 | d_all < 0)) | n_zero18 > 3 | n_zero12 > 3])
out(cs, "05c_cdc_daily_state")

# ---------------------------------------------------------------------------
hr("V6  Reporting backlog: first doses by vaccination date as known at successive editions")
# For each calendar month of vaccination, how many first doses did each later
# workbook edition attribute to it?
vd[, vmonth := format(vax_date, "%Y-%m")]
bm <- vd[, .(one_dose = sum(one_dose, na.rm = TRUE)), by = .(as_of, vmonth)]
eds <- sort(unique(vd$as_of))
pick <- eds[c(1, which(eds >= as.Date("2021-07-01"))[1], which(eds >= as.Date("2021-10-20"))[1],
              which(eds >= as.Date("2022-02-20"))[1], which(eds >= as.Date("2022-11-01"))[1], length(eds))]
pick <- unique(pick[!is.na(pick)])
bw <- dcast(bm[as_of %in% pick & vmonth <= "2022-12"], vmonth ~ as_of, value.var = "one_dose")
print(bw)
out(bw, "06_first_dose_by_vaxdate_across_editions")
# Completeness of a month's first doses one edition later versus the final edition
last_ed <- max(eds)
fin <- bm[as_of == last_ed, .(vmonth, final = one_dose)]
comp <- merge(bm, fin, by = "vmonth")
comp[, month_end := month_end(as.Date(paste0(vmonth, "-01")))]
comp[, days_after_month_end := as.integer(as_of - month_end)]
c1 <- comp[days_after_month_end >= 0 & days_after_month_end <= 45, .SD[which.min(days_after_month_end)], by = vmonth]
c1[, pct_of_final := round(100 * one_dose / final, 2)]
cat("\nShare of a month's eventual first-dose count already recorded at the first edition after month end:\n")
print(c1[, .(vmonth, edition = as_of, days_after_month_end, recorded = one_dose, final, pct_of_final)])
out(c1, "06b_backlog_completeness")

# ---------------------------------------------------------------------------
hr("V7  Precision of the published percentages (CDC) and counts above population")
pc <- cdcc[date >= CDC_TX_FIRST_DATE]
for (v in c("administered_dose1_pop_pct", "administered_dose1_recip_12pluspop_pct",
            "administered_dose1_recip_18pluspop_pct", "administered_dose1_recip_65pluspop_pct")) {
  x <- pc[[v]]
  cat(sprintf("%-40s max = %.1f; county-report rows at the maximum: %d (%.1f%%); decimals: %d\n", v, max(x, na.rm = TRUE),
              sum(x == max(x, na.rm = TRUE), na.rm = TRUE), 100 * mean(x == max(x, na.rm = TRUE), na.rm = TRUE),
              max(nchar(sub("^[^.]*[.]?", "", format(x[!is.na(x)][1:5000], trim = TRUE, drop0trailing = TRUE))))))
}
capd <- pc[, .(max_pct_18plus = max(administered_dose1_recip_18pluspop_pct, na.rm = TRUE)), by = date][order(date)]
capd[, regime := rleid(max_pct_18plus)]
cat("\nLargest published 18+ percentage by period (the cap CDC applied):\n")
print(capd[, .(from = min(date), to = max(date), report_dates = .N), by = .(regime, max_pct_18plus)][report_dates >= 5])
dd <- sort(unique(pc$date)); gaps <- as.integer(diff(dd))
cat(sprintf("Reporting cadence: daily from %s to %s; then every 7 days from %s to %s (%d report dates in total)\n",
            min(dd), dd[max(which(gaps == 1)) + 1], dd[max(which(gaps == 1)) + 2], max(dd), length(dd)))
cat("Loving County (48301) in the CDC file, selected dates (people with at least one dose, all ages):\n")
print(pc[fips == "48301" & date %in% as.Date(c("2021-10-22", "2021-12-31", "2022-06-01", "2023-05-10")),
         .(date, administered_dose1_recip, administered_dose1_recip_18plus, census2019)])
lastd <- max(pc$date)
ex <- pc[date == lastd, .(fips, recip_county, d18 = administered_dose1_recip_18plus, pop18_2019 = census2019_18pluspop,
                          pct_published = administered_dose1_recip_18pluspop_pct)]
ex[, pct_from_counts := round(100 * d18 / pop18_2019, 1)]
cat(sprintf("\nOn %s: counties whose 18+ count exceeds the 2019 18+ population: %d; published at the 95%% cap: %d\n",
            lastd, ex[d18 > pop18_2019, .N], ex[pct_published >= 95, .N]))
print(ex[order(-pct_from_counts)][1:12])
out(ex, "07_cdc_cap_last_date")

# ---------------------------------------------------------------------------
hr("V8  Which edition supplies each month-end cumulative count?")
# A count 'through the last day of month M' is the edition dated the first day
# of month M+1 (DSHS as-of date; CDC report date).
ms <- month_seq(as.Date("2020-12-01"), as.Date("2023-04-01"))
need <- data.table(month = format(ms, "%Y-%m"), target = month_end(ms) + 1)
ghd <- sort(unique(gh$as_of)); wbd <- sort(unique(wb$as_of)); cdd <- sort(unique(cdcc[date >= CDC_TX_FIRST_DATE, date]))
near <- function(dates, t) { i <- which.min(abs(as.integer(dates - t))); list(dates[i], as.integer(dates[i] - t)) }
brk <- function(dates, t) c(before = suppressWarnings(max(dates[dates <= t])), after = suppressWarnings(min(dates[dates >= t])))
need[, c("github_nearest", "github_off") := { r <- lapply(target, function(t) near(ghd, t)); list(as.Date(sapply(r, `[[`, 1), origin = "1970-01-01"), sapply(r, `[[`, 2)) }]
need[, c("wayback_nearest", "wayback_off") := { r <- lapply(target, function(t) near(wbd, t)); list(as.Date(sapply(r, `[[`, 1), origin = "1970-01-01"), sapply(r, `[[`, 2)) }]
need[, c("cdc_nearest", "cdc_off") := { r <- lapply(target, function(t) near(cdd, t)); list(as.Date(sapply(r, `[[`, 1), origin = "1970-01-01"), sapply(r, `[[`, 2)) }]
print(need)
out(need, "08_month_end_editions")

# ---------------------------------------------------------------------------
hr("V9  Residents with unknown or out-of-state county")
print(idx[!is.na(other_row_one_dose), .(as_of, state_row_one_dose, county_sum_one_dose, other_row_one_dose,
                                        other_pct = round(100 * other_row_one_dose / state_row_one_dose, 2))][seq(1, .N, by = 4)])
unk <- cdc[fips == "UNK" & date >= CDC_TX_FIRST_DATE, .(date, unk_all = administered_dose1_recip, unk_12 = administered_dose1_recip_12plus,
                                                       unk_18 = administered_dose1_recip_18plus)]
unk <- merge(unk, cs[, .(date, all, a18)], by = "date")
unk[, pct_unknown_all := round(100 * unk_all / (unk_all + all), 2)]
cat("CDC 'Unknown County' row, selected report dates:\n")
print(unk[seq(1, .N, by = 40)])
out(unk, "09_cdc_unknown_county")

# ---------------------------------------------------------------------------
hr("V10  Denominators printed in the sources")
print(unique(idx[, .(as_of, state_pop16, state_pop12)])[!duplicated(paste(state_pop16, state_pop12))])
print(cdcc[date == max(date), .(census2019 = sum(census2019), pop5 = sum(census2019_5pluspop),
                                pop12 = sum(census2019_12pluspop), pop18 = sum(census2019_18pluspop),
                                pop65 = sum(census2019_65pluspop))])
# ---------------------------------------------------------------------------
hr("V11  Age bands present in each DSHS edition (eligibility as recorded)")
bands <- age[, .(people = sum(one_dose, na.rm = TRUE)), by = .(as_of, age_group)][people > 0]
first_seen <- bands[, .(first_edition = min(as_of), last_edition = max(as_of)), by = age_group][order(first_edition)]
print(first_seen)
out(first_seen, "11_age_bands_first_seen")

# ---------------------------------------------------------------------------
hr("V12  A county health department source: Harris County Public Health data hub")
suppressMessages(library(jsonlite))
hd <- file.path(DIR_RAW, "county_hd_harris")
rd <- function(f) as.data.table(fromJSON(file.path(hd, f))$features$attributes)
h1 <- rd("Download_DSHS_COVID_Vaccination_Summary_rows.json")
h2 <- rd("Download_DSHS_COVID_Vaccination_for_Ages_12_and_Up_rows.json")
h3 <- rd("Download_COVID_Vaccination_Progress_Overall_rows.json")
cat("Harris hub, DSHS summary table (one row):\n"); print(h1[, .(Date_Str, People_First_Dose, People_Fully_Vaccinated, Total_Vaccine_Administered)])
cat("Harris hub, DSHS percentage table (one row):\n"); print(h2[, .(Date_Str, Partially_Vaccinated, Partially_Vaccinated_12Y, Fully_Vaccinated, Fully_Vaccinated_12Y)])
harris_last <- wb[fips == "48201" & as_of == max(as_of), .(as_of, one_dose, fully)]
cat("DSHS workbook, Harris County, last edition:\n"); print(harris_last)
cat(sprintf("Harris hub weekly series: %d rows, %s to %s; values are cumulative percentages with %d decimals; last value %.2f\n",
            nrow(h3), min(h3$Date_Str), max(h3$Date_Str),
            max(nchar(sub("^[^.]*[.]?", "", format(h3$Overall_Cum, drop0trailing = TRUE, trim = TRUE)))), tail(h3$Overall_Cum, 1)))
out(data.table(item = c("hub DSHS people with first dose", "hub DSHS as-of date", "workbook Harris one dose (last edition)",
                        "workbook last edition", "hub weekly series rows", "hub weekly series precision"),
               value = c(h1$People_First_Dose, h1$Date_Str, harris_last$one_dose, as.character(harris_last$as_of), nrow(h3),
                         "cumulative percentages, 2 decimals")), "12_harris_hub")

# ---------------------------------------------------------------------------
hr("V13  People not yet assigned to a county, and the 15 April 2021 reassignment")
so <- fread(file.path(DIR_DERIVED, "dshs_state_other_daily.csv")); so[, as_of := as.Date(as_of)]
so[, unassigned := state_row_one_dose - county_sum_one_dose]
so[, unassigned_pct := round(100 * unassigned / state_row_one_dose, 2)]
so[, `:=`(d_state = state_row_one_dose - shift(state_row_one_dose), d_county = county_sum_one_dose - shift(county_sum_one_dose),
          d_unassigned = unassigned - shift(unassigned))]
sel <- as.Date(c("2021-01-01", "2021-01-31", "2021-03-01", "2021-04-01", "2021-04-14", "2021-04-15", "2021-04-16",
                 "2021-05-01", "2021-05-25", "2021-07-01", "2021-10-01", "2021-10-05", "2021-10-06"))
print(so[as_of %in% sel, .(as_of, state_row_one_dose, county_sum_one_dose, unassigned, unassigned_pct, d_state, d_county, d_unassigned)])
out(so, "13a_unassigned_daily")
# County-level size of the reassignment: the jump on 15 April beyond the county's
# usual daily change (median of the three days before and after).
g2 <- gh[as_of != as.Date("2021-03-12")]          # drop the one-day faulty edition
setorder(g2, fips, as_of)
g2[, d1 := one_dose - shift(one_dose), by = fips]
lump <- g2[as_of >= DSHS_COUNTY_FIX_DATE - 3 & as_of <= DSHS_COUNTY_FIX_DATE + 3,
           .(jump = d1[as_of == DSHS_COUNTY_FIX_DATE], usual = median(d1[as_of != DSHS_COUNTY_FIX_DATE]),
             before = one_dose[as_of == DSHS_COUNTY_FIX_DATE - 1]), by = .(fips, county)]
lump[, `:=`(reassigned = jump - usual, reassigned_pct_of_prior_count = round(100 * (jump - usual) / before, 1))]
cat(sprintf("\nReassigned to counties on %s: %s people in total; share of the county's previous count: median %.1f%%, 5th-95th percentile %.1f%% to %.1f%%; counties above 10%%: %d\n",
            DSHS_COUNTY_FIX_DATE, format(round(sum(lump$reassigned)), big.mark = ","), median(lump$reassigned_pct_of_prior_count),
            quantile(lump$reassigned_pct_of_prior_count, .05), quantile(lump$reassigned_pct_of_prior_count, .95),
            lump[reassigned_pct_of_prior_count > 10, .N]))
print(lump[order(-reassigned)][1:12])
out(lump[order(-reassigned_pct_of_prior_count)], "13b_reassignment_by_county")
cat("\nOther days on which the statewide county sum fell (faulty or corrected editions):\n")
print(so[!is.na(d_county) & d_county < 0, .(as_of, d_state, d_county, d_unassigned)])

# ---------------------------------------------------------------------------
hr("V14  Do county counts keep changing retroactively after the baseline?")
a16 <- age[age_group %in% c("16-49", "50-64", "65-79", "80+", "Unknown"), .(n16 = sum(one_dose, na.rm = TRUE)), by = .(as_of, fips)]
a16 <- a16[as_of != as.Date("2021-05-07")]        # corrupted age sheet
setorder(a16, fips, as_of)
a16[, d16 := n16 - shift(n16), by = fips]
stab <- a16[!is.na(d16), .(counties_with_fall = sum(d16 < 0), persons_in_falls = sum(d16[d16 < 0]),
                           statewide_change = sum(d16)), by = as_of]
print(stab)
out(stab, "14_count_falls_by_edition")
cat("\nDone.\n")
