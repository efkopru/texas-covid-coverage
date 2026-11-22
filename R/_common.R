# _common.R -- shared paths, constants and helpers. Sourced by every script.
#
# All scripts are run from the project root:
#   Rscript --vanilla R/<script>.R
# --vanilla matters: it stops R from loading .RData/.Rprofile files, so nothing
# inside the downloaded-data folders can be executed by accident.

if (!file.exists("R/_common.R")) {
  stop("Run scripts from the project root, e.g. Rscript --vanilla R/01_download_sources.R")
}
.libPaths(c(file.path(getwd(), "r-lib"), .libPaths()))

DIR_RAW     <- "data/raw"
DIR_DERIVED <- "data/derived"
DIR_OUT     <- "outputs"
DIR_FIG     <- file.path(DIR_OUT, "figures")
DIR_TAB     <- file.path(DIR_OUT, "tables")
DIR_MOD     <- file.path(DIR_OUT, "models")
for (d in c(DIR_RAW, DIR_DERIVED, DIR_FIG, DIR_TAB, DIR_MOD)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

MANIFEST <- file.path(DIR_RAW, "MANIFEST.csv")
USER_AGENT <- "tx-covid-coverage-study/1.0 (R libcurl)"

# ---------------------------------------------------------------------------
# Study constants (see docs/01_source_inventory.md for the evidence behind them)
# ---------------------------------------------------------------------------
STATE_FIPS <- "48"

# Time grid of the analysis: "as of" dates of the original DSHS workbooks used
# as interval boundaries. An edition dated D holds records through D - 1.
# The first edition is the baseline; each later one closes an interval. They
# are the surviving editions that give intervals closest to one month.
#
# main  : baseline 24 May 2021 (first edition after DSHS stopped re-assigning
#         early records between counties), near-monthly intervals to February
#         2022, then the only edition available before June 2022, then two
#         half-year intervals to May 2023 (by then net changes in most counties
#         were smaller than routine record corrections, so months are pooled).
# early : adds the interval 23 April - 24 May 2021 (sensitivity analysis).
# fine  : keeps every near-monthly edition after May 2022 (sensitivity analysis).
GRIDS <- list(
  main = as.Date(c("2021-05-25", "2021-06-23", "2021-07-22", "2021-08-22", "2021-09-24",
                   "2021-10-26", "2021-11-21", "2021-12-22", "2022-01-22", "2022-02-26",
                   "2022-05-31", "2022-11-21", "2023-05-10")),
  early = as.Date(c("2021-04-23", "2021-05-25", "2021-06-23", "2021-07-22", "2021-08-22", "2021-09-24",
                    "2021-10-26", "2021-11-21", "2021-12-22", "2022-01-22", "2022-02-26",
                    "2022-05-31", "2022-11-21", "2023-05-10")),
  fine = as.Date(c("2021-05-25", "2021-06-23", "2021-07-22", "2021-08-22", "2021-09-24",
                   "2021-10-26", "2021-11-21", "2021-12-22", "2022-01-22", "2022-02-26",
                   "2022-05-31", "2022-07-11", "2022-08-15", "2022-10-03", "2022-11-21",
                   "2022-12-28", "2023-01-25", "2023-03-29", "2023-05-10")))
GRID_ASOF <- GRIDS$main

# A county-interval enters the binomial model only if recorded coverage at the
# start of the interval is below this share of the population estimate (%).
COVERAGE_CEILING <- 95
# A county is left out of the binomial model altogether if its recorded count
# of vaccinated residents ever exceeds this share of its population estimate.
COUNTY_MAX_COVERAGE <- 100

# Models used for the reported results, chosen on out-of-sample performance
# (docs/02_report.md, section 4.2). No single model was best at everything:
# FINAL_MODEL   best at a county's next interval and at leave-one-out
#               prediction, lowest CRPS for later intervals; used for modelled
#               uptake and its intervals. (M3 is close: see the report.)
# SPATIAL_MODEL as good as any model at predicting counties with no data and
#               the simplest of them; used for statements about spatial
#               structure and for the "neighbours alone" check.
FINAL_MODEL <- "M4"
SPATIAL_MODEL <- "M1"

# CDC's county file contains Texas counties only from this report date onward.
CDC_TX_FIRST_DATE <- as.Date("2021-10-22")

# In the edition of this date DSHS moved 662,780 first-dose recipients from
# the "Other" (county unknown) row to counties; county counts before it are
# incomplete to a degree that differs by county.
DSHS_COUNTY_FIX_DATE <- as.Date("2021-04-15")

# ---------------------------------------------------------------------------
# Extension to the first months of the rollout (docs/03_early_rollout.md).
# It rests on an assumption about where the then-unassigned recipients lived,
# so its inputs and outputs are kept apart from the main analysis.
# ---------------------------------------------------------------------------
EARLY_START <- as.Date("2020-12-14")          # first vaccine doses delivered and given in Texas
# Daily editions used as boundaries before the baseline: records through
# 31 December, 30 January (no edition survives for 1 February), 28 February,
# 31 March, and 13 April (the last edition before the correction).
EARLY_ASOF <- as.Date(c("2021-01-01", "2021-01-31", "2021-03-01", "2021-04-01", "2021-04-14"))
# Records kept moving between counties for some weeks after the correction;
# daily falls in county counts become negligible after this edition.
DSHS_FLUX_END <- as.Date("2021-05-11")
# A county's early records are treated as unsettled if the falls in its count
# between the correction and DSHS_FLUX_END exceed this share (%) of its count
# on the day of the correction, or if more than this share of its count at a
# boundary edition was later removed.
EARLY_UNSTABLE_FALLS_PCT <- 5
# One daily edition in which the "at least one dose" and "fully vaccinated"
# columns are interchanged; it is never used.
DSHS_FAULTY_DAILY <- as.Date("2021-03-12")
# Allocation rules for the records that had no county (see R/13):
#   H  in proportion to the county's published count at that date times the
#      share it received on 15 April (main assumption)
#   A  in proportion to the county's fixed share of the 15 April assignment
#   N  nothing allocated (counts as published)
EARLY_VARIANTS <- c(H = "Published count x share received in April", A = "Fixed April shares", N = "No allocation")

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "|", sprintf(...), "\n")

# Last calendar day of the month containing each date (vectorised).
month_end <- function(d) {
  d <- as.Date(d)
  y <- as.integer(format(d, "%Y"))
  m <- as.integer(format(d, "%m"))
  y2 <- ifelse(m == 12L, y + 1L, y)
  m2 <- ifelse(m == 12L, 1L, m + 1L)
  as.Date(sprintf("%04d-%02d-01", y2, m2)) - 1
}

month_seq <- function(from, to) seq(as.Date(format(from, "%Y-%m-01")),
                                    as.Date(format(to, "%Y-%m-01")), by = "month")

expit <- function(x) 1 / (1 + exp(-x))
logit <- function(p) log(p / (1 - p))

sha256_file <- function(path) unname(tools::sha256sum(path))

# Excel serial day number -> Date (Windows 1900 date system).
excel_date <- function(x) as.Date(as.numeric(x), origin = "1899-12-30")

# County names differ slightly between sources (case, "County" suffix, De Witt
# vs DeWitt, a stray trailing space). This key is used only to attach FIPS codes.
county_key <- function(x) {
  x <- toupper(trimws(x))
  x <- sub("[[:space:]]+COUNTY$", "", x)
  gsub("[^A-Z]", "", x)
}

# ---------------------------------------------------------------------------
# Provenance manifest: one row per raw file
# ---------------------------------------------------------------------------
read_manifest <- function() {
  if (!file.exists(MANIFEST)) {
    return(data.frame(source_id = character(), file = character(), url = character(),
                      retrieved_utc = character(), bytes = numeric(), sha256 = character(),
                      http_last_modified = character(), note = character(),
                      stringsAsFactors = FALSE))
  }
  read.csv(MANIFEST, stringsAsFactors = FALSE, colClasses = c(bytes = "numeric"))
}

add_manifest <- function(source_id, file, url, http_last_modified = "", note = "") {
  m <- read_manifest()
  m <- m[m$file != file, , drop = FALSE]
  row <- data.frame(source_id = source_id, file = file, url = url,
                    retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                    bytes = file.size(file), sha256 = sha256_file(file),
                    http_last_modified = http_last_modified, note = note,
                    stringsAsFactors = FALSE)
  m <- rbind(m, row)
  m <- m[order(m$source_id, m$file), ]
  write.csv(m, MANIFEST, row.names = FALSE)
  invisible(row)
}

# Download `url` to `dest` unless it is already there. Every successful
# download is recorded in the manifest with its SHA-256.
fetch <- function(url, dest, source_id, note = "", force = FALSE, retries = 5,
                  timeout = 900, zip_container = FALSE) {
  if (file.exists(dest) && !force) return(invisible("cached"))
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".part")
  res <- NULL
  for (i in seq_len(retries)) {
    h <- curl::new_handle(useragent = USER_AGENT, followlocation = TRUE,
                          timeout = timeout, connecttimeout = 60)
    res <- tryCatch(curl::curl_fetch_disk(url, tmp, handle = h), error = function(e) e)
    ok <- !inherits(res, "error") && res$status_code == 200
    # XLSX/DOCX/ZIP files are zip containers and must start with "PK"; an
    # archive error page served with HTTP 200 is rejected here.
    if (ok && zip_container) {
      ok <- identical(readBin(tmp, "raw", 2L), charToRaw("PK"))
      if (!ok) res <- simpleError("not a zip container (unexpected content)")
    }
    if (ok) break
    why <- if (inherits(res, "error")) conditionMessage(res) else paste("HTTP", res$status_code)
    msg("  attempt %d failed for %s (%s)", i, basename(dest), why)
    Sys.sleep(8 * i)
  }
  if (inherits(res, "error") || res$status_code != 200) {
    if (file.exists(tmp)) file.remove(tmp)
    stop("Download failed: ", url)
  }
  file.rename(tmp, dest)
  hdr <- curl::parse_headers_list(res$headers)
  lm <- if (!is.null(hdr[["last-modified"]])) hdr[["last-modified"]] else ""
  add_manifest(source_id, dest, url, http_last_modified = lm, note = note)
  msg("  downloaded %s (%s bytes)", dest, format(file.size(dest), big.mark = ","))
  invisible("downloaded")
}

# Verify that every file in the manifest is present and unchanged.
verify_manifest <- function() {
  m <- read_manifest()
  ok <- file.exists(m$file)
  same <- rep(NA, nrow(m))
  same[ok] <- vapply(m$file[ok], sha256_file, character(1)) == m$sha256[ok]
  data.frame(file = m$file, present = ok, sha256_matches = same)
}
