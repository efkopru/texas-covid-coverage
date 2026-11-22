# 13_early_reconstruction.R -- county first-dose counts before the main baseline
# (14 December 2020 to 24 May 2021), under an explicit allocation of the records
# that had no county at the time.
#
#   Rscript --vanilla R/13_early_reconstruction.R
#
# Why an assumption is needed
#   Until the edition of 15 April 2021, 5-11% of first-dose recipients were in an
#   "Other" row with no county. In that edition DSHS assigned most of them to
#   counties. County counts published before it are therefore too low, by an
#   amount that differs from county to county.
#
# What is observed
#   R_i     records county i received on 15 April 2021: its rise that day minus
#           its share of that day's new first doses.
#   odds_i  R_i divided by the count published for county i the day before.
#   O(t)    the size of the "Other" row at every earlier date t (statewide).
#   r       the share of the state total that stayed unassigned after the
#           correction (1.16%).
#
# What is assumed (allocation "H", the main one)
#   At every earlier date t, the records that would later be assigned number
#   U(t) = O(t) - r * S(t), where S(t) is the state total, and they are spread
#   over counties in proportion to  C_i(t) * odds_i , where C_i(t) is the count
#   published for county i at t. In words: each county was missing the same
#   relative share of its recipients as the April correction revealed, scaled
#   up or down so that the allocations add up to the unassigned total actually
#   published at that date.
#   At the last edition before the correction (14 April) nothing is assumed:
#   the allocation equals what DSHS did the next day.
#
# Alternatives carried through the analysis
#   "A"  U(t) spread by each county's fixed share of the April assignment.
#   "N"  nothing allocated: counts as published.
#
# Before 12 May 2021 nobody under 16 was eligible, and the county totals equal
# the 16+ counts of the age sheet in every edition that has both, so county
# totals are counts of adults aged 16+.
#
# Outputs
#   data/derived/early_county_allocation.csv   per county: R, odds, stability flag, DSHS phase populations
#   data/derived/early_reconstruction.csv      per county and boundary: published, allocated, reconstructed
#   data/derived/panel_ext_<H|A|N>.csv         6 early intervals + the 12 main ones, same layout as panel.csv
#   outputs/tables/early_*.csv                 checks and summaries

source("R/_common.R")
suppressMessages(library(data.table))
options(width = 220, scipen = 999)

lk    <- fread(file.path(DIR_DERIVED, "county_lookup.csv"), colClasses = list(character = "fips"))
ct    <- fread(file.path(DIR_DERIVED, "dshs_county_total.csv"), colClasses = list(character = "fips"))
so    <- fread(file.path(DIR_DERIVED, "dshs_state_other_daily.csv"))
flags <- fread(file.path(DIR_DERIVED, "county_flags.csv"), colClasses = list(character = "fips"))
ed    <- fread(file.path(DIR_DERIVED, "coverage_editions.csv"), colClasses = list(character = "fips"))
main  <- fread(file.path(DIR_DERIVED, "panel.csv"), colClasses = list(character = "fips"))
cases <- fread(file.path(DIR_DERIVED, "cases_county_daily.csv"), colClasses = list(character = "fips"))
scal  <- fread(file.path(DIR_DERIVED, "covariate_scaling.csv"))
ct[, as_of := as.Date(as_of)]; so[, as_of := as.Date(as_of)]; ed[, as_of := as.Date(as_of)]; cases[, date := as.Date(date)]
for (v in c("start_asof", "end_asof", "data_from", "data_to", "mid")) set(main, j = v, value = as.Date(main[[v]]))

# One row per county and edition. Where an original workbook and a daily copy
# exist for the same date they are identical (verify_02); the workbook is kept.
ct <- ct[order(fips, as_of, -(source == "wayback"))]
ct <- ct[!duplicated(ct[, .(fips, as_of)])]
ct <- ct[as_of != DSHS_FAULTY_DAILY]
so <- so[as_of != DSHS_FAULTY_DAILY]
so[, `:=`(state = as.numeric(state_row_one_dose), county_sum = as.numeric(county_sum_one_dose))]
so[, other := state - county_sum]              # equals the "Other" row wherever that row is printed
stopifnot(so[!is.na(other_row_one_dose), all(other == other_row_one_dose)])
setorder(lk, fips)
FIPS <- lk$fips
Cc <- function(d) { x <- ct[as_of == as.Date(d)]; stopifnot(nrow(x) == 254); as.numeric(x[match(FIPS, fips), one_dose]) }
St <- function(d) so[as_of == as.Date(d), state]
Ot <- function(d) so[as_of == as.Date(d), other]
fix <- DSHS_COUNTY_FIX_DATE
need <- c(EARLY_ASOF, fix - 1, fix, fix + 7, DSHS_FLUX_END)
stopifnot(all(need %in% ct$as_of), all(need %in% so$as_of), max(EARLY_ASOF) == fix - 1)
src <- ct[as_of %in% EARLY_ASOF, .(source = source[1], file = file[1]), keyby = as_of]
msg("Boundary editions before the baseline and where their county counts come from:"); print(src)

# ---------------------------------------------------------------------------
# 1. The correction of 15 April 2021, county by county
# ---------------------------------------------------------------------------
r_resid <- Ot(fix) / St(fix)                                   # share still unassigned after the correction
jump <- Cc(fix) - Cc(fix - 1)
wk <- Cc(fix + 7) - Cc(fix)                                    # the following week, for the county mix of new first doses
new_fix <- (1 - r_resid) * (St(fix) - St(fix - 1)) * wk / sum(wk)
R <- jump - new_fix
odds <- pmax(R, 0) / Cc(fix - 1)
msg("15 April 2021: county counts rose by %s; state total by %s; 'Other' fell by %s; records assigned to counties (sum of R): %s",
    format(sum(jump), big.mark = ","), format(St(fix) - St(fix - 1), big.mark = ","), format(Ot(fix - 1) - Ot(fix), big.mark = ","),
    format(round(sum(R)), big.mark = ","))
msg("Share of the state total still unassigned after the correction: %.3f%%; counties with negative R: %d (sum %.0f)",
    100 * r_resid, sum(R < 0), sum(R[R < 0]))

# Records kept moving between counties until about 10 May. Falls in a county's
# count over that period can only be removals, so they measure how unsettled
# its records were.
y <- ct[as_of >= fix & as_of <= DSHS_FLUX_END][order(fips, as_of)]
y[, d := one_dose - shift(one_dose), by = fips]
fl <- y[!is.na(d), .(falls_after_fix = -sum(d[d < 0]), fall_days = sum(d < 0)), by = fips]
ca <- data.table(fips = FIPS, county = lk$county, count_apr14 = Cc(fix - 1), count_apr15 = Cc(fix), rise_apr15 = jump,
                 new_first_doses_apr15_est = new_fix, assigned_apr15 = R, odds = odds,
                 share_of_assignment = pmax(R, 0) / sum(pmax(R, 0)))
ca <- merge(ca, fl, by = "fips")
ca[, falls_pct_of_apr15_count := 100 * falls_after_fix / count_apr15]
# A second sign of unsettled records: a boundary edition (or the edition of the
# correction itself) whose count for the county is higher than a later count,
# which means that some of the records it contained were afterwards taken away
# (typically a batch credited to the wrong county for some days). The one-day
# fault of 24 March, when a batch vanished and returned, is not such a removal.
later_min <- function(d) ct[as_of > d & as_of <= DSHS_FLUX_END & as_of != as.Date("2021-03-24"), .(mn = as.numeric(min(one_dose))), by = fips]
rm_pct <- sapply(as.character(c(EARLY_ASOF, fix)), function(d) {
  m <- later_min(as.Date(d)); C <- Cc(d)
  100 * pmax(C - m[match(FIPS, fips), mn], 0) / pmax(C, 1)
})
stopifnot(identical(ca$fips, FIPS))
ca[, max_boundary_removed_pct := apply(rm_pct, 1, max)]
ca[, worst_boundary := colnames(rm_pct)[apply(rm_pct, 1, which.max)]]
ca[max_boundary_removed_pct == 0, worst_boundary := NA_character_]
ca[, early_unstable := falls_pct_of_apr15_count > EARLY_UNSTABLE_FALLS_PCT | max_boundary_removed_pct > EARLY_UNSTABLE_FALLS_PCT]
ca <- merge(ca, flags[, .(fips, pop16, excl_county)], by = "fips")

# DSHS's own estimates of the population in each priority phase, printed in the
# county sheet (2019-based). Read from the daily copy of the 14 April edition.
squish <- function(v) trimws(gsub("[[:space:]]+", " ", v))
num <- function(v) suppressWarnings(as.numeric(gsub(",", "", v)))
f14 <- file.path(DIR_RAW, "dshs_vax_github/snapshots", sprintf("%s.csv", fix - 1))
x <- utils::read.csv(f14, header = FALSE, colClasses = "character", check.names = FALSE, fill = TRUE,
                     na.strings = character(), encoding = "UTF-8")
h <- squish(unlist(x[1, ])); x <- x[-1, , drop = FALSE]
gc1 <- function(p) { i <- grep(p, h, ignore.case = TRUE); stopifnot(length(i) >= 1); num(x[[i[1]]]) }
ph <- data.table(ckey = county_key(sub("^[*]", "", squish(x[[grep("^county", h, ignore.case = TRUE)[1]]]))),
                 dshs_pop16 = gc1("population[, ]*16[+]"), dshs_pop65 = gc1("population[, ]*65[+]"),
                 dshs_hcw = gc1("healthcare workers"), dshs_ltc = gc1("long-term care residents"),
                 dshs_medical_16_64 = gc1("medical condition"), dshs_education = gc1("education"))
st_row <- ph[ckey == "TEXAS"]
ph <- merge(data.table(fips = FIPS, ckey = county_key(lk$county)), ph, by = "ckey")[, ckey := NULL]
stopifnot(nrow(ph) == 254, !anyNA(ph$dshs_pop16), sum(ph$dshs_pop16) == st_row$dshs_pop16)
# Phase 1A + 1B: health-care workers, long-term-care residents, everyone 65+,
# and people 16-64 with a medical condition. The groups overlap (most
# long-term-care residents are 65+), so the sum is an upper bound.
ph[, elig_1b_share := pmin((dshs_hcw + dshs_ltc + dshs_pop65 + dshs_medical_16_64) / dshs_pop16, 1)]
ca <- merge(ca, ph, by = "fips")
setorder(ca, fips)
fwrite(ca, file.path(DIR_DERIVED, "early_county_allocation.csv"))
unstable <- ca[early_unstable == TRUE, fips]
kept <- ca[excl_county == FALSE, fips]
stable <- setdiff(kept, unstable)
msg("Counties with unsettled early records (falls after the correction, or records at a boundary later removed, above %d%% of the count): %d, of which %d among the %d modelled counties (%.2f%% of their adults)",
    EARLY_UNSTABLE_FALLS_PCT, length(unstable), length(intersect(unstable, kept)), length(kept),
    100 * ca[fips %in% intersect(unstable, kept), sum(pop16)] / ca[fips %in% kept, sum(pop16)])
msg("  by falls after the correction: %d; by a boundary count later reduced: %d; by both: %d",
    ca[falls_pct_of_apr15_count > EARLY_UNSTABLE_FALLS_PCT, .N], ca[max_boundary_removed_pct > EARLY_UNSTABLE_FALLS_PCT, .N],
    ca[falls_pct_of_apr15_count > EARLY_UNSTABLE_FALLS_PCT & max_boundary_removed_pct > EARLY_UNSTABLE_FALLS_PCT, .N])
print(ca[early_unstable == TRUE][order(-pmax(falls_pct_of_apr15_count, max_boundary_removed_pct)),
         .(county, pop16, excl_county, count_apr15, assigned_apr15 = round(assigned_apr15), falls_after_fix, fall_days,
           falls_pct = round(falls_pct_of_apr15_count, 1), boundary_removed_pct = round(max_boundary_removed_pct, 1), worst_boundary)])
fwrite(ca[early_unstable == TRUE & excl_county == FALSE][order(-pmax(falls_pct_of_apr15_count, max_boundary_removed_pct)),
          .(fips, county, pop16, count_apr15, falls_after_fix, falls_pct_of_apr15_count, max_boundary_removed_pct, worst_boundary)],
       file.path(DIR_TAB, "early_unstable_counties.csv"))

# ---------------------------------------------------------------------------
# 2. Allocation at each earlier boundary
# ---------------------------------------------------------------------------
allocate <- function(d) {
  C <- Cc(d)
  U <- max(Ot(d) - r_resid * St(d), 0)
  wH <- C * odds; wA <- pmax(R, 0)
  list(C = C, U = U, H = U * wH / sum(wH), A = U * wA / sum(wA), N = rep(0, length(C)), u = U / sum(wH), const_total = sum(wH))
}
al <- lapply(EARLY_ASOF, allocate); names(al) <- as.character(EARLY_ASOF)
by_date <- rbindlist(lapply(names(al), function(d) {
  a <- al[[d]]
  data.table(as_of = as.Date(d), data_through = as.Date(d) - 1, state_total = St(d), county_sum = sum(a$C), unassigned = Ot(d),
             unassigned_pct_of_state = 100 * Ot(d) / St(d), assumed_never_assigned = r_resid * St(d), allocated = a$U,
             allocated_pct_of_county_sum = 100 * a$U / sum(a$C),
             total_if_county_shares_were_constant = a$const_total, scaling_u = a$u,
             largest_county_uplift_pct_H = 100 * max((a$H / pmax(a$C, 1))[FIPS %in% stable]),
             largest_county_uplift_pct_A = 100 * max((a$A / pmax(a$C, 1))[FIPS %in% stable]),
             counties_uplift_over_10pct_H = sum((a$H / pmax(a$C, 1))[FIPS %in% stable] > 0.10))
}))
fwrite(by_date, file.path(DIR_TAB, "early_allocation_by_date.csv"))
cat("\nAllocation at each boundary edition:\n"); print(by_date[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])

base_asof <- GRIDS$main[1]
b <- ed[as_of == base_asof][match(FIPS, fips)]
rec <- rbind(
  data.table(fips = FIPS, as_of = EARLY_START, published = 0, alloc_H = 0, alloc_A = 0),
  rbindlist(lapply(names(al), function(d) data.table(fips = FIPS, as_of = as.Date(d), published = al[[d]]$C,
                                                     alloc_H = al[[d]]$H, alloc_A = al[[d]]$A))),
  data.table(fips = FIPS, as_of = base_asof, published = as.numeric(b$n16), alloc_H = 0, alloc_A = 0))
rec[, `:=`(n_H = round(published + alloc_H), n_A = round(published + alloc_A), n_N = published)]
rec <- merge(rec, ca[, .(fips, county, pop16, excl_county, early_unstable)], by = "fips")
rec[, `:=`(data_through = as_of - 1, cov_H = 100 * n_H / pop16, cov_A = 100 * n_A / pop16, cov_N = 100 * n_N / pop16)]
setorder(rec, as_of, fips)
setcolorder(rec, c("fips", "county", "as_of", "data_through", "pop16", "excl_county", "early_unstable", "published", "alloc_H", "alloc_A"))
fwrite(rec, file.path(DIR_DERIVED, "early_reconstruction.csv"))
# The baseline row is the 16+ count of the age sheet (as in the main analysis).
stopifnot(rec[as_of == base_asof, all(n_H == published)])

# ---------------------------------------------------------------------------
# 3. Checks
# ---------------------------------------------------------------------------
# (a) Does the county pattern revealed on 15 April show up when the unassigned
#     stock moved at other times? If county i is missing the share u(t) * odds_i
#     of its recipients at date t, then between two dates the growth of its
#     published count differs from its true growth by about (u(t1) - u(t2)) *
#     odds_i. A regression of published growth on odds should therefore have a
#     slope near u(t1) - u(t2) in every window: clearly positive when unassigned
#     records were being worked off, near zero or negative when they piled up.
win <- as.Date(c("2021-01-14", "2021-01-28", "2021-02-12", "2021-02-27", "2021-03-14", "2021-03-30", "2021-04-14"))
stopifnot(all(win %in% ct$as_of))
uu <- function(d) { C <- Cc(d); max(Ot(d) - r_resid * St(d), 0) / sum(C * odds) }
pt <- rbindlist(lapply(seq_len(length(win) - 1), function(i) {
  a <- win[i]; z <- win[i + 1]
  dd <- data.table(fips = FIPS, g = log(Cc(z) / Cc(a)), odds = odds, w = Cc(fix - 1))[fips %in% stable & is.finite(g)]
  m1 <- summary(lm(g ~ odds, data = dd, weights = w))$coefficients
  m0 <- summary(lm(g ~ odds, data = dd))$coefficients
  data.table(from = a, to = z, counties = nrow(dd),
             unassigned_from = Ot(a), unassigned_to = Ot(z), unassigned_pct_from = 100 * Ot(a) / St(a), unassigned_pct_to = 100 * Ot(z) / St(z),
             predicted_slope = uu(a) - uu(z),
             slope_weighted = m1[2, 1], se_weighted = m1[2, 2], slope_unweighted = m0[2, 1], se_unweighted = m0[2, 2])
}))
fwrite(pt, file.path(DIR_TAB, "early_persistence_test.csv"))
cat("\nGrowth of published county counts regressed on the share received in April, by window:\n")
print(pt[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 3) else v)])
msg("Correlation between predicted and estimated slopes over the %d windows: %.2f (weighted), %.2f (unweighted)", nrow(pt),
    cor(pt$predicted_slope, pt$slope_weighted), cor(pt$predicted_slope, pt$slope_unweighted))

# (b) Boundary editions: counties whose published count is below the previous
#     day's (a correction or a one-day fault such as that of 24 March).
bc <- rbindlist(lapply(EARLY_ASOF, function(d) {
  prev <- max(ct[as_of < d, as_of]); nxt <- min(ct[as_of > d, as_of])
  z <- data.table(fips = FIPS, county = lk$county, prev = Cc(prev), at = Cc(d), nxt = Cc(nxt))
  z[, fall := at - prev]
  data.table(as_of = d, previous_edition = prev, next_edition = nxt, counties_below_previous = z[fall < 0, .N],
             persons = z[fall < 0, sum(fall)], counties_below_previous_by_2pct = z[fall < -0.02 * prev & fall <= -5, .N],
             largest = z[which.min(fall), sprintf("%s %d (%.1f%%)", county, as.integer(fall), 100 * fall / prev)],
             below_previous_and_next_recovers = z[fall < -0.02 * prev & fall <= -5 & nxt >= prev, .N])
}))
fwrite(bc, file.path(DIR_TAB, "early_boundary_checks.csv"))
cat("\nBoundary editions against the day before:\n"); print(bc)

# (c) County totals against the 16+ counts of the age sheet, before 12-15 year olds became eligible
ag <- ed[as_of < as.Date("2021-05-12"), .(counties = .N, county_total = sum(one_dose_all), adults_16plus_age_sheet = sum(n16),
                                          counties_that_differ = sum(n16 != one_dose_all)), keyby = as_of]
fwrite(ag, file.path(DIR_TAB, "early_county_total_vs_16plus.csv"))
cat("\nCounty totals against 16+ counts of the age sheet:\n"); print(ag)
stopifnot(ag[, all(counties_that_differ == 0)])

# (d) The episodes in which records moved, for the write-up
dly <- ct[as_of >= as.Date("2020-12-29") & as_of <= as.Date("2021-05-25")][order(fips, as_of)]
dly[, d := one_dose - shift(one_dose), by = fips]
dd <- dly[!is.na(d), .(rises = sum(d[d > 0]), falls = sum(d[d < 0]), counties_falling = sum(d < 0)), keyby = as_of]
g24 <- as.Date("2021-03-24")
tar <- dly[county == "Tarrant" & as_of %in% (g24 + 0:1), d]
feb <- so[as_of >= as.Date("2021-02-01") & as_of <= as.Date("2021-03-01")]
ev <- data.table(
  item = c("Unassigned records, highest in February (date)", "Unassigned records, highest in February",
           "Unassigned records, lowest in late February (date)", "Unassigned records, lowest in late February",
           "24 March: sum of falls in county counts", "24 March: counties with a fall", "24 March: change in Tarrant County",
           "25 March: change in Tarrant County", "15 April: records assigned to counties", "15 April: fall in the unassigned row",
           "16 April - 11 May: sum of falls in county counts", "16 April - 11 May: counties with any fall",
           "12 May - 25 May: sum of falls in county counts"),
  value = c(format(feb[which.max(other), as_of]), feb[, max(other)], format(feb[as_of > as.Date("2021-02-12")][which.min(other), as_of]),
            feb[as_of > as.Date("2021-02-12"), min(other)],
            dd[as_of == g24, falls], dd[as_of == g24, counties_falling], tar[1], tar[2], round(sum(R)), Ot(fix - 1) - Ot(fix),
            dd[as_of > fix & as_of <= DSHS_FLUX_END, sum(falls)], ca[falls_after_fix > 0, .N],
            dd[as_of > DSHS_FLUX_END, sum(falls)]))
fwrite(ev, file.path(DIR_TAB, "early_events.csv"))
cat("\nEpisodes:\n"); print(ev)

# (e) Eligibility: who could be vaccinated when (DSHS news releases, data/raw/dshs_news)
#     and DSHS's own population estimates for each priority group (state row).
el <- data.table(
  from = as.Date(c("2020-12-14", "2020-12-29", "2021-03-03", "2021-03-15", "2021-03-29", "2021-05-12")),
  eligible = c("Phase 1A: front-line health-care workers and residents of long-term-care facilities",
               "Phase 1B added: people aged 65+ and people aged 16+ with a chronic medical condition",
               "School and child-care staff added",
               "Phase 1C added: people aged 50-64",
               "Everyone aged 16+",
               "Adolescents aged 12-15 added (not part of this study's adult counts)"),
  source = c("DSHS news release of 14 Dec 2020 (first doses delivered that day)",
             "DSHS news release of 21 Dec 2020 (definition); release of 10 Mar 2021 says Phase 1B began later in December; start date of 29 Dec from press reports, not from a DSHS file",
             "DSHS news release of 3 Mar 2021", "DSHS news release of 10 Mar 2021", "DSHS news release of 23 Mar 2021",
             "DSHS news release of 12 May 2021"),
  dshs_population_estimate = c(st_row$dshs_hcw + st_row$dshs_ltc,
                               st_row$dshs_hcw + st_row$dshs_ltc + st_row$dshs_pop65 + st_row$dshs_medical_16_64,
                               st_row$dshs_education, NA, st_row$dshs_pop16, NA),
  note = c("health-care workers plus long-term-care residents",
           "cumulative: adds 65+ and 16-64 with a medical condition; groups overlap, so an upper bound",
           "this group alone; overlaps with the groups above", "no county estimate printed by DSHS", "DSHS 16+ population (2019-based)", ""))
el[, pct_of_dshs_16plus := 100 * dshs_population_estimate / st_row$dshs_pop16]
fwrite(el, file.path(DIR_TAB, "early_eligibility.csv"))
cat("\nEligibility timeline:\n"); print(el[, .(from, eligible = substr(eligible, 1, 60), dshs_population_estimate, pct = round(pct_of_dshs_16plus, 1))])
msg("Share of adults in Phase 1A or 1B by DSHS's estimates, across counties: median %.0f%%, range %.0f%% to %.0f%%",
    100 * median(ca$elig_1b_share), 100 * min(ca$elig_1b_share), 100 * max(ca$elig_1b_share))

# ---------------------------------------------------------------------------
# 4. Extended panels: six early intervals followed by the twelve main ones
# ---------------------------------------------------------------------------
bnd <- c(EARLY_START, EARLY_ASOF, base_asof)
iv <- data.table(k = seq_len(length(bnd) - 1), start_asof = bnd[-length(bnd)], end_asof = bnd[-1])
iv[, `:=`(days = as.integer(end_asof - start_asof), data_from = start_asof, data_to = end_asof - 1)]
iv[, mid := data_from + days / 2]
iv[, label := sprintf("%s - %s", format(data_from, "%d %b %Y"), format(data_to, "%d %b %Y"))]
n_early <- nrow(iv)
cases[, new_cases := new_confirmed + new_probable]
cr <- rbindlist(lapply(seq_len(n_early), function(i) {
  e <- iv$data_from[i] - 1
  cases[date > e - 30 & date <= e, .(cases_prev30 = sum(new_cases, na.rm = TRUE), confirmed_prev30 = sum(new_confirmed, na.rm = TRUE)), by = fips][, k := iv$k[i]]
}))
cs <- scal[variable == "log_case_rate_prev30_plus10"]
cvc <- c("fips", "county", "pop16", "pop_total", "pct65_of_16plus", "med_hh_income", "med_hh_income_moe", "income_imputed", "median_age",
         "acs_pct65_of_adults", "excl_county", "max_cov16", "dshs_pop16", "z_age", "z_income", "z_age_acs")
cv <- unique(main[, ..cvc]); stopifnot(nrow(cv) == 254)
build_ext <- function(v) {
  n <- rec[, .(fips, as_of, n = get(paste0("n_", v)), alloc = if (v == "N") 0 else get(paste0("alloc_", v)))]
  p <- merge(CJ(fips = FIPS, k = iv$k), iv, by = "k")
  p <- merge(p, n[, .(fips, start_asof = as_of, cum_start = n, alloc_start = alloc)], by = c("fips", "start_asof"))
  p <- merge(p, n[, .(fips, end_asof = as_of, cum_end = n, alloc_end = alloc)], by = c("fips", "end_asof"))
  p <- merge(p, cv, by = "fips")
  p <- merge(p, cr, by = c("fips", "k"))
  p[, `:=`(y = cum_end - cum_start, at_risk = pop16 - cum_start, cov_start = 100 * cum_start / pop16, cov_end = 100 * cum_end / pop16,
           case_rate_prev30 = 1e5 * cases_prev30 / pop_total, confirmed_rate_prev30 = 1e5 * confirmed_prev30 / pop_total)]
  p[, log_case_rate := log(case_rate_prev30 + 10)]
  p[, z_cases := (log_case_rate - cs$mean) / cs$sd]          # same scale as the main panel
  p[, z_cases_confirmed := NA_real_]
  p[, exclude := fifelse(excl_county, "county: recorded count exceeds population estimate",
                 fifelse(fips %in% unstable, "early records unsettled: records later moved or removed",
                 fifelse(cov_start >= COVERAGE_CEILING, "recorded coverage at or above 95% at interval start",
                 fifelse(y > at_risk, "new first doses exceed remaining population", ""))))]
  p[, usable := exclude == ""]
  p[, y_floored := usable & y < 0]
  p[, y_model := fifelse(usable, pmax(y, 0), NA_real_)]
  p[, uptake := fifelse(usable, y_model / at_risk, NA_real_)]
  p[, uptake30 := 1 - (1 - uptake)^(30 / days)]
  p[, early := TRUE]
  m <- copy(main)[, `:=`(k = k + n_early, early = FALSE, alloc_start = 0, alloc_end = 0)]
  for (cc in c("cum_start", "cum_end", "y", "at_risk", "y_model")) set(m, j = cc, value = as.numeric(m[[cc]]))
  out <- rbind(p, m, fill = TRUE)
  out[, `:=`(variant = v, k_main = fifelse(early, NA_integer_, k - n_early), early_unstable = fips %in% unstable)]
  out <- merge(out, ca[, .(fips, elig_1b_share)], by = "fips")
  setorder(out, fips, k)
  stopifnot(nrow(out) == 254 * (n_early + main[, max(k)]),
            out[k == n_early, all(cum_end == main[k == 1][match(out[k == n_early, fips], fips), cum_start])])
  out[]
}
ext <- lapply(names(EARLY_VARIANTS), build_ext); names(ext) <- names(EARLY_VARIANTS)
for (v in names(ext)) fwrite(ext[[v]], file.path(DIR_DERIVED, sprintf("panel_ext_%s.csv", v)))
pH <- ext$H
msg("Extended panel: %d counties x %d intervals; early rows usable in the model: %d of %d (%d counties)",
    pH[, uniqueN(fips)], pH[, max(k)], pH[early == TRUE, sum(usable)], pH[early == TRUE, .N], pH[early == TRUE & usable == TRUE, uniqueN(fips)])
print(pH[early == TRUE & usable == FALSE, .(rows = .N, counties = uniqueN(fips)), by = exclude])
msg("Early rows where the reconstructed count fell and new first doses were set to zero: %d", pH[early == TRUE, sum(y_floored)])

# Statewide and typical-county figures by early interval, for each allocation
sumv <- function(p, v) {
  one <- function(d, grp) d[, .(variant = v, group = grp, days = days[1], counties = uniqueN(fips), new_first_doses = sum(y),
                                cov_start = 100 * sum(cum_start) / sum(pop16), cov_end = 100 * sum(cum_end) / sum(pop16),
                                uptake30_pooled = 100 * (1 - (1 - sum(y) / sum(at_risk))^(30 / days[1])),
                                uptake30_median_county = 100 * median(1 - (1 - pmax(y, 0) / at_risk)^(30 / days), na.rm = TRUE),
                                median_case_rate_prev30 = median(case_rate_prev30)), by = .(k, label)]
  e <- p[early == TRUE]
  rbind(one(e, "all 254 counties"), one(e[excl_county == FALSE], "238 modelled counties"),
        one(e[fips %in% stable], sprintf("%d modelled counties with stable early records", length(stable))))
}
sw <- rbindlist(lapply(names(ext), function(v) sumv(ext[[v]], v)))
fwrite(sw, file.path(DIR_TAB, "early_statewide_by_interval.csv"))
cat("\nBy early interval, allocation H:\n")
print(sw[variant == "H" & group != "238 modelled counties", lapply(.SD, function(z) if (is.numeric(z)) round(z, 2) else z)])

# Spread of coverage across counties at each early boundary, for each allocation
gapv <- rbindlist(lapply(names(EARLY_VARIANTS), function(v) {
  rec[fips %in% stable & as_of > EARLY_START, {
    cv_ <- get(paste0("cov_", v))
    .(variant = v, counties = .N, p10 = quantile(cv_, .1), p25 = quantile(cv_, .25), median = median(cv_), p75 = quantile(cv_, .75),
      p90 = quantile(cv_, .9), gap_p90_p10 = quantile(cv_, .9) - quantile(cv_, .1), sd = sd(cv_),
      pooled = 100 * sum(get(paste0("n_", v))) / sum(pop16),
      ratio_p90_p10 = quantile(cv_, .9) / quantile(cv_, .1))
  }, by = .(as_of, data_through)]
}))
fwrite(gapv, file.path(DIR_TAB, "early_gap_by_date.csv"))
cat("\nSpread of reconstructed coverage across the", length(stable), "modelled counties with stable early records:\n")
print(dcast(gapv, data_through ~ variant, value.var = "gap_p90_p10")[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 2) else z)])
print(gapv[variant == "H", lapply(.SD, function(z) if (is.numeric(z)) round(z, 2) else z)])

# How much the allocation moves a county's reconstructed coverage
mv <- rec[fips %in% stable & as_of %in% EARLY_ASOF, .(counties = .N,
          median_uplift_pct_H = 100 * median(alloc_H / pmax(published, 1)), p90_uplift_pct_H = 100 * quantile(alloc_H / pmax(published, 1), .9),
          max_uplift_pct_H = 100 * max(alloc_H / pmax(published, 1)),
          median_abs_diff_points_H_vs_N = median(abs(cov_H - cov_N)), max_abs_diff_points_H_vs_N = max(abs(cov_H - cov_N)),
          median_abs_diff_points_H_vs_A = median(abs(cov_H - cov_A)), max_abs_diff_points_H_vs_A = max(abs(cov_H - cov_A)),
          rank_cor_H_vs_N = cor(cov_H, cov_N, method = "spearman"), rank_cor_H_vs_A = cor(cov_H, cov_A, method = "spearman")),
          by = .(as_of, data_through)]
fwrite(mv, file.path(DIR_TAB, "early_allocation_effect.csv"))
cat("\nEffect of the allocation on county coverage:\n"); print(mv[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 3) else z)])
msg("Done.")
