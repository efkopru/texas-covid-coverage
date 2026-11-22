# 01_download_sources.R -- fetch every raw source file and record its provenance.
#
#   Rscript --vanilla R/01_download_sources.R
#
# Files that already exist are not downloaded again, so the script can be
# re-run safely after an interruption. Each file is listed in
# data/raw/MANIFEST.csv with its URL, retrieval time (UTC), size and SHA-256.
# Nothing downloaded here is executed: the files are data (CSV, XLSX, DOCX,
# PDF, DAT, a zipped shapefile) and each source has its own folder.

source("R/_common.R")
suppressMessages({library(curl); library(jsonlite)})

enc <- function(x) utils::URLencode(x, reserved = TRUE)

# ---------------------------------------------------------------------------
# 1. CDC -- "COVID-19 Vaccinations in the United States, County" (8xkx-amqh)
#    All columns, Texas rows only (Recip_State = 'TX'), every report date.
# ---------------------------------------------------------------------------
msg("CDC county vaccination file (Texas rows)")
d <- file.path(DIR_RAW, "cdc_county_vax")
fetch("https://data.cdc.gov/api/views/8xkx-amqh.json",
      file.path(d, "cdc_8xkx-amqh_metadata.json"), "cdc_county_vax",
      note = "Dataset metadata and column dictionary")
fetch(paste0("https://data.cdc.gov/resource/8xkx-amqh.csv",
             "?$where=", enc("recip_state='TX'"),
             "&$order=", enc("date,fips"),
             "&$limit=500000"),
      file.path(d, "cdc_8xkx-amqh_TX.csv"), "cdc_county_vax",
      note = "SODA export: all columns, recip_state='TX', ordered by date,fips")

# ---------------------------------------------------------------------------
# 2. Texas DSHS "COVID-19 Vaccine Data by County" workbook -- Internet Archive
#    DSHS overwrote one workbook in place each day and has since removed it,
#    so the only surviving copies of the original files are Wayback Machine
#    captures. The capture index (CDX) is saved first; every distinct capture
#    (unique content digest, HTTP 200) is then downloaded unmodified ("id_").
# ---------------------------------------------------------------------------
msg("DSHS vaccine workbooks (Wayback Machine captures)")
d <- file.path(DIR_RAW, "dshs_vax_wayback")
cdx_base <- "http://web.archive.org/cdx/search/cdx"
cdx_fl <- "&fl=timestamp,original,statuscode,mimetype,length,digest&filter=statuscode:200&collapse=digest"
cdx_queries <- c(
  texas_gov = paste0(cdx_base, "?url=", enc("dshs.texas.gov/immunize/covid19/COVID-19-Vaccine-Data-by-County.xls"),
                     "&matchType=prefix", cdx_fl),
  state_tx_us = paste0(cdx_base, "?url=", enc("dshs.state.tx.us/immunize/covid19/COVID-19-Vaccine-Data-by-County.xls"),
                       "&matchType=prefix", cdx_fl),
  new_site = paste0(cdx_base, "?url=", enc("dshs.texas.gov/sites/default/files/LIDS-Immunize-COVID19/COVID Dashboard/"),
                    "&matchType=prefix", cdx_fl)
)
caps <- list()
for (tag in names(cdx_queries)) {
  f <- file.path(d, sprintf("cdx_%s.txt", tag))
  fetch(cdx_queries[[tag]], f, "dshs_vax_wayback",
        note = "Wayback Machine CDX capture index (one row per distinct capture)")
  x <- readLines(f, warn = FALSE)
  x <- x[nzchar(x)]
  if (!length(x)) next
  p <- do.call(rbind, strsplit(x, " ", fixed = TRUE))
  caps[[tag]] <- data.frame(tag = tag, timestamp = p[, 1], original = p[, 2],
                            mimetype = p[, 4], digest = p[, 6], stringsAsFactors = FALSE)
}
caps <- do.call(rbind, caps)
# Keep spreadsheets whose URL is the county workbook (the new-site prefix also
# returns ZIP-code workbooks, which are not used).
caps <- caps[grepl("spreadsheet|excel", caps$mimetype) &
               grepl("County", caps$original, ignore.case = TRUE) &
               !grepl("Zip", caps$original, ignore.case = TRUE), ]
caps <- caps[order(caps$timestamp), ]
caps <- caps[!duplicated(caps$digest), ]
msg("  %d distinct workbook captures, %s to %s", nrow(caps),
    substr(min(caps$timestamp), 1, 8), substr(max(caps$timestamp), 1, 8))
for (i in seq_len(nrow(caps))) {
  dest <- file.path(d, "workbooks", sprintf("dshs_vax_%s.xlsx", caps$timestamp[i]))
  st <- fetch(sprintf("https://web.archive.org/web/%sid_/%s", caps$timestamp[i], caps$original[i]),
              dest, "dshs_vax_wayback", zip_container = TRUE,
              note = sprintf("Wayback capture %s of %s (digest %s)",
                             caps$timestamp[i], caps$original[i], caps$digest[i]))
  if (identical(st, "downloaded")) Sys.sleep(1.5)   # be polite to the archive
}

# ---------------------------------------------------------------------------
# 3. Daily CSV copies of the DSHS workbook's "By County" sheet (third party)
#    github.com/rdmurphy/tx-covid-vaccine-data (MIT licence) saved that sheet
#    as CSV each time DSHS updated the workbook, 2020-12-29 to 2021-10-06.
#    Pinned to one commit so the inputs cannot change underneath the analysis.
# ---------------------------------------------------------------------------
msg("DSHS 'By County' daily snapshots (GitHub archive, pinned commit)")
d <- file.path(DIR_RAW, "dshs_vax_github")
GH_REPO <- "rdmurphy/tx-covid-vaccine-data"
GH_SHA  <- "375efdd971a511cc826e05d5d8f6fd86191a2ada"
gh_raw  <- sprintf("https://raw.githubusercontent.com/%s/%s", GH_REPO, GH_SHA)
tree_file <- file.path(d, sprintf("tree_%s.json", substr(GH_SHA, 1, 12)))
fetch(sprintf("https://api.github.com/repos/%s/git/trees/%s?recursive=1", GH_REPO, GH_SHA),
      tree_file, "dshs_vax_github", note = "Git tree listing at the pinned commit")
fetch(paste0(gh_raw, "/README.md"), file.path(d, "README.md"), "dshs_vax_github",
      note = "Archive description by its maintainer")
fetch(paste0(gh_raw, "/LICENSE"), file.path(d, "LICENSE"), "dshs_vax_github",
      note = "MIT licence of the archive")
tree <- fromJSON(tree_file)$tree
snaps <- tree$path[grepl("^distribution/snapshots/[0-9]{4}-[0-9]{2}-[0-9]{2}[.]csv$", tree$path)]
msg("  %d county snapshots, %s to %s", length(snaps),
    sub(".*/(.*)[.]csv", "\\1", min(snaps)), sub(".*/(.*)[.]csv", "\\1", max(snaps)))
for (p in snaps) {
  fetch(paste0(gh_raw, "/", p), file.path(d, "snapshots", basename(p)), "dshs_vax_github",
        note = "CSV copy of the DSHS workbook 'By County' sheet; file name = workbook modified date (Central)")
}

# ---------------------------------------------------------------------------
# 4. Texas DSHS reported COVID-19 cases by county (still hosted by DSHS)
# ---------------------------------------------------------------------------
msg("DSHS case workbooks and data notes")
d <- file.path(DIR_RAW, "dshs_cases")
dshs <- "https://www.dshs.texas.gov/sites/default/files/chs/data/COVID/"
case_files <- c(
  "Texas COVID-19 New Confirmed Cases by County.xlsx" = "New confirmed cases over time by county, 2020-03-06 to 2023-05-10",
  "Texas COVID-19 New Probable Cases by County.xlsx"  = "New probable cases over time by county, 2020-03-06 to 2023-05-10",
  "COVID-19 Data Definitions.docx" = "DSHS data definitions",
  "COVID-19 Data Sources.docx" = "DSHS data sources (final vs provisional years)",
  "COVID-19 Additional Data Notes & Dashboard Changes over Time.docx" = "DSHS additional data notes",
  "COVID-19 Case Notes - 2020.docx" = "DSHS case and lab backlog notes 2020",
  "COVID-19 Case Notes - 2021.docx" = "DSHS case and lab backlog notes 2021",
  "COVID-19 Case Notes - 2022.docx" = "DSHS case and lab backlog notes 2022",
  "COVID-19 Case Notes - 2023.docx" = "DSHS case and lab backlog notes 2023"
)
url_path <- function(f) gsub("&", "%26", utils::URLencode(f), fixed = TRUE)
for (f in names(case_files)) {
  fetch(paste0(dshs, url_path(f)), file.path(d, gsub("[ &]+", "_", f)), "dshs_cases",
        note = case_files[[f]], zip_container = TRUE)
}

# ---------------------------------------------------------------------------
# 5. Census Bureau population estimates, Vintage 2025, Texas counties by age
# ---------------------------------------------------------------------------
msg("Census population estimates (Vintage 2025)")
d <- file.path(DIR_RAW, "census_pep")
pep <- "https://www2.census.gov/programs-surveys/popest/"
fetch(paste0(pep, "datasets/2020-2025/counties/asrh/cc-est2025-syasex-48.csv"),
      file.path(d, "cc-est2025-syasex-48.csv"), "census_pep",
      note = "County resident population by single year of age and sex, Texas")
fetch(paste0(pep, "datasets/2020-2025/counties/asrh/cc-est2025-agesex-48.csv"),
      file.path(d, "cc-est2025-agesex-48.csv"), "census_pep",
      note = "County resident population by selected age groups and sex, Texas")
for (f in c("CC-EST2025-SYASEX.pdf", "CC-EST2025-AGESEX.pdf")) {
  fetch(paste0(pep, "technical-documentation/file-layouts/2020-2025/", f),
        file.path(d, f), "census_pep", note = "File layout")
}

# ---------------------------------------------------------------------------
# 6. American Community Survey 2019-2023 five-year estimates (table-based
#    summary file; national files, filtered to Texas counties in step 03)
# ---------------------------------------------------------------------------
msg("ACS 2019-2023 five-year tables")
d <- file.path(DIR_RAW, "census_acs")
acs <- "https://www2.census.gov/programs-surveys/acs/summary_file/2023/table-based-SF/"
for (tb in c("b19013", "b01001", "b01002")) {
  fetch(sprintf("%sdata/5YRData/acsdt5y2023-%s.dat", acs, tb),
        file.path(d, sprintf("acsdt5y2023-%s.dat", tb)), "census_acs",
        note = sprintf("ACS 2019-2023 5-year detailed table %s, all geographies", toupper(tb)),
        timeout = 3600)
}
for (f in c("Geos20235YR.txt", "ACS20235YR_Table_Shells.txt", "README.txt")) {
  fetch(paste0(acs, "documentation/", f), file.path(d, f), "census_acs",
        note = "ACS table-based summary file documentation")
}

# ---------------------------------------------------------------------------
# 7. Census county boundaries and the Census county adjacency file
# ---------------------------------------------------------------------------
msg("Census county boundaries and adjacency file")
d <- file.path(DIR_RAW, "census_geo")
zipf <- file.path(d, "cb_2021_us_county_500k.zip")
fetch("https://www2.census.gov/geo/tiger/GENZ2021/shp/cb_2021_us_county_500k.zip",
      zipf, "census_geo", note = "2021 cartographic boundary file, counties, 1:500,000")
fetch("https://www2.census.gov/geo/docs/reference/county_adjacency/county_adjacency2023.txt",
      file.path(d, "county_adjacency2023.txt"), "census_geo",
      note = "Census county adjacency file (2023)")
shp_dir <- file.path(d, "cb_2021_us_county_500k")
if (!dir.exists(shp_dir)) {
  dir.create(shp_dir)
  utils::unzip(zipf, exdir = shp_dir)
}

# ---------------------------------------------------------------------------
# 8. A county health department source, inspected but not used in the models:
#    Harris County Public Health "COVID-19 Data Hub" tables (ArcGIS feature
#    services). Saved so the inventory's description of them can be checked.
# ---------------------------------------------------------------------------
msg("Harris County Public Health data hub tables")
d <- file.path(DIR_RAW, "county_hd_harris")
hc <- "https://services.arcgis.com/su8ic9KbA7PYVxPS/ArcGIS/rest/services/"
hc_tables <- c(Download_DSHS_COVID_Vaccination_Summary = "DSHS totals for Harris County (single latest row)",
               Download_DSHS_COVID_Vaccination_for_Ages_12_and_Up = "DSHS percentages for Harris County (single latest row)",
               Download_COVID_Vaccination_Progress_Overall = "Weekly cumulative percentage vaccinated, Harris County",
               Download_COVID_Vaccination_Progress_By_Age_Groups = "Weekly cumulative percentage vaccinated by age band, Harris County")
for (tb in names(hc_tables)) {
  fetch(paste0(hc, tb, "/FeatureServer/0?f=json"), file.path(d, paste0(tb, "_layer.json")),
        "county_hd_harris", note = paste("Layer definition:", hc_tables[[tb]]))
  fetch(paste0(hc, tb, "/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=false&f=json"),
        file.path(d, paste0(tb, "_rows.json")), "county_hd_harris", note = hc_tables[[tb]])
}

# ---------------------------------------------------------------------------
# 9. DSHS news releases that set out who was eligible for vaccination and from
#    when. DSHS has reorganised its website and the original addresses refuse
#    automated requests, so each page is taken from the Wayback Machine capture
#    made on or just after the day of the release (pinned by its timestamp).
#    Used only to document the eligibility timeline; no numbers come from them.
# ---------------------------------------------------------------------------
msg("DSHS news releases on vaccine eligibility (Wayback Machine captures)")
d <- file.path(DIR_RAW, "dshs_news")
news <- data.frame(
  stamp = c("20201214195739", "20201221215553", "20201229163105", "20210303194310",
            "20210310205809", "20210323154855", "20210512222231"),
  url = c("https://dshs.texas.gov/news/releases/2020/20201214.aspx",
          "https://dshs.texas.gov/news/releases/2020/20201221.aspx",
          "https://dshs.texas.gov/news/releases/2020/20201228.aspx",
          "https://dshs.texas.gov/news/releases/2021/20210303.aspx",
          "https://dshs.texas.gov/news/releases/2021/20210310.aspx",
          "https://www.dshs.texas.gov/news/releases/2021/20210323.aspx",
          "https://dshs.texas.gov/news/releases/2021/20210512.aspx"),
  stringsAsFactors = FALSE)
for (i in seq_len(nrow(news))) {
  dest <- file.path(d, sprintf("dshs_release_%s.html", sub("[.]aspx$", "", basename(news$url[i]))))
  st <- fetch(sprintf("https://web.archive.org/web/%sid_/%s", news$stamp[i], news$url[i]), dest, "dshs_news",
              note = sprintf("DSHS news release, Wayback capture %s of %s", news$stamp[i], news$url[i]))
  if (identical(st, "downloaded")) Sys.sleep(1.5)
}

# ---------------------------------------------------------------------------
v <- verify_manifest()
m <- read_manifest()
msg("Manifest: %d files, %.1f MB; all present: %s; all checksums match: %s",
    nrow(m), sum(m$bytes) / 1e6, all(v$present), all(v$sha256_matches))
print(aggregate(cbind(files = 1, MB = round(m$bytes / 1e6, 2)) ~ source_id, data = m, FUN = sum))
