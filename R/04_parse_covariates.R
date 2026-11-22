# 04_parse_covariates.R -- denominators, county characteristics, cases, neighbours.
#
#   Rscript --vanilla R/04_parse_covariates.R
#
# Inputs  : data/raw/census_pep, census_acs, dshs_cases, census_geo
# Outputs : data/derived/pop_county_year.csv      Census population estimates by age cut
#           data/derived/acs_county.csv           ACS 2019-2023 county characteristics
#           data/derived/cases_county_daily.csv   DSHS reported cases by county and day
#           data/derived/cases_notes.csv          undated / no-county case totals
#           data/derived/tx_counties.gpkg         county polygons (EPSG:3083)
#           data/derived/tx_adjacency_edges.csv   neighbour pairs used by the models
#           outputs/tables/verify_10_adjacency.csv, verify_11_acs_vs_pep_age.csv

source("R/_common.R")
suppressMessages({library(data.table); library(readxl); library(sf); library(spdep)})
options(width = 200, scipen = 999)
lk <- fread(file.path(DIR_DERIVED, "county_lookup.csv"), colClasses = list(character = "fips"))
lk[, key := county_key(county)]

# ---------------------------------------------------------------------------
# 1. Census population estimates (Vintage 2025), single year of age
#    YEAR codes (file layout CC-EST2025-SYASEX): 1 = 4/1/2020 estimates base,
#    2..7 = July 1 of 2020..2025. AGE 0..85, where 85 means 85 and over.
# ---------------------------------------------------------------------------
sya <- fread(file.path(DIR_RAW, "census_pep/cc-est2025-syasex-48.csv"),
             colClasses = list(character = c("STATE", "COUNTY")))
sya[, fips := paste0(STATE, COUNTY)]
stopifnot(sya[, uniqueN(fips)] == 254, setequal(unique(sya$YEAR), 1:7), sya[, max(AGE)] == 85)
pop <- sya[YEAR >= 2, .(pop_total = sum(TOT_POP),
                        pop5  = sum(TOT_POP[AGE >= 5]),
                        pop12 = sum(TOT_POP[AGE >= 12]),
                        pop16 = sum(TOT_POP[AGE >= 16]),
                        pop17 = sum(TOT_POP[AGE >= 17]),
                        pop18 = sum(TOT_POP[AGE >= 18]),
                        pop65 = sum(TOT_POP[AGE >= 65])),
           by = .(fips, year = 2018L + YEAR)]   # YEAR 2 -> 2020, 3 -> 2021, ...
setorder(pop, fips, year)
fwrite(pop, file.path(DIR_DERIVED, "pop_county_year.csv"))
msg("Population estimates: Texas 16+ on 1 July 2021 = %s; total = %s",
    format(pop[year == 2021, sum(pop16)], big.mark = ","), format(pop[year == 2021, sum(pop_total)], big.mark = ","))

# ---------------------------------------------------------------------------
# 2. ACS 2019-2023 five-year estimates: median household income (B19013),
#    age composition (B01001), median age (B01002). Texas counties only.
#    Negative "jam" values (e.g. -666666666) mean the estimate was not published.
# ---------------------------------------------------------------------------
read_acs <- function(tb) {
  x <- fread(file.path(DIR_RAW, sprintf("census_acs/acsdt5y2023-%s.dat", tb)), sep = "|")
  x <- x[grepl("^0500000US48[0-9]{3}$", GEO_ID)]
  x[, fips := sub("^0500000US", "", GEO_ID)]
  stopifnot(nrow(x) == 254)
  x
}
inc <- read_acs("b19013")[, .(fips, med_hh_income = as.numeric(B19013_E001), med_hh_income_moe = as.numeric(B19013_M001))]
inc[med_hh_income < 0, `:=`(med_hh_income = NA_real_, med_hh_income_moe = NA_real_)]
inc[med_hh_income_moe < 0, med_hh_income_moe := NA_real_]
ma <- read_acs("b01002")[, .(fips, median_age = as.numeric(B01002_E001), median_age_moe = as.numeric(B01002_M001))]
b <- read_acs("b01001")
e <- function(i) rowSums(as.matrix(b[, sprintf("B01001_E%03d", i), with = FALSE]))
agec <- data.table(fips = b$fips,
                   acs_pop = e(1),
                   acs_under18 = e(c(3:6, 27:30)),
                   acs_18_64 = e(c(7:19, 31:43)),
                   acs_65plus = e(c(20:25, 44:49)))
stopifnot(all(agec[, acs_under18 + acs_18_64 + acs_65plus] == agec$acs_pop))
agec[, `:=`(pct_65plus = 100 * acs_65plus / acs_pop,
            pct_under18 = 100 * acs_under18 / acs_pop,
            pct_65plus_of_adults = 100 * acs_65plus / (acs_18_64 + acs_65plus))]
acs <- Reduce(function(x, y) merge(x, y, by = "fips"), list(lk[, .(fips, county)], inc, ma, agec))
msg("ACS: counties without a published median household income: %s",
    paste(acs[is.na(med_hh_income), county], collapse = ", "))

# ---------------------------------------------------------------------------
# 3. County polygons and neighbours
# ---------------------------------------------------------------------------
shp <- st_read(file.path(DIR_RAW, "census_geo/cb_2021_us_county_500k/cb_2021_us_county_500k.shp"), quiet = TRUE)
tx <- shp[shp$STATEFP == STATE_FIPS, c("GEOID", "NAME", "ALAND", "AWATER")]
names(tx)[1:2] <- c("fips", "county")
tx <- tx[order(tx$fips), ]
stopifnot(nrow(tx) == 254, identical(tx$fips, sort(lk$fips)))
tx <- st_transform(tx, 3083)                # NAD83 / Texas Centric Albers Equal Area
tx <- st_make_valid(tx)
nb <- poly2nb(tx, queen = TRUE, row.names = tx$fips)
edges <- rbindlist(lapply(seq_along(nb), function(i) {
  j <- nb[[i]]; j <- j[j > 0]
  data.table(fips = tx$fips[i], nb_fips = tx$fips[j])
}))
# Cross-check against the Census Bureau's county adjacency file
adj <- fread(file.path(DIR_RAW, "census_geo/county_adjacency2023.txt"), sep = "|", colClasses = "character")
setnames(adj, c("name", "fips", "nb_name", "nb_fips"))
adj <- adj[substr(fips, 1, 2) == STATE_FIPS & substr(nb_fips, 1, 2) == STATE_FIPS & fips != nb_fips]
e1 <- edges[, paste(fips, nb_fips)]; e2 <- adj[, paste(fips, nb_fips)]
only_poly <- setdiff(e1, e2); only_census <- setdiff(e2, e1)
chk <- data.table(source = c("polygons (queen contiguity)", "Census adjacency file", "in polygons only", "in Census file only"),
                  directed_pairs = c(length(e1), length(e2), length(only_poly), length(only_census)),
                  detail = c("", "", paste(only_poly, collapse = "; "), paste(only_census, collapse = "; ")))
fwrite(chk, file.path(DIR_TAB, "verify_10_adjacency.csv"))
print(chk)
# Neighbour definition used in the models: the Census adjacency file (it also
# records pairs joined only across water), symmetric by construction.
edges_use <- unique(rbind(adj[, .(fips, nb_fips)], adj[, .(fips = nb_fips, nb_fips = fips)]))
setorder(edges_use, fips, nb_fips)
stopifnot(edges_use[, uniqueN(fips)] == 254)
fwrite(edges_use, file.path(DIR_DERIVED, "tx_adjacency_edges.csv"))
msg("Neighbours: %d undirected pairs; neighbours per county min %d, median %g, max %d",
    nrow(edges_use) / 2, edges_use[, .N, by = fips][, min(N)], edges_use[, .N, by = fips][, median(N)],
    edges_use[, .N, by = fips][, max(N)])
if (file.exists(file.path(DIR_DERIVED, "tx_counties.gpkg"))) file.remove(file.path(DIR_DERIVED, "tx_counties.gpkg"))
st_write(tx, file.path(DIR_DERIVED, "tx_counties.gpkg"), quiet = TRUE)

# Kenedy County's median household income is not published in this ACS release
# (too few sample households). It is filled with the median of its neighbours'
# values and flagged, so that the county can stay in the model.
acs[, income_imputed := is.na(med_hh_income)]
for (f in acs[income_imputed == TRUE, fips]) {
  nbv <- acs[fips %in% edges_use[fips == f, nb_fips], med_hh_income]
  acs[fips == f, med_hh_income := median(nbv, na.rm = TRUE)]
  msg("  income for %s filled with neighbour median %.0f (neighbours: %s)", acs[fips == f, county],
      acs[fips == f, med_hh_income], paste(acs[fips %in% edges_use[fips == f, nb_fips], county], collapse = ", "))
}
fwrite(acs, file.path(DIR_DERIVED, "acs_county.csv"))
# ACS age shares against the population-estimates programme (same concept, different source)
cmp <- merge(acs[, .(fips, county, acs_pct65 = pct_65plus)],
             pop[year == 2021, .(fips, pep_pct65 = 100 * pop65 / pop_total, pop_total)], by = "fips")
cmp[, diff := acs_pct65 - pep_pct65]
fwrite(cmp, file.path(DIR_TAB, "verify_11_acs_vs_pep_age.csv"))
msg("ACS vs population-estimates share aged 65+: correlation %.4f; median abs difference %.2f points; max %.2f (%s)",
    cor(cmp$acs_pct65, cmp$pep_pct65), median(abs(cmp$diff)), max(abs(cmp$diff)), cmp[which.max(abs(diff)), county])

# ---------------------------------------------------------------------------
# 4. DSHS reported cases by county and day (confirmed and probable)
#    2020 and 2021 sheets hold DSHS's final counts; 2022 and 2023 are provisional.
#    Column headers are dates (Excel serials in 2020-21, text dates in 2022-23),
#    plus "Unknown Date" and "Total" columns in the final years.
# ---------------------------------------------------------------------------
read_cases <- function(path, type) {
  rbindlist(lapply(excel_sheets(path), function(s) {
    x <- as.data.frame(suppressMessages(read_excel(path, sheet = s, col_names = FALSE, col_types = "text",
                                                   .name_repair = "minimal")), stringsAsFactors = FALSE)
    h <- which(trimws(x[[1]]) == "County")[1]
    hdr <- trimws(unlist(x[h, ]))
    body <- x[(h + 1):nrow(x), , drop = FALSE]
    body <- body[!is.na(body[[1]]) & !grepl("^Additional information", body[[1]]), , drop = FALSE]
    is_serial <- grepl("^[0-9]{5}$", hdr)
    is_text <- grepl("^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$", hdr)
    dates <- rep(as.Date(NA), length(hdr))
    dates[is_serial] <- excel_date(hdr[is_serial])
    dates[is_text] <- as.Date(hdr[is_text], format = "%m/%d/%Y")
    dc <- which(!is.na(dates))
    long <- data.table(name = rep(trimws(body[[1]]), times = length(dc)),
                       date = rep(dates[dc], each = nrow(body)),
                       n = suppressWarnings(as.numeric(unlist(body[, dc]))))
    long[, `:=`(type = type, sheet = s)]
    unk <- which(hdr == "Unknown Date")
    if (length(unk)) attr(long, "unknown") <- data.table(name = trimws(body[[1]]), type = type, sheet = s,
                                                         unknown_date = suppressWarnings(as.numeric(body[[unk]])))
    long
  }))
}
read_unknown <- function(path, type) {
  rbindlist(lapply(excel_sheets(path), function(s) {
    x <- as.data.frame(suppressMessages(read_excel(path, sheet = s, col_names = FALSE, col_types = "text",
                                                   .name_repair = "minimal")), stringsAsFactors = FALSE)
    h <- which(trimws(x[[1]]) == "County")[1]
    hdr <- trimws(unlist(x[h, ]))
    unk <- which(hdr == "Unknown Date")
    if (!length(unk)) return(NULL)
    body <- x[(h + 1):nrow(x), , drop = FALSE]
    body <- body[!is.na(body[[1]]) & !grepl("^Additional information", body[[1]]), , drop = FALSE]
    data.table(name = trimws(body[[1]]), type = type, year = as.integer(sub(".* ", "", s)),
               unknown_date = suppressWarnings(as.numeric(body[[unk]])))
  }))
}
f_conf <- file.path(DIR_RAW, "dshs_cases/Texas_COVID-19_New_Confirmed_Cases_by_County.xlsx")
f_prob <- file.path(DIR_RAW, "dshs_cases/Texas_COVID-19_New_Probable_Cases_by_County.xlsx")
cs <- rbind(read_cases(f_conf, "confirmed"), read_cases(f_prob, "probable"))
cs[, key := county_key(name)]
stopifnot(all(lk$key %in% cs$key))
cty <- merge(cs, lk[, .(key, fips, county)], by = "key")
cty <- dcast(cty, fips + county + date ~ type, value.var = "n", fun.aggregate = sum)
setnames(cty, c("confirmed", "probable"), c("new_confirmed", "new_probable"))
setorder(cty, fips, date)
stopifnot(cty[, .N, by = fips][, uniqueN(N)] == 1)
fwrite(cty, file.path(DIR_DERIVED, "cases_county_daily.csv"))

unk <- rbind(read_unknown(f_conf, "confirmed"), read_unknown(f_prob, "probable"))
unk[, key := county_key(name)]
yr <- cs[, .(dated_all_rows = sum(n[key == "TOTAL"], na.rm = TRUE),
             dated_counties = sum(n[key %in% lk$key], na.rm = TRUE),
             dated_incomplete_address = sum(n[key == "INCOMPLETEADDRESS"], na.rm = TRUE),
             negative_county_days = sum(n[key %in% lk$key] < 0, na.rm = TRUE)),
         by = .(type, year = as.integer(format(date, "%Y")))]
yr <- merge(yr, unk[key == "TOTAL", .(type, year, unknown_date_statewide = unknown_date)], by = c("type", "year"), all.x = TRUE)
yr <- merge(yr, unk[key %in% lk$key, .(unknown_date_counties = sum(unknown_date, na.rm = TRUE)), by = .(type, year)],
            by = c("type", "year"), all.x = TRUE)
yr[, pct_no_county := round(100 * dated_incomplete_address / dated_all_rows, 2)]
yr[, pct_unknown_date := round(100 * unknown_date_statewide / (dated_all_rows + unknown_date_statewide), 2)]
setorder(yr, type, year)
fwrite(yr, file.path(DIR_DERIVED, "cases_notes.csv"))
print(yr)
msg("Cases: %s to %s; %d county-days", min(cty$date), max(cty$date), nrow(cty))
