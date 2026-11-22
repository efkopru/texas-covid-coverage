# 15_early_outputs.R -- tables, figures and write-up for the extension to the
# first months of the rollout (14 December 2020 to 24 May 2021).
#
#   Rscript --vanilla R/15_early_outputs.R
#
# Needs the outputs of R/13_early_reconstruction.R and R/14_early_models.R.
# Writes outputs/figures/fig12-fig16, their table twins in outputs/tables, and
# docs/03_early_rollout.md from docs/03_early_rollout_template.md.
#
# "Published" means a county count exactly as it stood in a DSHS edition.
# "Reconstructed" means published plus the allocated share of the records that
# had no county at the time (allocation H unless another is named).
# "Modelled" means a posterior summary from the model fitted to the
# reconstructed series.

source("R/_common.R")
source("R/_models.R")
source("R/_plot.R")
source("R/_report.R")
options(width = 220, scipen = 999)
out <- function(x, name) fwrite(x, file.path(DIR_TAB, paste0(name, ".csv")))
fmt_date <- function(x) sub("^0", "", format(as.Date(x), "%d %b %Y"))
qs <- function(m, p = c(0.025, 0.5, 0.975)) t(apply(m, 1, quantile, probs = p, names = FALSE))

ca    <- fread(file.path(DIR_DERIVED, "early_county_allocation.csv"), colClasses = list(character = "fips"))
rec   <- fread(file.path(DIR_DERIVED, "early_reconstruction.csv"), colClasses = list(character = "fips"))
ed    <- fread(file.path(DIR_DERIVED, "coverage_editions.csv"), colClasses = list(character = "fips"))
so    <- fread(file.path(DIR_DERIVED, "dshs_state_other_daily.csv"))
shape <- st_read(file.path(DIR_DERIVED, "tx_counties.gpkg"), quiet = TRUE)[, "fips"]
for (x in list(rec, ed, so)) for (v in intersect(c("as_of", "data_through"), names(x))) set(x, j = v, value = as.Date(x[[v]]))
d  <- load_panel("panel_ext_H.csv")
dr <- readRDS(file.path(DIR_MOD, "samples_ext_H.rds"))
stopifnot(identical(dr$panel_key$fips, d$fips), identical(dr$panel_key$k, d$k))
stable <- ca[excl_county == FALSE & early_unstable == FALSE, sort(fips)]
kept <- ca[excl_county == FALSE, sort(fips)]
n_early <- d[early == TRUE, max(k)]
iv <- unique(d[, .(k, label, data_from, data_to, days, mid, early)])
base_asof <- GRIDS$main[1]
fix <- DSHS_COUNTY_FIX_DATE
cap_early <- paste("Source: Texas DSHS county vaccine workbook, daily copies (verified against the original workbooks) and original editions;",
                   "U.S. Census Bureau Vintage 2025 population estimates.", sep = "\n")

# ===========================================================================
# 1. Tables
# ===========================================================================
bd  <- rd("early_allocation_by_date.csv"); bd[, `:=`(as_of = as.Date(as_of), data_through = as.Date(data_through))]
pt  <- rd("early_persistence_test.csv"); pt[, `:=`(from = as.Date(from), to = as.Date(to))]
sw  <- rd("early_statewide_by_interval.csv")
gp  <- rd("early_gap_by_date.csv"); gp[, `:=`(as_of = as.Date(as_of), data_through = as.Date(data_through))]
ae  <- rd("early_allocation_effect.csv"); ae[, data_through := as.Date(data_through)]
ev  <- rd("early_events.csv")
el  <- rd("early_eligibility.csv"); el[, from := as.Date(from)]
pa  <- rd("early_period_associations.csv")
mp  <- rd("early_model_parameters.csv")
ru  <- rd("early_relative_uptake_by_period.csv", colClasses = list(character = "fips"))
pc  <- rd("early_period_correlations.csv")
mu  <- rd("early_modelled_uptake.csv", colClasses = list(character = "fips"))
uc  <- rd("early_unstable_counties.csv", colClasses = list(character = "fips"))

# Uptake per 30 days by interval over the whole extended series, counties with settled early records:
# pooled (reconstructed before the baseline, recorded after), and the modelled median county with its 10th-90th percentile range
logh <- dr$eta - d$off
u30 <- 100 * cloglog_inv(logh)
rs <- which(d$fips %in% stable)
ds <- d[rs]
cur <- rbindlist(lapply(iv$k, function(kk) {
  i <- which(ds$k == kk)
  cq <- apply(u30[rs[i], , drop = FALSE], 2, quantile, probs = c(0.1, 0.5, 0.9))
  data.table(k = kk, pooled = 100 * (1 - (1 - sum(ds$y[i]) / sum(ds$at_risk[i]))^(30 / iv$days[kk])),
             county_p10 = median(cq[1, ]), county_median = median(cq[2, ]), county_p90 = median(cq[3, ]),
             cov_end_pooled = 100 * sum(ds$cum_end[i]) / sum(ds$pop16[i]))
}))
cur <- merge(iv, cur, by = "k")
out(cur[, .(k, label, days, reconstructed = early, uptake30_pooled_pct = pooled, modelled_median_county_pct = county_median,
            modelled_p10_county_pct = county_p10, modelled_p90_county_pct = county_p90, pooled_coverage_at_end_pct = cov_end_pooled)],
    "fig14_extended_uptake_by_interval")

# Spread of county coverage over the whole series for the same counties
late <- ed[as_of %in% GRIDS$main & fips %in% stable, .(variant = "recorded", counties = .N, p10 = quantile(cov16, .1), median = median(cov16),
                                                      p90 = quantile(cov16, .9), sd = sd(cov16)), by = .(as_of)]
late[, `:=`(data_through = as_of - 1, gap_p90_p10 = p90 - p10)]
gl <- rbind(gp[variant == "H" & as_of < base_asof, .(as_of, data_through, variant = "reconstructed (H)", counties, p10, median, p90, sd, gap_p90_p10)],
            late[, .(as_of, data_through, variant, counties, p10, median, p90, sd, gap_p90_p10)])
setorder(gl, as_of)
out(gl, "fig14b_coverage_spread_extended")

# Is the weak link between early and later relative uptake a product of the
# allocation? The same correlations computed from the counts themselves (no
# model), for each allocation, in counties with at least 5,000 adults (below
# that, single doses move the rate too much for an unmodelled comparison).
crude <- rbindlist(lapply(names(EARLY_VARIANTS), function(v) {
  p <- fread(file.path(DIR_DERIVED, sprintf("panel_ext_%s.csv", v)), colClasses = list(character = "fips"))
  p <- p[fips %in% stable & pop16 >= 5000 & at_risk > 0]
  p[, lh := log(-log1p(-pmin(pmax(y, 0.5) / at_risk, 1 - 1e-9))) - log(days / 30)]
  p[, lh := lh - mean(lh), by = k]
  per <- p[, .(e1 = mean(lh[k %in% 1:4]), e2 = mean(lh[k %in% 5:6]), later = mean(lh[k > 6])), by = fips]
  data.table(variant = v, allocation = EARLY_VARIANTS[[v]], counties = nrow(per), early_with_spring = cor(per$e1, per$e2),
             early_with_later = cor(per$e1, per$later), spring_with_later = cor(per$e2, per$later))
}))
out(crude, "early_period_correlations_by_allocation")
cat("\nCorrelations between periods from the counts themselves, by allocation:\n"); print(crude)

# ===========================================================================
# 2. Figures
# ===========================================================================
msg("Figures")
# ---- Figure 12: the unassigned records and where the April correction put them
un <- so[as_of != DSHS_FAULTY_DAILY & as_of <= as.Date("2021-05-25"),
         .(as_of, pct = 100 * (state_row_one_dose - county_sum_one_dose) / state_row_one_dose)]
out(un, "fig12a_unassigned_share_daily")
bpts <- un[as_of %in% EARLY_ASOF]
feb_drop <- as.numeric(ev[item == "Unassigned records, highest in February", value]) - as.numeric(ev[item == "Unassigned records, lowest in late February", value])
p12a <- ggplot(un, aes(as_of, pct)) +
  geom_line(colour = PAL$blue, linewidth = 0.8, lineend = "round") +
  geom_point(data = bpts, colour = PAL$surface, size = 3.4) + geom_point(data = bpts, colour = PAL$ink, size = 2) +
  annotate("text", x = as.Date("2021-02-20"), y = 10.9, hjust = 0, vjust = 0, family = FONT, size = 3.2, colour = PAL$ink2, lineheight = 1.05,
           label = sprintf("12-27 Feb: the number without a county\nfalls by %s", format(round(feb_drop, -3), big.mark = ","))) +
  annotate("text", x = fix + 4, y = 7.4, hjust = 0, vjust = 1, family = FONT, size = 3.2, colour = PAL$ink2, lineheight = 1.05,
           label = sprintf("15 Apr: %s records\nassigned to counties\nin one edition", format(round(sum(ca$assigned_apr15), -3), big.mark = ","))) +
  annotate("text", x = as.Date("2021-01-03"), y = 2.1, hjust = 0, vjust = 1, family = FONT, size = 3.2, colour = PAL$ink2, lineheight = 1.05,
           label = "Black dots: the five editions used as boundaries") +
  scale_x_date(date_breaks = "1 month", date_labels = "%b\n%Y", expand = expansion(mult = c(0.01, 0.03))) +
  scale_y_continuous(limits = c(0, 12.4), breaks = seq(0, 12, 2), labels = function(x) paste0(x, "%"), expand = c(0, 0)) +
  labs(title = "First-dose recipients with no county on record",
       subtitle = "Share of the state total, by daily DSHS edition, 29 December 2020 to 25 May 2021", x = NULL, y = NULL) + theme_tx()
ob <- c(-Inf, 1, 5, 10, 15, 20, Inf); olab <- c("Under 1%", "1-5%", "5-10%", "10-15%", "15-20%", "20% or more")
m12 <- ca[, .(fips, val = 100 * odds, flag = FALSE)]
m12[, cls := factor(as.character(cut(val, ob, olab, right = FALSE)), levels = olab)]
p12b <- ggplot(merge(shape, m12, by = "fips")) + geom_sf(aes(fill = cls), colour = PAL$surface, linewidth = 0.1, show.legend = TRUE) +
  scale_fill_manual(values = setNames(PAL$seq6, olab), drop = FALSE, name = "Records received on 15 April, as a share of the county's count the day before",
                    guide = guide_legend(nrow = 1, label.position = "bottom", title.position = "top", keywidth = unit(2.4, "lines"), keyheight = unit(0.6, "lines"))) +
  coord_sf(datum = NA) +
  labs(title = "The April correction fell very unevenly on counties",
       subtitle = "This share is what the allocation carries back to earlier dates", caption = cap_early) + theme_tx_map()
save_fig(p12a / p12b + plot_layout(heights = c(1, 1.45)), "fig12_unassigned_and_correction", 8.2, 11.2)
out(ca[, .(fips, county, count_apr14, assigned_apr15, share_received_pct = 100 * odds, early_unstable, excl_county)], "fig12b_april_correction_by_county")

# ---- Figure 13: reconstructed coverage maps ----------------------------------
cb <- c(-Inf, 5, 10, 20, 30, 40, Inf); clab <- c("Under 5%", "5-10%", "10-20%", "20-30%", "30-40%", "40% or more")
m13 <- rec[as_of %in% EARLY_ASOF[2:5], .(fips, cov_H, panel = paste("Through", fmt_date(data_through)), excl_county, early_unstable)]
m13[, panel := factor(panel, levels = unique(panel))]
m13[, cls := as.character(cut(cov_H, cb, clab, right = FALSE))]
m13[excl_county == TRUE | early_unstable == TRUE, cls := "Not reconstructed"]
m13[, cls := factor(cls, levels = c(clab, "Not reconstructed"))]
p13 <- ggplot(merge(shape, m13, by = "fips")) + geom_sf(aes(fill = cls), colour = PAL$surface, linewidth = 0.1, show.legend = TRUE) +
  facet_wrap(~panel, nrow = 2) +
  scale_fill_manual(values = setNames(c(PAL$seq6, PAL$flag), levels(m13$cls)), drop = FALSE, name = NULL,
                    guide = guide_legend(nrow = 1, label.position = "bottom", keywidth = unit(2.6, "lines"), keyheight = unit(0.6, "lines"))) +
  coord_sf(datum = NA) +
  labs(title = "Reconstructed first-dose coverage of residents aged 16 and over, early 2021",
       subtitle = "Published county counts plus the allocated share of records that had no county, over the 1 July 2021 population estimate",
       caption = paste("Grey: counties whose records exceed their population later on, or whose early records were unsettled.", cap_early, sep = "\n")) +
  theme_tx_map()
save_fig(p13, "fig13_reconstructed_coverage_maps", 9.6, 10.2)
out(dcast(rec[as_of %in% c(EARLY_ASOF, base_asof)], fips + county + pop16 + excl_county + early_unstable ~ data_through, value.var = "cov_H"),
    "fig13_reconstructed_coverage")

# ---- Figure 14: uptake and spread over the whole series ----------------------
shade <- data.table(xmin = EARLY_START, xmax = base_asof)
kx <- as.Date("2021-12-20"); ky <- max(cur$county_p90, cur$pooled)
p14a <- ggplot(cur) +
  geom_rect(data = shade, aes(xmin = xmin, xmax = xmax, ymin = 0, ymax = Inf), fill = PAL$grid, alpha = 0.45) +
  geom_rect(aes(xmin = data_from, xmax = data_to + 1, ymin = county_p10, ymax = county_p90), fill = PAL$blue, alpha = 0.14) +
  geom_segment(aes(x = data_from, xend = data_to + 1, y = county_median, yend = county_median), colour = PAL$blue, linewidth = 0.9, lineend = "round") +
  geom_segment(aes(x = data_from, xend = data_to + 1, y = pooled, yend = pooled), colour = PAL$ink2, linewidth = 0.9, lineend = "round") +
  # key drawn in the empty upper right, so that no label sits on a bar
  annotate("segment", x = kx, xend = kx + 28, y = ky * 0.93, yend = ky * 0.93, colour = PAL$ink2, linewidth = 0.9, lineend = "round") +
  annotate("text", x = kx + 38, y = ky * 0.93, label = sprintf("All %d counties pooled", length(stable)), hjust = 0, family = FONT, size = 3.2, colour = PAL$ink2) +
  annotate("rect", xmin = kx, xmax = kx + 28, ymin = ky * 0.74, ymax = ky * 0.84, fill = PAL$blue, alpha = 0.14) +
  annotate("segment", x = kx, xend = kx + 28, y = ky * 0.79, yend = ky * 0.79, colour = PAL$blue, linewidth = 0.9, lineend = "round") +
  annotate("text", x = kx + 38, y = ky * 0.79, label = "Median county (modelled), with the range from\nthe 10th to the 90th percentile county", hjust = 0,
           lineheight = 1, family = FONT, size = 3.2, colour = PAL$ink2) +
  annotate("text", x = EARLY_START + 4, y = ky * 1.04, label = "Reconstructed", hjust = 0, vjust = 0, family = FONT, size = 3.1, colour = PAL$muted) +
  annotate("text", x = base_asof + 6, y = ky * 1.04, label = "Recorded", hjust = 0, vjust = 0, family = FONT, size = 3.1, colour = PAL$muted) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y", expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.09))) +
  labs(title = "Uptake among adults not yet vaccinated, per 30 days, from the first doses",
       subtitle = sprintf("Each bar spans one interval; %d counties with settled early records. Until 29 March 2021 not all adults were eligible", length(stable)),
       x = NULL, y = NULL) + theme_tx()
gll <- melt(gl, id.vars = c("as_of", "data_through"), measure.vars = c("p10", "median", "p90"))
endl <- gll[data_through == max(data_through)]
endl[, lab := c(p10 = "10th percentile county", median = "Median county", p90 = "90th percentile county")[as.character(variable)]]
p14b <- ggplot(gl) +
  geom_rect(data = shade, aes(xmin = xmin, xmax = xmax, ymin = 0, ymax = Inf), fill = PAL$grid, alpha = 0.45) +
  geom_ribbon(aes(data_through, ymin = p10, ymax = p90), fill = PAL$blue, alpha = 0.14) +
  geom_line(aes(data_through, p10), colour = PAL$blue, linewidth = 0.5) + geom_line(aes(data_through, p90), colour = PAL$blue, linewidth = 0.5) +
  geom_line(aes(data_through, median), colour = PAL$blue, linewidth = 1, lineend = "round") +
  geom_point(aes(data_through, median), colour = PAL$surface, size = 2.6) + geom_point(aes(data_through, median), colour = PAL$blue, size = 1.5) +
  geom_text(data = endl, aes(data_through + 12, value, label = lab), hjust = 0, family = FONT, size = 3.1, colour = PAL$ink2) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y", expand = expansion(mult = c(0.01, 0.2))) +
  scale_y_continuous(limits = c(0, NA), labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Most of the gap between counties opened in the first three months",
       subtitle = "First-dose coverage of residents aged 16+ across the same counties: 10th percentile, median and 90th percentile county",
       x = NULL, y = NULL, caption = cap_early) + theme_tx()
save_fig(p14a / p14b, "fig14_extended_uptake_and_spread", 8.8, 9.4)

# ---- Figure 15: associations by period, and what the allocation changes ------
plab <- c(z_age = "Share of adults aged 65+", z_income = "Median household income", z_cases = "Cases in previous 30 days")
per_lab <- c(E1 = "Dec 2020 -\nMar 2021", E2 = "Apr -\nMay 2021", P1 = "May -\nSep 2021", P2 = "Sep 2021 -\nFeb 2022", P3 = "Feb 2022 -\nMay 2023")
vlab <- c(H = "Main allocation", A = "Fixed April shares", N = "No allocation")
a15 <- pa[variant %in% names(vlab)]
a15[, `:=`(predictor_lab = factor(plab[predictor], levels = plab), period_lab = factor(per_lab[period], levels = per_lab),
           variant_lab = factor(vlab[variant], levels = vlab))]
vcol <- setNames(c(PAL$blue, PAL$orange, PAL$aqua), vlab)
pdg <- position_dodge(width = 0.55)
p15 <- ggplot(a15, aes(period_lab, hazard_ratio, colour = variant_lab, group = variant_lab)) +
  geom_hline(yintercept = 1, colour = PAL$axis, linewidth = 0.5) +
  geom_linerange(aes(ymin = lo, ymax = hi), position = pdg, linewidth = 0.7, lineend = "round") +
  geom_point(position = pdg, size = 3.2, colour = PAL$surface) + geom_point(position = pdg, size = 2.1) +
  facet_wrap(~predictor_lab, nrow = 1) +
  scale_colour_manual(values = vcol, name = "Records without a county") +
  scale_y_log10(breaks = c(0.8, 0.9, 1, 1.1, 1.2, 1.3)) +
  labs(title = "County-level associations with uptake, by period",
       subtitle = "Hazard ratio per standard deviation of each predictor, posterior median and 95% credible interval. Only the first two periods depend on the allocation",
       x = NULL, y = "Hazard ratio (1 = no association)",
       caption = "Eligibility was restricted until 29 March 2021 (65+ and people with medical conditions from late December 2020).\nThese are associations between county characteristics and county outcomes; they do not describe individuals.") +
  theme_tx() + theme(axis.text.x = element_text(size = rel(0.82), lineheight = 0.95), panel.grid.major.x = element_blank())
save_fig(p15, "fig15_associations_by_period", 11.4, 5.2)
out(pa, "fig15_associations_by_period")

# ---- Figure 16: who was ahead early and who was ahead later ------------------
r16 <- merge(ru, ca[, .(fips, elig_1b_share)], by = "fips")
r16[, age_third := cut(pct65_of_16plus, quantile(pct65_of_16plus, 0:3 / 3), include.lowest = TRUE,
                       labels = c("Youngest third of counties", "Middle third", "Oldest third (by share aged 65+)"))]
acol <- setNames(c(PAL$blue, PAL$aqua, PAL$orange), levels(r16$age_third))
brk <- c(0.25, 0.5, 1, 2, 4)
p16 <- ggplot(r16, aes(rel_early_restricted, rel_later, colour = age_third)) +
  geom_hline(yintercept = 1, colour = PAL$axis, linewidth = 0.4) + geom_vline(xintercept = 1, colour = PAL$axis, linewidth = 0.4) +
  geom_point(size = 2.5, colour = PAL$surface) + geom_point(size = 1.7, alpha = 0.85) +
  scale_colour_manual(values = acol, name = NULL, guide = guide_legend(override.aes = list(size = 2.8, alpha = 1))) +
  scale_x_log10(breaks = brk, labels = brk) + scale_y_log10(breaks = brk, labels = brk) +
  labs(title = "Being ahead while eligibility was restricted said little about later uptake",
       subtitle = "Modelled uptake relative to the average county (1 = average), log scales. Each dot is a county, coloured by age composition",
       x = "14 December 2020 to 31 March 2021", y = "25 May 2021 to 9 May 2023", caption = cap_early) + theme_tx()
save_fig(p16, "fig16_early_versus_later_uptake", 7.6, 7.2)
out(r16, "fig16_early_versus_later_uptake")
agg16 <- r16[, .(counties = .N, median_rel_early = median(rel_early_restricted), median_rel_spring = median(rel_spring_2021),
                 median_rel_later = median(rel_later), median_share_65 = median(pct65_of_16plus)), keyby = age_third]
out(agg16, "early_relative_uptake_by_age_third")
print(agg16)

# ===========================================================================
# 3. Tables and values for the write-up
# ===========================================================================
tables <- list()
add <- function(title, lines) tables[[title]] <<- lines
V <- list(final = FINAL_MODEL, n_stable = length(stable), n_kept = length(kept), n_unstable = length(setdiff(kept, stable)),
          unstable_pct_adults = sprintf("%.1f%%", 100 * ca[fips %in% setdiff(kept, stable), sum(pop16)] / ca[fips %in% kept, sum(pop16)]),
          threshold = EARLY_UNSTABLE_FALLS_PCT)

add("Eligibility for vaccination in Texas",
    md(el[, .(From = fmt_date(from), `Who could be vaccinated` = eligible,
              `DSHS population estimate` = ifelse(is.na(dshs_population_estimate), "", f0(dshs_population_estimate)),
              `Share of adults 16+` = ifelse(is.na(pct_of_dshs_16plus), "", pct0(pct_of_dshs_16plus)), Source = source)]))
add("Records without a county and the amount allocated, by boundary edition",
    md(bd[, .(`Records through` = fmt_date(data_through), `State total` = state_total, `Sum of county counts` = county_sum,
              `No county` = unassigned, `No county (% of state)` = unassigned_pct_of_state,
              `Allocated to counties` = allocated, `Allocated (% of county sum)` = allocated_pct_of_county_sum,
              `Scaling u` = scaling_u, `Largest county uplift (%)` = largest_county_uplift_pct_H)],
       digits = list(`State total` = 0, `Sum of county counts` = 0, `No county` = 0, `No county (% of state)` = 1, `Allocated to counties` = 0,
                     `Allocated (% of county sum)` = 1, `Largest county uplift (%)` = 0)))
add("Test of the allocation: growth of published county counts against the share received in April",
    md(pt[, .(Window = sprintf("%s to %s", fmt_date(from - 1), fmt_date(to - 1)), `No county at start (%)` = unassigned_pct_from,
              `No county at end (%)` = unassigned_pct_to, `Slope predicted by the assumption` = predicted_slope,
              `Estimated slope, counties weighted by size` = sprintf("%.2f (s.e. %.2f)", slope_weighted, se_weighted),
              `Estimated slope, counties weighted equally` = sprintf("%.2f (s.e. %.2f)", slope_unweighted, se_unweighted))],
       digits = list(`No county at start (%)` = 1, `No county at end (%)` = 1)))
swk <- sw[variant == "H"]
g1 <- swk[group == "all 254 counties"]; g3 <- swk[grepl("stable", group)]
add("Reconstructed first doses, coverage and uptake by early interval",
    md(data.table(Interval = g1$k, Records = g1$label, Days = g1$days, `New first doses, all counties` = g1$new_first_doses,
                  `Coverage at end, all counties (%)` = g1$cov_end, `Uptake per 30 days, all counties (%)` = g1$uptake30_pooled,
                  x1 = g3$cov_end, x2 = g3$uptake30_pooled, x3 = g3$uptake30_median_county)[
                    , setnames(.SD, c("x1", "x2", "x3"), c(sprintf("Coverage at end, %d counties (%%)", length(stable)),
                                                           sprintf("Uptake per 30 days, %d counties pooled (%%)", length(stable)),
                                                           "Uptake per 30 days, median county (%)"))],
       digits = list(Interval = 0, Days = 0, `New first doses, all counties` = 0)))
gH <- gl[, .(`Records through` = fmt_date(data_through), Source = variant, `10th percentile` = p10, Median = median, `90th percentile` = p90,
             `Gap 90th - 10th (points)` = gap_p90_p10, `Ratio 90th / 10th` = p90 / p10, `Standard deviation` = sd)]
add("Coverage across counties with settled early records, from the first doses to the end of the study",
    md(gH[gl$as_of %in% c(EARLY_ASOF, GRIDS$main[c(1, 5, 10, 13)])]))
gv <- dcast(gp[as_of <= base_asof], data_through ~ variant, value.var = "gap_p90_p10")
cw <- dcast(rec[fips %in% stable & as_of > EARLY_START], fips ~ as_of, value.var = "cov_H")
cw <- merge(cw, ed[as_of == max(GRIDS$main), .(fips, cov_end = cov16)], by = "fips")
rk <- rbindlist(lapply(as.character(c(EARLY_ASOF, base_asof)), function(dd) data.table(
  as_of = as.Date(dd), with_baseline = cor(cw[[dd]], cw[[as.character(base_asof)]], method = "spearman"),
  with_end = cor(cw[[dd]], cw$cov_end, method = "spearman"))))
out(rk, "early_rank_correlation_of_coverage")
add("Rank correlation of county coverage at early dates with coverage later",
    md(rk[, .(`Coverage through` = fmt_date(as_of - 1), `With coverage on 24 May 2021` = with_baseline, `With coverage on 9 May 2023` = with_end)]))
for (i in seq_len(nrow(rk))) { V[[sprintf("rk_base_b%d", i)]] <- f1(rk$with_baseline[i], 2); V[[sprintf("rk_end_b%d", i)]] <- f1(rk$with_end[i], 2) }
add("Gap between the 90th and 10th percentile county under each allocation (points)",
    md(gv[, .(`Records through` = fmt_date(data_through), `Main allocation (H)` = H, `Fixed April shares (A)` = A, `No allocation (N)` = N)]))
add("How much the allocation changes a county's coverage",
    md(ae[, .(`Records through` = fmt_date(data_through), `Median uplift of the county count (%)` = median_uplift_pct_H,
              `90th percentile uplift (%)` = p90_uplift_pct_H, `Largest uplift (%)` = max_uplift_pct_H,
              `Median change in coverage, H against none (points)` = median_abs_diff_points_H_vs_N,
              `Largest change, H against none (points)` = max_abs_diff_points_H_vs_N,
              `Largest change, H against fixed shares (points)` = max_abs_diff_points_H_vs_A,
              `Rank correlation of county coverage, H against none` = rank_cor_H_vs_N)],
       digits = list(`Median uplift of the county count (%)` = 1, `90th percentile uplift (%)` = 1, `Largest uplift (%)` = 0,
                     `Rank correlation of county coverage, H against none` = 3)))
ptab <- function(vs) {
  x <- pa[variant %in% vs]
  x[, est := ci(hazard_ratio, lo, hi)]
  w <- dcast(x, variant + predictor ~ period, value.var = "est", fill = "")
  w[, `:=`(o1 = match(variant, vs), o2 = match(predictor, names(plab)))]
  setorder(w, o1, o2)
  w
}
plabs <- pa[variant == "H", .(l = period_label[1]), keyby = period]
vname <- c(H = "Main allocation (H)", A = "Fixed April shares (A)", N = "No allocation (N)", HU = "H, unsettled counties kept",
           HE = "H, eligible population at risk in Jan-Feb", main = "Main analysis (no early intervals)")
wH <- ptab("H")
add("Hazard ratios per standard deviation by period, extended series",
    md(wH[, .(Predictor = plab[predictor], E1, E2, P1, P2, P3)][, setnames(.SD, c("E1", "E2", "P1", "P2", "P3"), plabs$l)]))
have <- intersect(names(vname), unique(pa$variant))
wA <- ptab(have)
add("Hazard ratios per standard deviation by period under each variant",
    md(wA[, .(Variant = vname[variant], Predictor = plab[predictor], E1, E2, P1, P2, P3)][, setnames(.SD, c("E1", "E2", "P1", "P2", "P3"), plabs$l)]))
add("Correlation of county relative uptake between periods",
    md(pc[, .(Periods = pair, Counties = counties, Correlation = correlation,
              `Interval from the uncertainty in modelled county rates` = sprintf("%.2f to %.2f", lo, hi), `Rank correlation` = rank_correlation)],
       digits = list(Counties = 0)))
add("Correlation between periods from the reconstructed counts themselves, by allocation (counties with 5,000 or more adults)",
    md(crude[, .(Allocation = sprintf("%s (%s)", allocation, variant), Counties = counties,
                 `14 Dec 2020 - 31 Mar 2021 with 1 Apr - 24 May 2021` = early_with_spring,
                 `14 Dec 2020 - 31 Mar 2021 with 25 May 2021 - 9 May 2023` = early_with_later,
                 `1 Apr - 24 May 2021 with 25 May 2021 - 9 May 2023` = spring_with_later)], digits = list(Counties = 0)))
add("Relative uptake by period and age composition (median county in each third)",
    md(agg16[, .(`Counties grouped by share aged 65+` = as.character(age_third), Counties = counties, `Median share aged 65+ (%)` = median_share_65,
                 `14 Dec 2020 - 31 Mar 2021` = median_rel_early, `1 Apr - 24 May 2021` = median_rel_spring,
                 `25 May 2021 - 9 May 2023` = median_rel_later)], digits = list(Counties = 0, `Median share aged 65+ (%)` = 1)))
add("Counties whose early records were unsettled (left out of the early intervals)",
    md(uc[, .(County = county, `Adults 16+` = pop16, `Count on 15 April 2021` = count_apr15, `Falls 16 April - 11 May (persons)` = falls_after_fix,
              `Falls as % of the 15 April count` = falls_pct_of_apr15_count,
              `Largest share of a boundary count later removed (%)` = max_boundary_removed_pct,
              `At the edition of` = { wb <- as.Date(as.character(worst_boundary)); ifelse(is.na(wb), "", fmt_date(wb)) })],
       digits = list(`Adults 16+` = 0, `Count on 15 April 2021` = 0, `Falls 16 April - 11 May (persons)` = 0, `Falls as % of the 15 April count` = 1,
                     `Largest share of a boundary count later removed (%)` = 1)))
top <- ca[fips %in% stable][order(-assigned_apr15)][1:12]
add("Counties that received the most records on 15 April 2021",
    md(top[, .(County = county, `Count published 14 April` = count_apr14, `Records received 15 April` = assigned_apr15,
               `Share of the previous count (%)` = 100 * odds)],
       digits = list(`Count published 14 April` = 0, `Records received 15 April` = 0, `Share of the previous count (%)` = 1)))
# Example counties: published against reconstructed coverage
exf <- c(Harris = "48201", Tarrant = "48439", Denton = "48121", Travis = "48453", Lubbock = "48303", Gaines = "48165")
ex <- rec[fips %in% exf & as_of %in% EARLY_ASOF]
exw <- dcast(ex, county ~ data_through, value.var = c("cov_N", "cov_H"))
add("Published and reconstructed coverage in six counties (%)",
    md(rbindlist(lapply(names(exf), function(cn) {
      z <- ex[county == cn][order(as_of)]
      data.table(County = cn, Series = c("Published", "Reconstructed (H)"),
                 rbind(as.data.table(t(setNames(z$cov_N, fmt_date(z$data_through)))), as.data.table(t(setNames(z$cov_H, fmt_date(z$data_through))))))
    })), digits = list()))

# values quoted in the text
evv <- function(p) ev[grepl(p, item, fixed = TRUE), value][1]
V$fix_assigned <- f0(as.numeric(evv("15 April: records assigned")))
V$fix_other_fall <- f0(as.numeric(evv("15 April: fall in the unassigned row")))
V$feb_high <- f0(as.numeric(ev[item == "Unassigned records, highest in February", value]))
V$feb_low <- f0(as.numeric(ev[item == "Unassigned records, lowest in late February", value]))
V$feb_high_date <- fmt_date(ev[item == "Unassigned records, highest in February (date)", value])
V$feb_low_date <- fmt_date(ev[item == "Unassigned records, lowest in late February (date)", value])
V$feb_worked_off <- f0(as.numeric(ev[item == "Unassigned records, highest in February", value]) - as.numeric(ev[item == "Unassigned records, lowest in late February", value]))
V$glitch_falls <- f0(-as.numeric(evv("24 March: sum of falls")))
V$glitch_counties <- evv("24 March: counties with a fall")
V$glitch_tarrant <- f0(-as.numeric(evv("24 March: change in Tarrant")))
V$glitch_tarrant_back <- f0(as.numeric(evv("25 March: change in Tarrant")))
V$flux_falls <- f0(-as.numeric(evv("16 April - 11 May: sum of falls")))
V$flux_counties <- evv("16 April - 11 May: counties with any fall")
V$late_falls <- f0(-as.numeric(evv("12 May - 25 May: sum of falls")))
V$resid_pct <- sprintf("%.2f%%", 100 * bd[.N, assumed_never_assigned / state_total])
V$fix_assigned_round <- f0(round(as.numeric(evv("15 April: records assigned")), -3))
V$fix_new_unassigned <- f0(round(as.numeric(evv("15 April: records assigned")) - as.numeric(evv("15 April: fall in the unassigned row")), -2))
ctw <- fread(file.path(DIR_DERIVED, "dshs_county_total.csv"), select = c("source", "as_of"))
V$n_wayback_early <- ctw[source == "wayback" & as.Date(as_of) < base_asof, uniqueN(as_of)]
V$first_daily <- fmt_date(ctw[source == "github", min(as.Date(as_of))])
for (i in seq_len(nrow(bd))) {
  V[[sprintf("other_pct_b%d", i)]] <- sprintf("%.1f%%", bd$unassigned_pct_of_state[i])
  V[[sprintf("alloc_b%d", i)]] <- f0(bd$allocated[i]); V[[sprintf("u_b%d", i)]] <- f1(bd$scaling_u[i], 2)
}
V$odds_median <- pct1(100 * median(ca[fips %in% stable, odds])); V$odds_p90 <- pct1(100 * quantile(ca[fips %in% stable, odds], 0.9))
V$odds_max <- pct0(100 * max(ca[fips %in% stable, odds])); V$odds_max_county <- ca[fips %in% stable][which.max(odds), county]
V$odds_agg <- pct1(100 * sum(ca$assigned_apr15) / sum(ca$count_apr14))
V$n_neg_R <- ca[assigned_apr15 < 0, .N]
oc <- function(cn) pct0(100 * ca[county == cn, odds])
V$odds_harris <- oc("Harris"); V$odds_tarrant <- oc("Tarrant"); V$odds_denton <- oc("Denton")
V$pt_cor_w <- f1(cor(pt$predicted_slope, pt$slope_weighted), 2); V$pt_cor_u <- f1(cor(pt$predicted_slope, pt$slope_unweighted), 2)
V$pt_n <- nrow(pt)
febw <- pt[from == as.Date("2021-02-12")]
V$pt_feb_pred <- f1(febw$predicted_slope, 2); V$pt_feb_est <- sprintf("%.2f (standard error %.2f)", febw$slope_weighted, febw$se_weighted)
for (i in seq_len(nrow(g1))) {
  V[[sprintf("cov_all_k%d", i)]] <- f1(g1$cov_end[i]); V[[sprintf("up_all_k%d", i)]] <- f1(g1$uptake30_pooled[i])
  V[[sprintf("cov_st_k%d", i)]] <- f1(g3$cov_end[i]); V[[sprintf("up_st_k%d", i)]] <- f1(g3$uptake30_pooled[i])
  V[[sprintf("med_st_k%d", i)]] <- f1(cur[k == i, county_median]); V[[sprintf("p10_st_k%d", i)]] <- f1(cur[k == i, county_p10])
  V[[sprintf("p90_st_k%d", i)]] <- f1(cur[k == i, county_p90])
}
gHe <- gp[variant == "H"][order(as_of)]
for (i in seq_len(nrow(gHe))) {
  V[[sprintf("gap_b%d", i)]] <- f1(gHe$gap_p90_p10[i]); V[[sprintf("p10_b%d", i)]] <- f1(gHe$p10[i]); V[[sprintf("p90_b%d", i)]] <- f1(gHe$p90[i])
  V[[sprintf("med_b%d", i)]] <- f1(gHe$median[i]); V[[sprintf("ratio_b%d", i)]] <- f1(gHe$ratio_p90_p10[i])
}
V$gap_share_feb <- pct0(100 * gHe$gap_p90_p10[3] / gHe$gap_p90_p10[6]); V$gap_share_mar <- pct0(100 * gHe$gap_p90_p10[4] / gHe$gap_p90_p10[6])
V$gap_end <- f1(gl[.N, gap_p90_p10]); V$gap_base <- f1(gHe$gap_p90_p10[6])
V$gap_share_feb_end <- pct0(100 * gHe$gap_p90_p10[3] / gl[.N, gap_p90_p10])
V$gap_added_later <- f1(gl[.N, gap_p90_p10] - gHe$gap_p90_p10[6])
for (i in seq_len(nrow(pc))) V[[sprintf("pc_point_%d", i)]] <- f1(pc$correlation[i], 2)
gN <- gp[variant == "N"][order(as_of)]; gA <- gp[variant == "A"][order(as_of)]
V$gap_maxdiff_N <- f1(max(abs(gN$gap_p90_p10 - gHe$gap_p90_p10)), 1); V$gap_maxdiff_A <- f1(max(abs(gA$gap_p90_p10 - gHe$gap_p90_p10)), 1)
V$ae_med_max <- f1(max(ae$median_abs_diff_points_H_vs_N), 1); V$ae_max <- f1(max(ae$max_abs_diff_points_H_vs_N), 1)
V$ae_max_A <- f1(max(ae$max_abs_diff_points_H_vs_A), 1); V$ae_rank_min <- f1(min(ae$rank_cor_H_vs_N), 2)
V$ae_uplift_med <- sprintf("%.0f%% to %.0f%%", min(ae$median_uplift_pct_H), max(ae$median_uplift_pct_H))
V$ae_uplift_max <- pct0(max(ae$max_uplift_pct_H))
hr <- function(v, pr, pe) pa[variant == v & predictor == pr & period == pe, ci(hazard_ratio, lo, hi)]
for (v in unique(pa$variant)) for (pr in names(plab)) for (pe in unique(pa[variant == v, period])) {
  V[[sprintf("hr_%s_%s_%s", v, sub("z_", "", pr), pe)]] <- hr(v, pr, pe)
}
rng <- function(pr, pe, vs = c("H", "A", "N")) { x <- pa[variant %in% vs & predictor == pr & period == pe, hazard_ratio]; sprintf("%.2f to %.2f", min(x), max(x)) }
for (pr in names(plab)) for (pe in c("E1", "E2")) V[[sprintf("rng_%s_%s", sub("z_", "", pr), pe)]] <- rng(pr, pe)
lt <- merge(pa[variant == "H" & period %in% c("P1", "P2", "P3"), .(predictor, period, h = hazard_ratio)],
            pa[variant == "main", .(predictor, period, m = hazard_ratio)], by = c("predictor", "period"))
V$later_maxdiff <- f1(max(abs(lt$h - lt$m)), 2)
V$elig_1a <- f1(el$dshs_population_estimate[1] / 1e6, 1); V$elig_1b <- f1(el$dshs_population_estimate[2] / 1e6, 1)
V$elig_1a_pct <- pct0(el$pct_of_dshs_16plus[1]); V$elig_1b_pct <- pct0(el$pct_of_dshs_16plus[2])
V$elig_1b_med <- pct0(100 * median(ca$elig_1b_share)); V$elig_1b_min <- pct0(100 * min(ca$elig_1b_share)); V$elig_1b_max <- pct0(100 * max(ca$elig_1b_share))
for (i in seq_len(nrow(pc))) { V[[sprintf("pc_%d", i)]] <- ci(pc$correlation[i], pc$lo[i], pc$hi[i]); V[[sprintf("pc_rank_%d", i)]] <- f1(pc$rank_correlation[i], 2) }
sp <- function(col) { q <- quantile(ru[[col]], c(.1, .9)); c(f1(q[1], 2), f1(q[2], 2), f1(q[2] / q[1], 1)) }
for (g in c("early_restricted", "spring_2021", "later")) { s <- sp(paste0("rel_", g)); V[[paste0("rel_p10_", g)]] <- s[1]; V[[paste0("rel_p90_", g)]] <- s[2]; V[[paste0("rel_fold_", g)]] <- s[3] }
for (i in seq_len(nrow(agg16))) for (g in c("early", "spring", "later")) V[[sprintf("age3_%d_%s", i, g)]] <- f1(agg16[[paste0("median_rel_", g)]][i], 2)
V$n_ci <- f0(mp[variant == "H", county_intervals]); V$n_ci_early <- f0(mp[variant == "H", early_county_intervals])
V$fit_seconds <- f0(mp[variant == "H", seconds])
mdl <- mu[fips %in% stable & usable == TRUE]
V$mod_vs_rec_med <- f1(median(abs(mdl$modelled_uptake30_pct - mdl$reconstructed_uptake30_pct)), 2)
V$mod_vs_rec_small <- f1(mdl[pop16 < 5000, median(abs(modelled_uptake30_pct - reconstructed_uptake30_pct))], 2)
fwrite(data.table(name = names(V), value = vapply(V, function(x) as.character(x)[1], character(1))), file.path(DIR_TAB, "early_report_values.csv"))
tl <- character(); for (n in names(tables)) tl <- c(tl, "", paste0("### ", n), "", tables[[n]])
writeLines(tl, file.path(DIR_TAB, "early_report_tables.md"))
if (file.exists("docs/03_early_rollout_template.md")) fill_template("docs/03_early_rollout_template.md", "docs/03_early_rollout.md", tables, V)
msg("Done.")
