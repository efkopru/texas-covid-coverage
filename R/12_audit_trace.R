# 12_audit_trace.R -- trace reported numbers back to the raw files by a second route.
#
#   Rscript --vanilla R/12_audit_trace.R
#
# For a handful of counties this script re-reads the original DSHS workbook
# cells and the Census population file directly, without using any of the
# parsing code in 02-05, recomputes recorded coverage and the change over the
# study, and compares them with outputs/tables/county_results.csv. It prints
# the workbook file, sheet and rows each number came from.

source("R/_common.R")
suppressMessages({library(readxl); library(data.table)})
options(width = 200)

idx <- fread(file.path(DIR_DERIVED, "dshs_workbook_index.csv"))
man <- fread(MANIFEST)
res <- fread(file.path(DIR_TAB, "county_results.csv"), colClasses = list(character = "fips"))
pep <- fread(file.path(DIR_RAW, "census_pep/cc-est2025-syasex-48.csv"), colClasses = list(character = c("STATE", "COUNTY")))

counties <- c(Harris = "48201", Lubbock = "48303", Gaines = "48165", King = "48269", Bexar = "48029")
editions <- as.Date(c("2021-05-25", "2023-05-10"))
adult_bands <- c("16-49", "50-64", "65-79", "80+", "Unknown")

read_adults <- function(edition, county) {
  wb <- idx$file[as.Date(idx$as_of) == edition]
  stopifnot(length(wb) == 1)
  path <- file.path(DIR_RAW, "dshs_vax_wayback/workbooks", wb)
  x <- as.data.frame(suppressMessages(read_excel(path, sheet = "By County, Age", col_types = "text")))
  names(x) <- trimws(names(x))
  cty <- x[[grep("^County", names(x))[1]]]
  age <- sub(" years$", "", trimws(x[[grep("^Age", names(x))[1]]]))
  one <- as.numeric(x[[grep("at least One Dose", names(x))[1]]])
  rows <- which(trimws(cty) == county & age %in% adult_bands)
  mi <- which(basename(man$file) == wb)
  list(file = wb, excel_rows = rows + 1L, bands = age[rows], n = sum(one[rows]), url = man$url[mi], sha256 = man$sha256[mi])
}

ok <- TRUE
for (nm in names(counties)) {
  f <- counties[[nm]]
  pop16 <- pep[STATE == "48" & COUNTY == substr(f, 3, 5) & YEAR == 3 & AGE >= 16, sum(TOT_POP)]
  a <- read_adults(editions[1], nm); b <- read_adults(editions[2], nm)
  cov0 <- 100 * a$n / pop16; cov1 <- 100 * b$n / pop16
  r <- res[fips == f]
  same <- isTRUE(all.equal(c(cov0, cov1, cov1 - cov0), c(r$cov_baseline, r$cov_end, r$change_pp), tolerance = 1e-9)) && pop16 == r$pop16
  ok <- ok && same
  cat(sprintf("\n%s County (FIPS %s)\n", nm, f))
  cat(sprintf("  population 16+, 1 July 2021 : %s   (cc-est2025-syasex-48.csv, YEAR = 3, AGE >= 16)\n", format(pop16, big.mark = ",")))
  for (z in list(a, b)) {
    cat(sprintf("  %s, sheet 'By County, Age', rows %s (%s): %s adults with a first dose\n", z$file,
                paste(range(z$excel_rows), collapse = "-"), paste(z$bands, collapse = ", "), format(z$n, big.mark = ",")))
    cat(sprintf("      source %s\n      sha256 %s\n", z$url, z$sha256))
  }
  cat(sprintf("  recomputed: coverage %.4f%% -> %.4f%%, change %.4f points\n", cov0, cov1, cov1 - cov0))
  cat(sprintf("  reported  : coverage %.4f%% -> %.4f%%, change %.4f points   %s\n", r$cov_baseline, r$cov_end, r$change_pp,
              if (same) "MATCH" else "MISMATCH"))
}

# ---------------------------------------------------------------------------
# Early-rollout extension: reconstructed counts re-derived from the raw daily
# copies alone (state row, "Other" row and county rows of five files), without
# R/13. Compared with data/derived/early_reconstruction.csv.
# ---------------------------------------------------------------------------
if (file.exists(file.path(DIR_DERIVED, "early_reconstruction.csv"))) {
  lk <- fread(file.path(DIR_DERIVED, "county_lookup.csv"), colClasses = list(character = "fips"))
  keys <- county_key(lk$county)
  squish <- function(v) trimws(gsub("[[:space:]]+", " ", v))
  raw_day <- function(d) {
    f <- file.path(DIR_RAW, "dshs_vax_github/snapshots", sprintf("%s.csv", d))
    x <- utils::read.csv(f, header = FALSE, colClasses = "character", check.names = FALSE, fill = TRUE, na.strings = character(), encoding = "UTF-8")
    h <- squish(unlist(x[1, ])); x <- x[-1, , drop = FALSE]
    nm <- squish(x[[grep("^County", h)[1]]])
    one <- suppressWarnings(as.numeric(gsub(",", "", x[[grep("at least One Dose", h)[1]]])))
    k <- county_key(sub("^[*]", "", nm))
    i <- match(keys, k); stopifnot(!anyNA(i))
    mi <- which(basename(man$file) == basename(f))
    list(file = basename(f), state = one[nm == "Texas"][1], county = one[i], csv_row = i + 1L, sha256 = man$sha256[mi])
  }
  fixd <- DSHS_COUNTY_FIX_DATE; bdate <- as.Date("2021-03-01")
  a <- raw_day(fixd - 1); b <- raw_day(fixd); w <- raw_day(fixd + 7); t0 <- raw_day(bdate)
  other <- function(z) z$state - sum(z$county)
  r_res <- other(b) / b$state
  wk <- w$county - b$county
  R <- (b$county - a$county) - (1 - r_res) * (b$state - a$state) * wk / sum(wk)
  share <- pmax(R, 0) / a$county
  U <- max(other(t0) - r_res * t0$state, 0)
  alloc <- U * t0$county * share / sum(t0$county * share)
  er <- fread(file.path(DIR_DERIVED, "early_reconstruction.csv"), colClasses = list(character = "fips"))[as.Date(as_of) == bdate]
  cat(sprintf("\nEarly-rollout extension, edition of %s (records through %s)\n", bdate, bdate - 1))
  for (z in list(a, b, w, t0)) cat(sprintf("  %s  sha256 %s\n", z$file, z$sha256))
  cat(sprintf("  state total %s, sum of counties %s, no county %s; share still unassigned after the correction %.4f%%; allocated %s\n",
              format(t0$state, big.mark = ","), format(sum(t0$county), big.mark = ","), format(other(t0), big.mark = ","), 100 * r_res,
              format(round(U), big.mark = ",")))
  for (cn in c("Tarrant", "Harris", "Denton", "Lubbock")) {
    j <- which(lk$county == cn); e <- er[fips == lk$fips[j]]
    mine <- round(t0$county[j] + alloc[j])
    same <- t0$county[j] == e$published && mine == e$n_H && abs(alloc[j] - e$alloc_H) < 1e-6
    ok <- ok && same
    cat(sprintf("  %s (CSV row %d): published %s, share received in April %.2f%%, allocated %.1f, reconstructed %s; reported %s   %s\n", cn,
                t0$csv_row[j], format(t0$county[j], big.mark = ","), 100 * share[j], alloc[j], format(mine, big.mark = ","),
                format(e$n_H, big.mark = ","), if (same) "MATCH" else "MISMATCH"))
  }
}
cat(sprintf("\nAll traced numbers match: %s\n", ok))
v <- verify_manifest()
cat(sprintf("Raw files present: %d of %d; checksums unchanged: %d of %d\n", sum(v$present), nrow(v), sum(v$sha256_matches, na.rm = TRUE), nrow(v)))
if (!ok) quit(status = 1)
