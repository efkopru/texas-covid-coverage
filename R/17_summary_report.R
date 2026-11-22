# 17_summary_report.R -- the short summary report.
#
#   Rscript --vanilla R/17_summary_report.R
#
# Fills docs/00_summary_template.md -> docs/00_summary.md. The values come from
#   outputs/tables/report_values.csv         {{v:key}}     written by step 10
#   outputs/tables/early_report_values.csv   {{v:x_key}}   written by step 15
# and a few descriptive figures computed here from the result tables ({{v:s_key}}),
# so the summary cannot drift from the reports. Run step 11 afterwards for the
# HTML copy.

source("R/_common.R")
source("R/_report.R")

v1 <- rd("report_values.csv"); v2 <- rd("early_report_values.csv")
V <- c(as.list(setNames(v1$value, v1$name)), as.list(setNames(v2$value, paste0("x_", v2$name))))

# ---------------------------------------------------------------------------
# Recorded coverage at the baseline and at the end of the study
# ---------------------------------------------------------------------------
# the modelled counties: first and last row of the table behind figure 4
g4 <- rd("fig04_gap_over_time.csv")
gb <- g4[1]; ge <- g4[.N]
stopifnot(as.character(gb$data_through) == "2021-05-24", as.character(ge$data_through) == "2023-05-09",
          gb$counties == ge$counties)
# statewide, all counties: the same sum as on the interactive site
ed <- fread(file.path(DIR_DERIVED, "coverage_editions.csv"), colClasses = list(character = "fips"))
ed[, as_of := as.Date(as_of)]
st <- ed[as_of %in% range(GRIDS$main), .(cov = 100 * sum(n16) / sum(pop16_2021), n = .N), keyby = as_of]
ct <- rd("county_results.csv", colClasses = list(character = "fips"))
kept <- ct[excl_county == FALSE]
stopifnot(nrow(st) == 2, all(st$n == nrow(ct)), nrow(kept) == as.integer(V$n_kept), nrow(kept) == gb$counties)

V$s_n_counties  <- nrow(ct)
V$s_n_excl      <- ct[excl_county == TRUE, .N]
V$s_excl_adults <- f1(100 * ct[excl_county == TRUE, sum(pop16)] / ct[, sum(pop16)])
V$s_state_base  <- f1(st$cov[1]); V$s_state_end <- f1(st$cov[2])
V$s_med_base    <- f1(gb$median); V$s_med_end   <- f1(ge$median)
V$s_gap_base    <- f1(gb$gap_p90_p10); V$s_gap_end <- f1(ge$gap_p90_p10)
V$s_rank        <- sprintf("%.2f", cor(kept$cov_baseline, kept$cov_end, method = "spearman"))
V$built         <- sub("^0", "", format(Sys.Date(), "%d %B %Y"))
# the baseline is also the last date of the early-rollout extension: the two must agree
stopifnot(V$s_state_base == V$x_cov_all_k6)

key <- data.table(
  ` ` = c(sprintf("Statewide (all %d counties)", nrow(ct)), sprintf("The %d modelled counties together", nrow(kept)),
          "Median county", "10th-percentile county", "90th-percentile county",
          "Gap between the 90th- and 10th-percentile county (points)", "Standard deviation across counties (points)"),
  `24 May 2021` = c(pct1(st$cov[1]), pct1(gb$pooled), pct1(gb$median), pct1(gb$p10), pct1(gb$p90), f1(gb$gap_p90_p10), f1(gb$sd)),
  `9 May 2023`  = c(pct1(st$cov[2]), pct1(ge$pooled), pct1(ge$median), pct1(ge$p10), pct1(ge$p90), f1(ge$gap_p90_p10), f1(ge$sd)))
msg("Statewide %s%% -> %s%%; median county %s%% -> %s%%; gap %s -> %s points; rank correlation %s; %d counties (%s%% of adults) not modelled",
    V$s_state_base, V$s_state_end, V$s_med_base, V$s_med_end, V$s_gap_base, V$s_gap_end, V$s_rank, V$s_n_excl, V$s_excl_adults)

fill_template("docs/00_summary_template.md", "docs/00_summary.md", list("Key numbers" = md(key)), V)
msg("Done.")
