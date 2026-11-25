# 18_rerun_check.R -- how closely do the modelled results repeat when the models are fitted again?
#
#   Rscript --vanilla R/18_rerun_check.R              every model: steps 6, 7, 9 and 14, about 45 minutes
#   Rscript --vanilla R/18_rerun_check.R quick        without the out-of-sample experiments of step 7: about 10 minutes
#   Rscript --vanilla R/18_rerun_check.R summary      recount rerun_summary.csv from the stored tables; fits nothing
#   Rscript --vanilla R/18_rerun_check.R <folder> [quick]   compare with an existing second copy instead of making one
#
# R-INLA does not return exactly the same fit twice, and the posterior draws then come out as a
# different sample even though their seed is fixed. This script measures how much that matters:
#   1. it copies the code, the derived data and the stored tables to a temporary folder,
#   2. refits the models there (steps 6, 9 and 14 side by side, then the four experiments of step 7 side by
#      side) and rebuilds what depends on the fits (step 8, the tables of step 14, steps 15 and 10),
#   3. compares each regenerated table with the one in this folder, and
#   4. fits one model four times: twice with the pipeline's threads and twice with a single thread.
# Nothing in this folder changes except the four tables it writes to outputs/tables/:
#   rerun_differences.csv      size of the differences, quantity by quantity
#   rerun_changed_values.csv   values quoted in the documents that came out differently
#   rerun_repeat_fit.csv       one model fitted four times
#   rerun_validation_verdicts.csv   with "full": per experiment, how many comparisons between models keep their verdict
#   rerun_summary.csv          the figures and sentences quoted in the README and the documents ({{v:rr_key}})
# With "quick" the out-of-sample experiments are not fitted again. The values that the documents quote from
# them then cannot differ and are reported as not compared. Because that says less than a full run, "quick"
# does not replace the stored tables of a full run unless "force" is added.

source("R/_common.R")
source("R/_models.R")
source("R/_report.R")

args <- commandArgs(trailingOnly = TRUE)
mode <- if (!length(args)) "full" else if (args[1] %in% c("quick", "summary")) args[1] else "folder"
if (mode == "quick" && !("force" %in% args) && file.exists(file.path(DIR_TAB, "rerun_summary.csv"))) {
  prev <- fread(file.path(DIR_TAB, "rerun_summary.csv"), colClasses = "character")
  if (identical(prev[name == "validation_refitted", value], "yes"))
    stop("The stored tables come from a full run. A quick run would replace them with less; add \"force\" to do that anyway.")
}
t_start <- Sys.time()
rscript <- file.path(R.home("bin"), "Rscript")
# the copy has no package library of its own: its R processes use this session's
Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))

# the values that steps 10 and 15 fill into the documents
quoted <- function(dir) rbind(fread(file.path(dir, DIR_TAB, "report_values.csv"), colClasses = "character")[, document := "main report"],
                              fread(file.path(dir, DIR_TAB, "early_report_values.csv"), colClasses = "character")[, document := "early rollout"])
# run times are not results
is_run_time <- function(name) grepl("^secs_|^fit_seconds$", name)
# scores, paired differences and held-out predictions of the out-of-sample experiments (R/10_report_tables.R takes
# them from the tables of step 7)
from_validation <- function(document, name) document == "main report" &
  grepl("^(crps|cov|cov1|end|cor|width|worse|impr|endin|ls|d_crps|d_ls|d_end|bias|ho)_", name)
write_summary <- function(S) fwrite(data.table(name = names(S), value = vapply(S, as.character, "")), file.path(DIR_TAB, "rerun_summary.csv"))

# how far apart two printed values are, in units of the last printed digit: 4.29 against 4.33 is 4 units, 136 against 138 is 2
nums <- function(s) regmatches(s, gregexpr("-?[0-9]+([.][0-9]+)?", s))[[1]]
units <- function(a, b) {
  x <- nums(a); y <- nums(b)
  if (!length(x) || length(x) != length(y)) return(NA_real_)
  decimals <- nchar(sub("^[^.]*[.]?", "", x))
  round(max(abs(as.numeric(x) - as.numeric(y)) * 10^decimals))
}
# what a printed difference between two models says: "estimate (low to high)" lies below zero, above zero, or includes it
verdict <- function(s) {
  m <- regmatches(s, regexec("^(-?[0-9.]+) [(](-?[0-9.]+) to (-?[0-9.]+)[)]$", s))[[1]]
  if (length(m) != 4) return(NA_character_)
  if (as.numeric(m[4]) < 0) "below zero" else if (as.numeric(m[3]) > 0) "above zero" else "includes zero"
}
# Everything that is derived from the quoted values. allq: document, name, value_published, value_rerun (no run times).
# Values from the out-of-sample experiments are always counted apart from the others.
value_results <- function(allq, validation_refitted, crps_max, crps_rel_max, run_date) {
  allq <- copy(allq)[, validation := from_validation(document, name)]
  if (!validation_refitted) stopifnot(allq[validation == TRUE & value_published != value_rerun, .N] == 0)
  changed <- allq[value_published != value_rerun, .(document, value = name, published = value_published, rerun = value_rerun,
                                                    from_out_of_sample_experiments = validation)]
  changed[, units_of_last_digit := if (.N) mapply(units, published, rerun) else numeric()]
  dd <- allq[document == "main report" & grepl("^d_(crps|ls|end)_", name)]
  dd[, experiment := sub("^d_(crps|ls|end)_([A-Z0-9]+)_.*$", "\\2", name)]
  dd[, `:=`(published = vapply(value_published, verdict, ""), rerun = vapply(value_rerun, verdict, ""))]
  dd <- dd[!is.na(published) & !is.na(rerun)]
  ver <- dd[, .(comparisons = .N, same_verdict = sum(published == rerun), different_verdict = sum(published != rerun)), by = experiment]
  cm <- changed[from_out_of_sample_experiments == FALSE]; cv <- changed[from_out_of_sample_experiments == TRUE]
  nv <- allq[validation == TRUE, .N]
  rerun_of <- function(key) allq[document == "main report" & name == key, value_rerun]
  E <- list(validation_refitted = if (validation_refitted) "yes" else "no",
            n_values = allq[validation == FALSE, .N], n_changed = nrow(cm),
            n_changed_main = cm[document == "main report", .N], n_changed_early = cm[document == "early rollout", .N],
            units_max = if (nrow(cm)) max(cm$units_of_last_digit, na.rm = TRUE) else 0,
            n_validation = nv, n_changed_validation = if (validation_refitted) nrow(cv) else "not compared",
            crps_max = crps_max, crps_rel_max = crps_rel_max,
            verdict_n_abc = if (validation_refitted) ver[experiment != "D", sum(comparisons)] else "not compared",
            verdict_changed_abc = if (validation_refitted) ver[experiment != "D", sum(different_verdict)] else "not compared",
            verdict_n_d = if (validation_refitted) ver[experiment == "D", sum(comparisons)] else "not compared",
            verdict_changed_d = if (validation_refitted) ver[experiment == "D", sum(different_verdict)] else "not compared",
            d_D_M3_M4_rerun = if (validation_refitted) rerun_of("d_crps_D_M3_M4") else "not run again",
            d_C1_M3_M4_rerun = if (validation_refitted) rerun_of("d_crps_C1_M3_M4") else "not run again")
  # one sentence on the out-of-sample experiments for the limitations of the main report, one for the shorter texts,
  # and one for section 4.2 of the main report
  if (validation_refitted) {
    E$note_report <- sprintf(paste("The out-of-sample experiments of section 4.2 were run again as well. Of the %d values quoted from them, %d came out",
                                   "differently: the mean scores (CRPS) changed by at most %s points, or %s%%, and section 4.2 says which",
                                   "comparisons between models held."), nv, nrow(cv), crps_max, crps_rel_max)
    E$note_short <- sprintf(paste("The prediction checks were run again as well: their mean scores changed by at most %s%%, but which model",
                                  "forecast the next interval better did not repeat."), crps_rel_max)
    E$note_validation <- sprintf(paste("**How far these comparisons repeat.** All four experiments were run again on %s (section 7). The mean CRPS",
                                       "of a model in an experiment changed by at most %s points, or %s%%. In experiments A, B and C, %d of the %d",
                                       "differences between models in the table above gave the same verdict as before (interval below zero, above",
                                       "zero, or including it). In experiment D only %d of %d did, so no ranking of the models should be read from",
                                       "experiment D."),
                                 run_date, crps_max, crps_rel_max, E$verdict_n_abc - E$verdict_changed_abc, E$verdict_n_abc,
                                 E$verdict_n_d - E$verdict_changed_d, E$verdict_n_d)
  } else {
    E$note_report <- sprintf("The out-of-sample experiments of section 4.2 were not run again, so the %d values quoted from them are not part of this comparison.", nv)
    E$note_short <- "The prediction checks were not run again, so their scores were not compared."
    E$note_validation <- "**How far these comparisons repeat.** The experiments have not been run a second time, so this is not known (section 7)."
  }
  list(changed = changed, verdicts = ver, entries = E)
}
write_value_tables <- function(vr, validation_refitted) {
  fwrite(vr$changed, file.path(DIR_TAB, "rerun_changed_values.csv"))
  f <- file.path(DIR_TAB, "rerun_validation_verdicts.csv")
  if (validation_refitted) fwrite(vr$verdicts, f) else unlink(f)
}

if (mode == "summary") {
  f <- file.path(DIR_TAB, "rerun_summary.csv")
  if (!file.exists(f)) stop("Nothing to recount: run this script without arguments first")
  s0 <- fread(f, colClasses = "character")
  S <- as.list(setNames(s0$value, s0$name))
  # the values as printed in the rerun: the stored list of changed values, and the published value for the rest
  allq <- quoted(".")[!is_run_time(name)]
  setnames(allq, "value", "value_published")
  ch <- fread(file.path(DIR_TAB, "rerun_changed_values.csv"), colClasses = "character")
  allq[, value_rerun := value_published]
  allq[ch, on = .(document, name = value), value_rerun := i.rerun]
  refitted <- identical(S$validation_refitted, "yes")
  vr <- value_results(allq, refitted, S$crps_max, S$crps_rel_max, S$date)
  stopifnot(nrow(vr$changed) == nrow(ch))
  S[names(vr$entries)] <- vr$entries
  write_value_tables(vr, refitted)
  write_summary(S)
  msg("Recounted: %s of %s values changed; from the out-of-sample experiments: %s of %s",
      S$n_changed, S$n_values, S$n_changed_validation, S$n_validation)
  quit(save = "no")
}

# ---------------------------------------------------------------------------
# 1 and 2. A second copy with the models fitted again
# ---------------------------------------------------------------------------
if (mode == "folder") {
  copy <- normalizePath(args[1], winslash = "/", mustWork = TRUE)
  validation_refitted <- !(length(args) > 1 && args[2] == "quick")
  msg("Comparing with the existing copy %s", copy)
} else {
  validation_refitted <- mode == "full"
  # beside this session's own temporary folder, not inside it, so that the copy survives if this script stops
  # with an error: its fits can then be completed by hand and compared with "<folder> [full]"
  copy <- file.path(dirname(tempdir()), "txcov_rerun")
  unlink(copy, recursive = TRUE)
  for (d in c("R", "docs", "data/derived", "outputs/tables", "outputs/models")) {
    dir.create(file.path(copy, d), recursive = TRUE)
    f <- list.files(d, full.names = TRUE)
    f <- f[!dir.exists(f) & !grepl("^samples_.*[.]rds$", basename(f)) & !grepl("[.](html|pdf)$", f)]
    stopifnot(all(file.copy(f, file.path(copy, d), copy.date = TRUE)))
  }
  if (validation_refitted) {
    # the held-out-regions experiment reads the public health regions from the last DSHS workbook
    wb <- file.path(DIR_RAW, "dshs_vax_wayback/workbooks",
                    fread(file.path(DIR_DERIVED, "dshs_workbook_index.csv"))[as.Date(as_of) == max(as.Date(as_of)), file])
    dir.create(file.path(copy, dirname(wb)), recursive = TRUE)
    stopifnot(file.copy(wb, file.path(copy, wb)))
  }
  msg("Copied code, derived data and stored tables to a temporary folder (%.0f MB)",
      sum(file.size(list.files(copy, recursive = TRUE, full.names = TRUE))) / 1e6)

  # a small wrapper so that several steps can run side by side and report when they end
  writeLines(c('a <- commandArgs(trailingOnly = TRUE)',
               'b <- gsub("[^A-Za-z0-9]+", "_", paste(c(sub("[.]R$", "", basename(a[1])), a[-1]), collapse = "_"))',
               'writeLines(as.character(Sys.getpid()), paste0("pid_", b, ".txt"))',
               'code <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", a),',
               '                stdout = paste0("log_", b, ".txt"), stderr = paste0("err_", b, ".txt"))',
               'writeLines(as.character(code), paste0("done_", b, ".txt"))'),
             file.path(copy, "run_step.R"))
  run_steps <- function(steps, limit_minutes = 120) {
    old <- setwd(copy); on.exit(setwd(old))
    tag <- vapply(steps, function(s) gsub("[^A-Za-z0-9]+", "_", paste(c(sub("[.]R$", "", basename(s[1])), s[-1]), collapse = "_")), "")
    unlink(c(paste0("done_", tag, ".txt"), paste0("pid_", tag, ".txt")))
    for (s in steps) system2(rscript, c("--vanilla", "run_step.R", s), wait = FALSE)
    t0 <- Sys.time()
    exit_code <- function(g) {            # NA while the step is still running
      f <- paste0("done_", g, ".txt")
      if (!file.exists(f)) return(NA_integer_)
      suppressWarnings(as.integer(readLines(f, warn = FALSE)[1]))
    }
    stop_running <- function(running) for (g in running) {   # best effort: end the steps that are still going
      pid <- tryCatch(readLines(paste0("pid_", g, ".txt"), warn = FALSE)[1], error = function(e) NA)
      if (is.na(pid)) next
      if (.Platform$OS.type == "windows") system2("taskkill", c("/PID", pid, "/T", "/F"), stdout = FALSE, stderr = FALSE)
      else { system2("pkill", c("-P", pid), stdout = FALSE, stderr = FALSE); tools::pskill(as.integer(pid)) }
    }
    repeat {
      codes <- vapply(tag, exit_code, integer(1))
      bad <- tag[!is.na(codes) & codes != 0L]
      if (length(bad)) {                  # stop at once instead of waiting for the other steps
        stop_running(tag[is.na(codes)])
        for (g in bad) cat(tail(c(readLines(paste0("log_", g, ".txt"), warn = FALSE), readLines(paste0("err_", g, ".txt"), warn = FALSE)), 15), sep = "\n")
        stop("Step failed in the copy: ", paste(bad, collapse = ", "), ". The copy is kept at ", copy)
      }
      if (!anyNA(codes)) break
      if (difftime(Sys.time(), t0, units = "mins") > limit_minutes) {
        stop_running(tag[is.na(codes)])
        stop("Steps did not finish: ", paste(tag[is.na(codes)], collapse = ", "), ". The copy is kept at ", copy)
      }
      Sys.sleep(3)
    }
    msg("  finished: %s (%.1f minutes)", paste(tag, collapse = ", "), as.numeric(difftime(Sys.time(), t0, units = "mins")))
  }
  msg("Fitting the models again in the copy: steps 6, 9 and 14 side by side")
  run_steps(list("R/06_fit_models.R", "R/09_sensitivity.R", "R/14_early_models.R"))
  if (validation_refitted) {
    # step 7 skips a model whose results file exists: remove the copied results so that every model is fitted again.
    # The slow model M3 gets jobs of its own, with model lists that do not overlap.
    old_results <- list.files(file.path(copy, DIR_TAB), pattern = "^validation_.*_(rows|endcoverage)_M[0-9][.]csv$", full.names = TRUE)
    unlink(old_results)
    msg("Running the four out-of-sample experiments again in the copy (%d stored result files removed there)", length(old_results))
    run_steps(list(c("R/07_validate.R", "counties"), c("R/07_validate.R", "regions"),
                   c("R/07_validate.R", "later", "M0,M1,M2,M4"), c("R/07_validate.R", "later", "M3"),
                   c("R/07_validate.R", "forecast", "M0,M1,M2,M4"), c("R/07_validate.R", "forecast", "M3")), limit_minutes = 360)
    run_steps(list(c("R/07_validate.R", "summary")))
  }
  msg("Rebuilding what depends on the fits")
  for (s in list("R/08_outputs.R", c("R/14_early_models.R", "tables"), "R/15_early_outputs.R", "R/10_report_tables.R")) run_steps(list(s))
}

# ---------------------------------------------------------------------------
# 3. Compare the regenerated tables with the ones in this folder
# ---------------------------------------------------------------------------
both <- function(file) {
  a <- fread(file, colClasses = "character"); b <- fread(file.path(copy, file), colClasses = "character")
  if (!identical(names(a), names(b)) || nrow(a) != nrow(b) || !identical(a[[1]], b[[1]])) stop("Rows or columns differ in ", file)
  list(a = a, b = b)
}
size <- function(label, file, cols) {
  z <- both(file)
  x <- suppressWarnings(as.numeric(unlist(z$a[, ..cols]))); y <- suppressWarnings(as.numeric(unlist(z$b[, ..cols])))
  ok <- !is.na(x) & !is.na(y)
  d <- abs(x[ok] - y[ok]); rel <- 100 * d / pmax(abs(x[ok]), abs(y[ok]), 1e-12)
  data.table(quantity = label, table = file, values_compared = sum(ok),
             abs_diff_median = median(d), abs_diff_p95 = quantile(d, 0.95, names = FALSE), abs_diff_max = max(d),
             rel_diff_pct_median = median(rel), rel_diff_pct_p95 = quantile(rel, 0.95, names = FALSE), rel_diff_pct_max = max(rel))
}
hr9 <- c("hr_age", "hr_age_lo", "hr_age_hi", "hr_income", "hr_income_lo", "hr_income_hi", "hr_cases", "hr_cases_lo", "hr_cases_hi")
CRPS <- "Out-of-sample experiments: mean CRPS by experiment and model, points"
dif <- rbind(
  size("Fixed-effect coefficients, all models (log scale)", "outputs/models/fixed_effects.csv", c("mean", "q025", "q975")),
  size("Hazard ratios by period, all variants", "outputs/tables/early_period_associations.csv", c("hazard_ratio", "lo", "hi")),
  size("Hazard ratios, sensitivity variants", "outputs/tables/sensitivity.csv", hr9),
  size("Variance and correlation parameters, all models", "outputs/models/hyperparameters.csv", c("mean", "q025", "q975")),
  size("County relative uptake", "outputs/tables/county_results.csv", "rel_uptake"),
  size("County relative uptake, interval bounds", "outputs/tables/county_results.csv", c("rel_uptake_lo", "rel_uptake_hi")),
  size("Modelled change in coverage, points", "outputs/tables/county_results.csv", "modelled_change_pp"),
  size("Modelled uptake per county and interval, % per 30 days", "outputs/tables/modelled_uptake_county_interval.csv", "modelled_uptake30_pct"),
  size("Modelled uptake, interval bounds", "outputs/tables/modelled_uptake_county_interval.csv", c("modelled_lo", "modelled_hi")),
  size("County relative uptake by period (extension)", "outputs/tables/early_relative_uptake_by_period.csv",
       c("rel_early_restricted", "rel_spring_2021", "rel_later")))
if (validation_refitted) dif <- rbind(dif,
  size(CRPS, "outputs/tables/fig05_validation_summary.csv", "mean_crps_pp"),
  size("Out-of-sample experiments: share of outcomes inside the 95% interval (fraction)", "outputs/tables/fig05_validation_summary.csv", "coverage95"),
  size("Out-of-sample experiments: paired differences in CRPS between models, points", "outputs/tables/validation_paired_differences.csv",
       c("diff_crps_pp", "diff_crps_lo", "diff_crps_hi")))
num_cols <- names(dif)[-(1:3)]
dif[, (num_cols) := lapply(.SD, signif, 3), .SDcols = num_cols]
fwrite(dif, file.path(DIR_TAB, "rerun_differences.csv"))
print(dif[, .(quantity, values_compared, abs_diff_max, rel_diff_pct_max)])

# values quoted in the documents, without run times
allq <- merge(quoted("."), quoted(copy), by = c("document", "name"), suffixes = c("_published", "_rerun"), sort = FALSE)
allq <- allq[!is_run_time(name)]
crps_max <- if (validation_refitted) formatC(dif[quantity == CRPS]$abs_diff_max, format = "f", digits = 3) else "not measured"
crps_rel_max <- if (validation_refitted) formatC(dif[quantity == CRPS]$rel_diff_pct_max, format = "f", digits = 1) else "not measured"
run_date <- sub("^0", "", format(Sys.Date(), "%d %B %Y"))
vr <- value_results(allq, validation_refitted, crps_max, crps_rel_max, run_date)
write_value_tables(vr, validation_refitted)
msg("Values compared: %s; came out differently: %s. From the out-of-sample experiments: %s values, came out differently: %s",
    vr$entries$n_values, vr$entries$n_changed, vr$entries$n_validation, vr$entries$n_changed_validation)

# how many stored tables the copy rewrote, and how many of those are byte-identical
tabs <- c(list.files(DIR_TAB, pattern = "[.]csv$", full.names = TRUE), list.files(DIR_MOD, pattern = "[.]csv$", full.names = TRUE))
tabs <- tabs[!grepl("^rerun_", basename(tabs)) & file.exists(file.path(copy, tabs))]
rewritten <- if (mode == "folder") tabs else tabs[file.mtime(file.path(copy, tabs)) > t_start]
same <- vapply(rewritten, function(f) identical(unname(tools::md5sum(f)), unname(tools::md5sum(file.path(copy, f)))), logical(1))
msg("Tables rewritten in the copy: %d; byte-identical to this folder's: %d", length(rewritten), sum(same))

# ---------------------------------------------------------------------------
# 4. One model fitted four times
# ---------------------------------------------------------------------------
msg("Fitting model M1 four times")
d <- load_panel("panel.csv"); W <- build_graph()
pipeline_threads <- INLA_THREADS
one <- function(threads) {
  INLA_THREADS <<- threads
  r <- fit_model(d, "M1", W)
  list(fixed = r$summary.fixed[, "mean"], hyper = r$summary.hyperpar[, "mean"], draws = as.numeric(unlist(sample_eta(r, rows = 1:200, n = 200))))
}
relmax <- function(x, y) 100 * max(abs(x - y) / pmax(abs(x), abs(y), 1e-300))
pair <- function(label, threads) {
  a <- one(threads); b <- one(threads)
  data.table(comparison = label, threads = threads, coefficients_max_rel_diff_pct = signif(relmax(a$fixed, b$fixed), 3),
             variance_parameters_max_rel_diff_pct = signif(relmax(a$hyper, b$hyper), 3), same_posterior_draws = identical(a$draws, b$draws))
}
rep4 <- rbind(pair("pipeline threads, fitted twice", pipeline_threads), pair("one thread, fitted twice", "1:1"))
INLA_THREADS <- pipeline_threads
fwrite(rep4, file.path(DIR_TAB, "rerun_repeat_fit.csv"))
print(rep4)

# ---------------------------------------------------------------------------
# Figures and sentences quoted in the README and the documents
# ---------------------------------------------------------------------------
g <- function(label, col) dif[quantity == label][[col]]
nd <- allq[document == "main report" & name == "n_distinct"]
S <- list(
  date           = run_date,
  inla_version   = as.character(utils::packageDescription("INLA")$Version),
  threads        = pipeline_threads,
  hr_max        = formatC(max(g("Hazard ratios by period, all variants", "abs_diff_max"), g("Hazard ratios, sensitivity variants", "abs_diff_max")), format = "f", digits = 4),
  rel_max        = formatC(g("County relative uptake", "rel_diff_pct_max"), format = "f", digits = 1),
  rel_ci_max     = formatC(g("County relative uptake, interval bounds", "rel_diff_pct_max"), format = "f", digits = 1),
  upt_max        = formatC(g("Modelled uptake per county and interval, % per 30 days", "abs_diff_max"), format = "f", digits = 2),
  var_max        = formatC(g("Variance and correlation parameters, all models", "rel_diff_pct_max"), format = "f", digits = 1),
  n_distinct_published = nd$value_published, n_distinct_rerun = nd$value_rerun,
  tables_rewritten = length(rewritten), tables_identical = sum(same),
  fit_threads_coef = formatC(rep4$coefficients_max_rel_diff_pct[1], format = "f", digits = 2),
  fit_one_coef     = formatC(rep4$coefficients_max_rel_diff_pct[2], format = "f", digits = 2),
  fit_same_draws   = if (any(rep4$same_posterior_draws)) "in some cases" else "in neither case",
  minutes        = round(as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
S[names(vr$entries)] <- vr$entries
write_summary(S)
if (mode != "folder") unlink(copy, recursive = TRUE)
msg("Wrote rerun_differences.csv, rerun_changed_values.csv, rerun_repeat_fit.csv and rerun_summary.csv in %s", DIR_TAB)
msg("Done in %d minutes.", S$minutes)
