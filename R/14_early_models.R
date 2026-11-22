# 14_early_models.R -- the uptake model on the extended series, 14 December 2020
# to 9 May 2023 (six reconstructed early intervals followed by the twelve main
# ones), with predictor associations allowed to differ between periods.
#
#   Rscript --vanilla R/14_early_models.R [variants]      e.g.  H   or  A,N
#
# Variants (each is one refit of the selected uptake model):
#   H   main allocation of the records that had no county (see R/13)
#   A   allocation by fixed April shares
#   N   no allocation: counts as published
#   HU  as H, but keeping the counties whose early records were unsettled
#   HE  as H, but in January and February 2021 the population at risk is the
#       population DSHS estimated to be eligible (Phase 1A and 1B), not all adults
# With no argument all five are fitted. Each variant's results are stored on
# their own and the combined tables are rebuilt from every variant present, so
# variants can be run in separate terminals; finish with
#   Rscript --vanilla R/14_early_models.R tables
# to rebuild the combined tables once every variant is in.
#
# Periods for the predictor associations
#   E1  14 Dec 2020 - 31 Mar 2021   eligibility restricted (intervals 1-4)
#   E2   1 Apr 2021 - 24 May 2021   all adults eligible (5-6); 29-31 March fall in E1
#   P1-P3  the three periods of the main analysis (7-10, 11-15, 16-18)
#
# Outputs
#   outputs/models/ext_summary_<variant>.rds, samples_ext_H.rds
#   outputs/tables/early_period_associations.csv, early_model_parameters.csv,
#   early_modelled_uptake.csv, early_relative_uptake_by_period.csv

source("R/_common.R")
source("R/_models.R")
options(width = 220, scipen = 999)
M <- FINAL_MODEL
N_DRAWS <- 1000
W <- build_graph()
VARIANTS <- c(H = "Main allocation (H)", A = "Allocation by fixed April shares (A)", N = "No allocation: counts as published (N)",
              HU = "Main allocation, counties with unsettled early records kept",
              HE = "Main allocation, January-February at risk = population eligible under Phases 1A and 1B")
args <- commandArgs(trailingOnly = TRUE)
# "tables" as the argument fits nothing and only rebuilds the combined tables
todo <- if (length(args)) setdiff(strsplit(args[1], ",")[[1]], "tables") else names(VARIANTS)
stopifnot(all(todo %in% names(VARIANTS)))
periods <- list(E1 = 1:4, E2 = 5:6, P1 = 7:10, P2 = 11:15, P3 = 16:18)
preds <- c("z_age", "z_income", "z_cases")

prep <- function(v) {
  d <- load_panel(sprintf("panel_ext_%s.csv", substr(v, 1, 1)))
  y <- d$y_model
  if (v == "HU") {            # keep the unsettled counties: same row rules as everywhere else
    ok <- !d$excl_county & d$cov_start < COVERAGE_CEILING & d$y <= d$at_risk
    y <- ifelse(ok, pmax(d$y, 0), NA_real_)
  }
  if (v == "HE") {            # eligible population at risk in the two intervals when eligibility did not change
    e <- d$k %in% 2:3
    ar <- round(d$pop16 * d$elig_1b_share) - d$cum_start
    bad <- e & (ar <= 0 | d$y > ar)
    set(d, i = which(e), j = "at_risk", value = pmax(ar[e], 1))
    y[bad] <- NA_real_
  }
  pv <- character()
  for (p in names(periods)) for (x in preds) {
    nm <- paste0(x, "_", p)
    set(d, j = nm, value = ifelse(d$k %in% periods[[p]], d[[x]], 0))
    pv <- c(pv, nm)
  }
  list(d = d, y = y, pv = pv)
}

for (v in todo) {
  msg("Variant %s: %s", v, VARIANTS[[v]])
  z <- prep(v); d <- z$d; y <- z$y
  msg("  rows in the likelihood: %d (early %d, later %d); counties: %d", sum(!is.na(y)), sum(!is.na(y) & d$early), sum(!is.na(y) & !d$early),
      uniqueN(d$fips[!is.na(y)]))
  t0 <- Sys.time()
  r <- fit_model(d, M, W, y = y, covars = z$pv, compute_scores = FALSE)
  msg("  fitted in %.0f s", as.numeric(difftime(Sys.time(), t0, units = "secs")))
  iv <- unique(d[, .(k, data_from, data_to)])
  fx <- fixed_table(r)[term %in% z$pv]
  fx[, `:=`(period = sub(".*_", "", term), predictor = sub("_[EP][0-9]$", "", term))]
  fx[, period_label := sapply(period, function(p) sprintf("%s to %s", format(min(iv[k %in% periods[[p]], data_from]), "%d %b %Y"),
                                                         format(max(iv[k %in% periods[[p]], data_to]), "%d %b %Y")))]
  summ <- list(variant = v, label = VARIANTS[[v]],
               fixed = fx[, .(variant = v, period, period_label, predictor, log_hr = median, log_hr_lo = q025, log_hr_hi = q975,
                              hazard_ratio = exp(median), lo = exp(q025), hi = exp(q975))],
               hyper = cbind(variant = v, hyper_table(r)),
               counts = data.table(variant = v, label = VARIANTS[[v]], counties = uniqueN(d$fips[!is.na(y)]), county_intervals = sum(!is.na(y)),
                                   early_county_intervals = sum(!is.na(y) & d$early), seconds = as.numeric(r$cpu.used[["Total"]])))
  saveRDS(summ, file.path(DIR_MOD, sprintf("ext_summary_%s.rds", v)))
  print(dcast(summ$fixed, predictor ~ period, value.var = "hazard_ratio")[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 3) else x)])
  if (v == "H") {
    sel <- list(Predictor = 1:nrow(d), oid = 1:nrow(d))
    for (nm in rownames(r$summary.fixed)) sel[[nm]] <- 1
    s <- inla.posterior.sample(N_DRAWS, r, selection = sel, seed = 20211022L, num.threads = "1:1")
    rn <- rownames(s[[1]]$latent)
    L <- vapply(s, function(q) q$latent[, 1], numeric(length(rn)))
    draws <- list(variant = v, panel_key = d[, .(fips, k)], eta = L[grepl("^Predictor:", rn), , drop = FALSE],
                  eps = L[grepl("^oid:", rn), , drop = FALSE],
                  fixed = L[rn %in% paste0(rownames(r$summary.fixed), ":1"), , drop = FALSE],
                  fixed_names = sub(":1$", "", rn[rn %in% paste0(rownames(r$summary.fixed), ":1")]),
                  hyper = vapply(s, function(q) q$hyperpar, numeric(length(s[[1]]$hyperpar))), hyper_names = names(s[[1]]$hyperpar))
    stopifnot(nrow(draws$eta) == nrow(d))
    saveRDS(draws, file.path(DIR_MOD, "samples_ext_H.rds"), compress = "xz")
    rm(s, L, draws)
  }
  rm(r); gc()
}

# ---------------------------------------------------------------------------
# Combined tables from every variant fitted so far
# ---------------------------------------------------------------------------
done <- intersect(names(VARIANTS), sub("^ext_summary_(.*)[.]rds$", "\\1", list.files(DIR_MOD, pattern = "^ext_summary_.*[.]rds$")))
summ <- lapply(done, function(v) readRDS(file.path(DIR_MOD, sprintf("ext_summary_%s.rds", v))))
pa <- rbindlist(lapply(summ, `[[`, "fixed"))
# the main analysis's own period-specific estimates, for comparison in P1-P3
mp <- fread(file.path(DIR_TAB, "period_specific_associations.csv"))
pa <- rbind(pa, mp[, .(variant = "main", period, period_label, predictor, log_hr = log(hazard_ratio), log_hr_lo = log(lo), log_hr_hi = log(hi),
                       hazard_ratio, lo, hi)])
fwrite(pa, file.path(DIR_TAB, "early_period_associations.csv"))
hy <- rbindlist(lapply(summ, `[[`, "hyper"))
cn <- rbindlist(lapply(summ, `[[`, "counts"))
fwrite(merge(cn, dcast(hy, variant ~ parameter, value.var = "median"), by = "variant"), file.path(DIR_TAB, "early_model_parameters.csv"))
msg("Variants available: %s", paste(done, collapse = ", "))
print(dcast(pa[, .(variant, predictor, period, est = sprintf("%.2f (%.2f-%.2f)", hazard_ratio, lo, hi))], variant + predictor ~ period, value.var = "est"))

# ---------------------------------------------------------------------------
# Modelled quantities from the main extension fit (variant H)
# ---------------------------------------------------------------------------
if (file.exists(file.path(DIR_MOD, "samples_ext_H.rds"))) {
  d <- load_panel("panel_ext_H.csv")
  dr <- readRDS(file.path(DIR_MOD, "samples_ext_H.rds"))
  stopifnot(identical(dr$panel_key$fips, d$fips), identical(dr$panel_key$k, d$k))
  qs <- function(m, p = c(0.025, 0.5, 0.975)) t(apply(m, 1, quantile, probs = p, names = FALSE))
  logh <- dr$eta - d$off
  q1 <- qs(100 * cloglog_inv(logh))
  mu <- d[, .(fips, county, k, label, days, early, pop16, at_risk, new_first_doses = y, usable, exclude, alloc_start, alloc_end,
              cov_start, cov_end, reconstructed_uptake30_pct = 100 * uptake30)]
  mu[, `:=`(modelled_uptake30_pct = q1[, 2], modelled_lo = q1[, 1], modelled_hi = q1[, 3])]
  mu[d$excl_county, c("modelled_uptake30_pct", "modelled_lo", "modelled_hi") := NA_real_]
  # a county whose early rows are not in the likelihood still has a modelled value there, driven by its later intervals,
  # its neighbours and its predictors; flag those so that they are not mistaken for reconstructed uptake
  mu[, informed_by_own_count := usable]
  fwrite(mu[early == TRUE], file.path(DIR_TAB, "early_modelled_uptake.csv"))

  # Relative uptake by period: the county's log hazard minus the mean of the
  # counties with stable early records, averaged over the intervals of the period.
  ca <- fread(file.path(DIR_DERIVED, "early_county_allocation.csv"), colClasses = list(character = "fips"))
  stable <- ca[excl_county == FALSE & early_unstable == FALSE, sort(fips)]
  n_t <- d[, max(k)]
  idx <- matrix(NA_integer_, length(stable), n_t)
  idx[cbind(match(d$fips[d$fips %in% stable], stable), d$k[d$fips %in% stable])] <- which(d$fips %in% stable)
  grp <- list(early_restricted = periods$E1, spring_2021 = periods$E2, later = unlist(periods[c("P1", "P2", "P3")]))
  dev <- lapply(grp, function(ks) {
    a <- 0
    for (kk in ks) { lk <- logh[idx[, kk], ]; a <- a + sweep(lk, 2, colMeans(lk)) }
    a / length(ks)
  })
  ru <- data.table(fips = stable)
  for (g in names(dev)) { q <- qs(exp(dev[[g]])); ru[, paste0("rel_", g, c("", "_lo", "_hi")) := list(q[, 2], q[, 1], q[, 3])] }
  ru <- merge(unique(d[, .(fips, county, pop16, pct65_of_16plus, med_hh_income)]), ru, by = "fips")
  fwrite(ru, file.path(DIR_TAB, "early_relative_uptake_by_period.csv"))
  cr <- function(a, b) { x <- sapply(seq_len(ncol(dev[[a]])), function(j) cor(dev[[a]][, j], dev[[b]][, j])); c(median(x), quantile(x, c(.025, .975), names = FALSE)) }
  sp <- function(a, b) cor(apply(dev[[a]], 1, median), apply(dev[[b]], 1, median), method = "spearman")
  pc <- rbindlist(list(
    data.table(pair = "14 Dec 2020 - 31 Mar 2021 with 1 Apr - 24 May 2021", t(cr("early_restricted", "spring_2021")), rank = sp("early_restricted", "spring_2021")),
    data.table(pair = "14 Dec 2020 - 31 Mar 2021 with 25 May 2021 - 9 May 2023", t(cr("early_restricted", "later")), rank = sp("early_restricted", "later")),
    data.table(pair = "1 Apr - 24 May 2021 with 25 May 2021 - 9 May 2023", t(cr("spring_2021", "later")), rank = sp("spring_2021", "later"))))
  setnames(pc, c("pair", "correlation", "lo", "hi", "rank_correlation"))
  pc[, counties := length(stable)]
  fwrite(pc, file.path(DIR_TAB, "early_period_correlations.csv"))
  cat("\nCorrelation of county relative uptake between periods (log scale):\n"); print(pc)
  sp10 <- function(g) { q <- quantile(ru[[paste0("rel_", g)]], c(.1, .9)); sprintf("%.2f to %.2f (%.1f-fold)", q[1], q[2], q[2] / q[1]) }
  for (g in names(grp)) msg("Relative uptake, %s: 10th to 90th percentile county %s", g, sp10(g))
}
msg("Done: %s", paste(todo, collapse = ", "))
