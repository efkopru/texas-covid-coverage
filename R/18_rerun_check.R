# 18_rerun_check.R -- how closely do the modelled results repeat when the models are fitted again?
#
#   Rscript --vanilla R/18_rerun_check.R              about 15 minutes
#   Rscript --vanilla R/18_rerun_check.R <folder>     compare with an existing second copy instead of making one
#   Rscript --vanilla R/18_rerun_check.R summary      recount rerun_summary.csv from the stored tables; fits nothing
#
# R-INLA does not return exactly the same fit twice, and the posterior draws then come out as a
# different sample even though their seed is fixed. This script measures how much that matters:
#   1. it copies the code, the derived data and the stored tables to a temporary folder,
#   2. refits every model there (steps 6, 9 and 14, side by side) and rebuilds what depends on the
#      fits (step 8, the tables of step 14, steps 15 and 10),
#   3. compares each regenerated table with the one in this folder, and
#   4. fits one model four times: twice with the pipeline's threads and twice with a single thread.
# Nothing in this folder changes except the four tables it writes to outputs/tables/:
#   rerun_differences.csv      size of the differences, quantity by quantity
#   rerun_changed_values.csv   values quoted in the documents that came out differently
#   rerun_repeat_fit.csv       one model fitted four times
#   rerun_summary.csv          the figures quoted in the README and the documents ({{v:rr_key}})
# The out-of-sample experiments (step 7, one to two hours) are not fitted again. The values that the documents
# quote from them therefore cannot differ; they are counted apart and are not among the values compared.

source("R/_common.R")
source("R/_models.R")
source("R/_report.R")

args <- commandArgs(trailingOnly = TRUE)
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

if (length(args) && args[1] == "summary") {
  f <- file.path(DIR_TAB, "rerun_summary.csv")
  if (!file.exists(f)) stop("Nothing to recount: run this script without arguments first")
  s0 <- fread(f, colClasses = "character")
  S <- as.list(setNames(s0$value, s0$name))
  q0 <- quoted(".")[!is_run_time(name)]
  S$n_values <- q0[!from_validation(document, name), .N]
  S$n_validation <- q0[from_validation(document, name), .N]
  stopifnot(as.integer(S$n_changed) == nrow(fread(file.path(DIR_TAB, "rerun_changed_values.csv"))))
  fwrite(data.table(name = names(S), value = vapply(S, as.character, "")), f)
  msg("Recounted: %s values compared, %s from the out-of-sample experiments not compared, %s came out differently",
      S$n_values, S$n_validation, S$n_changed)
  quit(save = "no")
}

# ---------------------------------------------------------------------------
# 1 and 2. A second copy with every model fitted again
# ---------------------------------------------------------------------------
if (length(args)) {
  copy <- normalizePath(args[1], winslash = "/", mustWork = TRUE)
  made_here <- FALSE
  msg("Comparing with the existing copy %s", copy)
} else {
  copy <- file.path(tempdir(), "txcov_rerun")
  made_here <- TRUE
  unlink(copy, recursive = TRUE)
  for (d in c("R", "docs", "data/derived", "outputs/tables", "outputs/models")) {
    dir.create(file.path(copy, d), recursive = TRUE)
    f <- list.files(d, full.names = TRUE)
    f <- f[!dir.exists(f) & !grepl("^samples_.*[.]rds$", basename(f)) & !grepl("[.](html|pdf)$", f)]
    stopifnot(all(file.copy(f, file.path(copy, d), copy.date = TRUE)))
  }
  msg("Copied code, derived data and stored tables to a temporary folder (%.0f MB)",
      sum(file.size(list.files(copy, recursive = TRUE, full.names = TRUE))) / 1e6)

  # a small wrapper so that several steps can run side by side and report when they end
  writeLines(c('a <- commandArgs(trailingOnly = TRUE)',
               'b <- paste(c(sub("[.]R$", "", basename(a[1])), a[-1]), collapse = "_")',
               'code <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", a),',
               '                stdout = paste0("log_", b, ".txt"), stderr = paste0("err_", b, ".txt"))',
               'writeLines(as.character(code), paste0("done_", b, ".txt"))'),
             file.path(copy, "run_step.R"))
  run_steps <- function(steps, limit_minutes = 120) {
    old <- setwd(copy); on.exit(setwd(old))
    tag <- vapply(steps, function(s) paste(c(sub("[.]R$", "", basename(s[1])), s[-1]), collapse = "_"), "")
    unlink(paste0("done_", tag, ".txt"))
    for (s in steps) system2(rscript, c("--vanilla", "run_step.R", s), wait = FALSE)
    t0 <- Sys.time()
    while (!all(file.exists(paste0("done_", tag, ".txt")))) {
      if (difftime(Sys.time(), t0, units = "mins") > limit_minutes) stop("Steps did not finish: ", paste(tag, collapse = ", "))
      Sys.sleep(3)
    }
    for (g in tag) {
      code <- as.integer(readLines(paste0("done_", g, ".txt"))[1])
      if (!identical(code, 0L)) {
        cat(tail(c(readLines(paste0("log_", g, ".txt"), warn = FALSE), readLines(paste0("err_", g, ".txt"), warn = FALSE)), 15), sep = "\n")
        stop("Step failed in the copy: ", g)
      }
    }
    msg("  finished: %s (%.1f minutes)", paste(tag, collapse = ", "), as.numeric(difftime(Sys.time(), t0, units = "mins")))
  }
  msg("Fitting every model again in the copy: steps 6, 9 and 14 side by side")
  run_steps(list("R/06_fit_models.R", "R/09_sensitivity.R", "R/14_early_models.R"))
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
num_cols <- names(dif)[-(1:3)]
dif[, (num_cols) := lapply(.SD, signif, 3), .SDcols = num_cols]
fwrite(dif, file.path(DIR_TAB, "rerun_differences.csv"))
print(dif[, .(quantity, values_compared, abs_diff_max, rel_diff_pct_max)])

# values quoted in the documents: run times are left out, and so are the values taken from the out-of-sample
# experiments, which were not fitted again and so cannot differ
q <- merge(quoted("."), quoted(copy), by = c("document", "name"), suffixes = c("_published", "_rerun"), sort = FALSE)
q <- q[!is_run_time(name)]
n_validation <- q[from_validation(document, name), .N]
stopifnot(q[from_validation(document, name) & value_published != value_rerun, .N] == 0)
q <- q[!from_validation(document, name)]
changed <- q[value_published != value_rerun, .(document, value = name, published = value_published, rerun = value_rerun)]
# how far apart, counted in units of the last printed digit: 4.29 against 4.33 is 4 units, 136 against 138 is 2
nums <- function(s) regmatches(s, gregexpr("-?[0-9]+([.][0-9]+)?", s))[[1]]
units <- function(a, b) {
  x <- nums(a); y <- nums(b)
  if (!length(x) || length(x) != length(y)) return(NA_real_)
  decimals <- nchar(sub("^[^.]*[.]?", "", x))
  round(max(abs(as.numeric(x) - as.numeric(y)) * 10^decimals))
}
changed[, units_of_last_digit := if (.N) mapply(units, published, rerun) else numeric()]
fwrite(changed, file.path(DIR_TAB, "rerun_changed_values.csv"))
msg("Values compared: %d; came out differently: %d; not compared because they come from the out-of-sample experiments: %d",
    nrow(q), nrow(changed), n_validation)

# how many stored tables the copy rewrote, and how many of those are byte-identical
tabs <- c(list.files(DIR_TAB, pattern = "[.]csv$", full.names = TRUE), list.files(DIR_MOD, pattern = "[.]csv$", full.names = TRUE))
tabs <- tabs[!grepl("^rerun_", basename(tabs)) & file.exists(file.path(copy, tabs))]
rewritten <- if (made_here) tabs[file.mtime(file.path(copy, tabs)) > t_start] else tabs
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
# Figures quoted in the README and the documents
# ---------------------------------------------------------------------------
g <- function(label, col) dif[quantity == label][[col]]
nd <- q[document == "main report" & name == "n_distinct"]
S <- list(
  date           = sub("^0", "", format(Sys.Date(), "%d %B %Y")),
  inla_version   = as.character(utils::packageDescription("INLA")$Version),
  threads        = pipeline_threads,
  n_values       = nrow(q),
  n_validation   = n_validation,
  n_changed      = nrow(changed),
  n_changed_main = changed[document == "main report", .N],
  n_changed_early = changed[document == "early rollout", .N],
  units_max      = if (nrow(changed)) max(changed$units_of_last_digit, na.rm = TRUE) else 0,
  hr_max         = formatC(max(g("Hazard ratios by period, all variants", "abs_diff_max"), g("Hazard ratios, sensitivity variants", "abs_diff_max")), format = "f", digits = 4),
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
fwrite(data.table(name = names(S), value = vapply(S, as.character, "")), file.path(DIR_TAB, "rerun_summary.csv"))
if (made_here) unlink(copy, recursive = TRUE)
msg("Wrote rerun_differences.csv, rerun_changed_values.csv, rerun_repeat_fit.csv and rerun_summary.csv in %s", DIR_TAB)
msg("Done in %d minutes.", S$minutes)
