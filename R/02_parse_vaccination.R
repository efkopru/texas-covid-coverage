# 02_parse_vaccination.R -- turn the raw vaccination files into tidy tables.
#
#   Rscript --vanilla R/02_parse_vaccination.R
#
# Inputs  : data/raw/dshs_vax_wayback/workbooks/*.xlsx   (original DSHS workbooks)
#           data/raw/dshs_vax_github/snapshots/*.csv      (daily copies of "By County")
#           data/raw/cdc_county_vax/cdc_8xkx-amqh_TX.csv  (CDC county file, Texas rows)
# Outputs : data/derived/county_lookup.csv
#           data/derived/dshs_workbook_index.csv
#           data/derived/dshs_county_total.csv
#           data/derived/dshs_county_age.csv
#           data/derived/dshs_state_by_vaxdate.csv
#           data/derived/cdc_county.csv
#
# Nothing is edited or imputed here: every number in the outputs is a cell of a
# source file, re-shaped and keyed by county FIPS code and date.

source("R/_common.R")
suppressMessages({library(readxl); library(data.table)})

squish <- function(x) gsub("[[:space:]]+", " ", trimws(as.character(x)))
num <- function(x) suppressWarnings(as.numeric(gsub(",", "", as.character(x))))

# ---------------------------------------------------------------------------
# County lookup (254 Texas counties) from the Census population-estimates file
# ---------------------------------------------------------------------------
pep <- fread(file.path(DIR_RAW, "census_pep/cc-est2025-agesex-48.csv"),
             colClasses = list(character = c("STATE", "COUNTY")), encoding = "Latin-1")
lk <- unique(pep[, .(fips = paste0(STATE, COUNTY), county = sub(" County$", "", CTYNAME))])
lk[, key := county_key(county)]
stopifnot(nrow(lk) == 254, !anyDuplicated(lk$key), all(nchar(lk$fips) == 5))
fwrite(lk[, .(fips, county)], file.path(DIR_DERIVED, "county_lookup.csv"))

# ---------------------------------------------------------------------------
# Parsers shared by the workbook sheets and the CSV copies
# ---------------------------------------------------------------------------
# "By County" layout: one header row, then Texas, programme rows, 254 counties, Other.
parse_by_county <- function(x) {
  hdr <- squish(unlist(x[1, ])); hdr[is.na(hdr)] <- ""
  col <- function(p) { i <- grep(p, hdr, ignore.case = TRUE); if (length(i)) i[1] else NA_integer_ }
  ci <- c(county = col("^county"),
          doses_admin = col("doses administered"),
          one_dose = col("at least one dose"),
          fully = col("fully vaccinated"),
          pop5 = col("population[, ]*5[+]"),
          pop12 = col("population[, ]*12[+]"),
          pop16 = col("population[, ]*16[+]"),
          pop65 = col("population[, ]*65[+]"))
  stopifnot(!is.na(ci[["county"]]), !is.na(ci[["one_dose"]]))
  b <- x[-1, , drop = FALSE]
  out <- data.table(name = squish(b[[ci[["county"]]]]))
  for (v in names(ci)[-1]) out[[v]] <- if (is.na(ci[[v]])) NA_real_ else num(b[[ci[[v]]]])
  out <- out[!is.na(name) & name != "" & name != "NULL"]
  out[, key := county_key(sub("^[*]", "", name))]
  out
}

# Age labels. From November 2021 Excel turned the labels "5-11" and "12-15"
# into dates (May 11 and Dec 15 of the file's year); they are restored here.
AGE_LEVELS <- c("0-4", "5-11", "12-15", "16-49", "50-64", "65-79", "80+", "Unknown")
norm_age <- function(a) {
  a <- sub(" years$", "", squish(a))
  ser <- !is.na(a) & grepl("^[0-9]{5}$", a)
  md <- format(excel_date(a[ser]), "%m-%d")
  a[ser] <- ifelse(md == "05-11", "5-11", ifelse(md == "12-15", "12-15", paste0("serial_", a[ser])))
  a[!is.na(a) & a == "6mo-4yr"] <- "0-4"
  a
}

parse_county_age <- function(x) {
  hdr <- squish(unlist(x[1, ])); hdr[is.na(hdr)] <- ""
  col <- function(p) { i <- grep(p, hdr, ignore.case = TRUE); if (length(i)) i[1] else NA_integer_ }
  ci <- c(county = col("^county"), age = col("^age"), doses_admin = col("doses administered"),
          one_dose = col("at least one dose"), fully = col("fully vaccinated"))
  stopifnot(!anyNA(ci))
  b <- x[-1, , drop = FALSE]
  out <- data.table(name = squish(b[[ci[["county"]]]]), age_raw = squish(b[[ci[["age"]]]]),
                    age_group = norm_age(b[[ci[["age"]]]]),
                    doses_admin = num(b[[ci[["doses_admin"]]]]),
                    one_dose = num(b[[ci[["one_dose"]]]]),
                    fully = num(b[[ci[["fully"]]]]))
  out[, key := county_key(sub("^[*]", "", name))]
  out
}

read_sheet <- function(path, sheet) {
  as.data.frame(suppressMessages(read_excel(path, sheet = sheet, col_names = FALSE,
                                            col_types = "text", .name_repair = "minimal")),
                stringsAsFactors = FALSE)
}

# Workbook "last modified" time from the XLSX package metadata (docProps/core.xml).
core_modified <- function(path) {
  td <- tempfile("core"); dir.create(td)
  on.exit(unlink(td, recursive = TRUE))
  f <- tryCatch(utils::unzip(path, files = "docProps/core.xml", exdir = td), error = function(e) character())
  if (!length(f)) return(as.POSIXct(NA))
  xml <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "")
  m <- regmatches(xml, regexpr("<dcterms:modified[^>]*>[^<]+", xml))
  if (!length(m)) return(as.POSIXct(NA))
  as.POSIXct(sub(".*>", "", m), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
}

# ---------------------------------------------------------------------------
# 1. Original DSHS workbooks (Wayback Machine captures)
# ---------------------------------------------------------------------------
wb_files <- sort(list.files(file.path(DIR_RAW, "dshs_vax_wayback/workbooks"),
                            pattern = "[.]xlsx$", full.names = TRUE))
msg("Parsing %d DSHS workbooks", length(wb_files))
idx <- list(); tot <- list(); age <- list(); vd <- list()
for (f in wb_files) {
  sh <- excel_sheets(f)
  cap <- sub(".*_([0-9]{14})[.]xlsx$", "\\1", f)
  # as-of date: the "About the Data" cell where present, else the workbook's
  # own modified time expressed as a US Central calendar date.
  asof_cell <- as.Date(NA)
  ab <- sh[grepl("about", sh, ignore.case = TRUE)]
  if (length(ab)) {
    a <- read_sheet(f, ab[1])
    i <- which(grepl("current as of", a[[1]], ignore.case = TRUE))
    if (length(i) && ncol(a) >= 2) asof_cell <- excel_date(num(a[i[1], 2]))
  }
  mod_utc <- core_modified(f)
  mod_central <- as.Date(format(mod_utc, tz = "America/Chicago", usetz = FALSE))
  as_of <- if (!is.na(asof_cell)) asof_cell else mod_central

  s_cty <- sh[grepl("^(by county|data)$", trimws(sh), ignore.case = TRUE)][1]
  bc <- parse_by_county(read_sheet(f, s_cty))
  st <- bc[key == "TEXAS"]
  ot <- bc[key == "OTHER"]
  cty <- merge(lk, bc, by = "key")
  stopifnot(nrow(cty) == 254)
  tot[[f]] <- cty[, .(source = "wayback", file = basename(f), as_of, fips, county,
                      doses_admin, one_dose, fully, pop5, pop12, pop16, pop65)]

  s_age <- sh[grepl("county.*age", sh, ignore.case = TRUE)][1]
  n_age_rows <- 0L
  if (!is.na(s_age)) {
    ca <- parse_county_age(read_sheet(f, s_age))
    ca <- ca[age_group %in% AGE_LEVELS]
    ca <- merge(lk, ca, by = "key")
    n_age_rows <- nrow(ca)
    age[[f]] <- ca[, .(file = basename(f), as_of, fips, county, age_group, doses_admin, one_dose, fully)]
  }

  s_vd <- sh[grepl("^by vaccination date$", trimws(sh), ignore.case = TRUE)][1]
  if (!is.na(s_vd)) {
    v <- read_sheet(f, s_vd)
    h <- squish(unlist(v[1, ]))
    v <- v[-1, , drop = FALSE]
    vd[[f]] <- data.table(file = basename(f), as_of,
                          vax_date = excel_date(num(v[[1]])),
                          doses_admin = num(v[[grep("doses administered", h, ignore.case = TRUE)[1]]]),
                          one_dose = num(v[[grep("at least one dose", h, ignore.case = TRUE)[1]]]),
                          fully = num(v[[grep("fully vaccinated", h, ignore.case = TRUE)[1]]]))[!is.na(vax_date)]
  }

  idx[[f]] <- data.table(file = basename(f), wayback_capture_utc = cap,
                         as_of_cell = asof_cell, workbook_modified_utc = format(mod_utc, "%Y-%m-%d %H:%M:%S"),
                         workbook_modified_central_date = mod_central, as_of,
                         sheets = paste(sh, collapse = "; "),
                         has_county_age = !is.na(s_age), has_by_vax_date = !is.na(s_vd),
                         state_row_one_dose = if (nrow(st)) st$one_dose[1] else NA_real_,
                         county_sum_one_dose = sum(cty$one_dose, na.rm = TRUE),
                         other_row_one_dose = if (nrow(ot)) ot$one_dose[1] else NA_real_,
                         state_pop16 = if (nrow(st)) st$pop16[1] else NA_real_,
                         state_pop12 = if (nrow(st)) st$pop12[1] else NA_real_,
                         n_county_age_rows = n_age_rows)
}
idx <- rbindlist(idx); tot_wb <- rbindlist(tot); age <- rbindlist(age); vd <- rbindlist(vd)
# Two captures can hold the same workbook edition; keep one row per as-of date
# (the later capture) but record every file in the index.
idx[, used := !duplicated(as_of, fromLast = TRUE)]
tot_wb <- tot_wb[file %in% idx[used == TRUE, file]]
age <- age[file %in% idx[used == TRUE, file]]
vd <- vd[file %in% idx[used == TRUE, file]]
fwrite(idx, file.path(DIR_DERIVED, "dshs_workbook_index.csv"))
fwrite(age, file.path(DIR_DERIVED, "dshs_county_age.csv"))
fwrite(vd, file.path(DIR_DERIVED, "dshs_state_by_vaxdate.csv"))
msg("  %d workbooks, %d distinct as-of dates (%s to %s); county-by-age sheets in %d",
    nrow(idx), sum(idx$used), min(idx$as_of), max(idx$as_of), sum(idx$used & idx$has_county_age))

# ---------------------------------------------------------------------------
# 2. Daily CSV copies of the "By County" sheet (GitHub archive)
#    File name = date DSHS last modified the workbook (US Central) = as-of date.
# ---------------------------------------------------------------------------
gh_files <- sort(list.files(file.path(DIR_RAW, "dshs_vax_github/snapshots"),
                            pattern = "^[0-9]{4}-[0-9]{2}-[0-9]{2}[.]csv$", full.names = TRUE))
msg("Parsing %d GitHub 'By County' snapshots", length(gh_files))
tot <- list()
for (f in gh_files) {
  x <- utils::read.csv(f, header = FALSE, colClasses = "character", check.names = FALSE,
                       fill = TRUE, na.strings = character(), encoding = "UTF-8")
  bc <- parse_by_county(x)
  cty <- merge(lk, bc, by = "key")
  if (nrow(cty) != 254) stop("Expected 254 counties in ", f, ", found ", nrow(cty))
  tot[[f]] <- cty[, .(source = "github", file = basename(f),
                      as_of = as.Date(sub("[.]csv$", "", basename(f))), fips, county,
                      doses_admin, one_dose, fully, pop5, pop12, pop16, pop65)]
}
tot_gh <- rbindlist(tot)

# State row and the "Other" row (recipient's county unknown or address out of
# state) for every daily snapshot: needed to trace people who had not yet been
# assigned to a county.
so <- rbindlist(lapply(gh_files, function(f) {
  x <- utils::read.csv(f, header = FALSE, colClasses = "character", check.names = FALSE,
                       fill = TRUE, na.strings = character(), encoding = "UTF-8")
  bc <- parse_by_county(x)
  data.table(as_of = as.Date(sub("[.]csv$", "", basename(f))),
             state_row_one_dose = bc[key == "TEXAS", one_dose][1],
             other_row_one_dose = bc[key == "OTHER", one_dose][1],
             state_row_fully = bc[key == "TEXAS", fully][1],
             other_row_fully = bc[key == "OTHER", fully][1])
}))
so <- merge(so, tot_gh[, .(county_sum_one_dose = sum(one_dose), county_sum_fully = sum(fully)), by = as_of], by = "as_of")
fwrite(so, file.path(DIR_DERIVED, "dshs_state_other_daily.csv"))

dshs <- rbind(tot_wb, tot_gh)
setorder(dshs, as_of, source, fips)
fwrite(dshs, file.path(DIR_DERIVED, "dshs_county_total.csv"))
msg("  GitHub snapshots span %s to %s", min(tot_gh$as_of), max(tot_gh$as_of))

# ---------------------------------------------------------------------------
# 3. CDC county file, Texas rows
# ---------------------------------------------------------------------------
cdc <- fread(file.path(DIR_RAW, "cdc_county_vax/cdc_8xkx-amqh_TX.csv"),
             colClasses = list(character = c("fips", "date")))
cdc[, date := as.Date(substr(date, 1, 10))]
keep <- c("date", "fips", "recip_county", "completeness_pct",
          "administered_dose1_recip", "administered_dose1_pop_pct",
          "administered_dose1_recip_5plus", "administered_dose1_recip_5pluspop_pct",
          "administered_dose1_recip_12plus", "administered_dose1_recip_12pluspop_pct",
          "administered_dose1_recip_18plus", "administered_dose1_recip_18pluspop_pct",
          "administered_dose1_recip_65plus", "administered_dose1_recip_65pluspop_pct",
          "series_complete_yes", "series_complete_12plus", "series_complete_18plus",
          "booster_doses", "census2019", "census2019_5pluspop", "census2019_12pluspop",
          "census2019_18pluspop", "census2019_65pluspop", "metro_status", "svi_ctgy")
stopifnot(all(keep %in% names(cdc)))
cdc <- cdc[, ..keep]
stopifnot(all(cdc[fips != "UNK", unique(fips)] %in% lk$fips),
          cdc[fips != "UNK", uniqueN(fips)] == 254)
setorder(cdc, date, fips)
fwrite(cdc, file.path(DIR_DERIVED, "cdc_county.csv"))
msg("CDC: %d rows, %d report dates, %s to %s; first date with Texas counts: %s",
    nrow(cdc), uniqueN(cdc$date), min(cdc$date), max(cdc$date),
    cdc[fips != "UNK" & administered_dose1_recip > 0, min(date)])
