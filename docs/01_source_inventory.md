# Source inventory, study period and outcome definition

Bayesian spatiotemporal small-area analysis of COVID-19 vaccination coverage across Texas counties.

Statements about the data were checked against downloaded files. A few statements rest on other material and say
so where they occur: a news report (how county is assigned), press reports (the day Phase 1B vaccination began) and
search-engine text of two local health departments' reports. Each raw file is listed in
[data/raw/MANIFEST.csv](../data/raw/MANIFEST.csv) with its URL, retrieval time, size and SHA-256.
The checks are in [R/03_verify_vaccination.R](../R/03_verify_vaccination.R); their full output is
[logs/03_verify_vaccination.log](../logs/03_verify_vaccination.log) and the tables named `verify_*.csv` in
[outputs/tables](../outputs/tables). Sources were retrieved on 20 November 2026; the DSHS news releases (source I)
on 21 November 2026.

## 1. What the verification found

1. **The proposed outcome (first dose, adults 18+, by county and month) cannot be built for the main rollout.**
   CDC's county file is the only source with an 18+ count, and it has no Texas county data before
   22 October 2021: all 254 county rows are zero for every report date from 13 December 2020 to 21 October 2021.
2. **Texas DSHS's own county workbook is the only record of the rollout, and it survives only in archives.**
   DSHS overwrote one workbook each day and has removed it from its site (the old address now returns "not found").
   Forty-six editions (19 December 2020 to 10 May 2023) are in the Internet Archive. Forty of them carry a usable
   county-by-age sheet whose youngest adult band is 16-49, so the adult group the records support is **16+**, not 18+.
3. **County counts before 15 April 2021 are incomplete, by a different amount in each county.** Until then
   5-11% of vaccinated people sat in an "Other" row (county unknown). In the edition of 15 April 2021 that row fell
   by 662,780 people in one day and county counts jumped by a matching amount. The jump was 1% of the previous
   count in Harris County, 19% in Tarrant and 25% in Denton. Month-by-month county uptake for January to April 2021
   can therefore not be recovered from these files without assumptions about where the unassigned people lived.
   The main analysis makes none. A separate extension, [03_early_rollout.md](03_early_rollout.md), states one,
   tests it and reports how much depends on it.
4. **CDC and DSHS county counts are not interchangeable.** On the same dates CDC's Texas county total is 1.7% to 3.3%
   above DSHS's, the gap changes over time, and it is very uneven: +36% in Bell County (Fort Hood), +16% in Wichita,
   +8% in El Paso and Bexar, and lower than DSHS in others. CDC also removed 297,634 people from Texas counties in a
   single revision on 3 August 2022.
5. **In 16 counties the recorded number of vaccinated adults exceeds the adult population**, in several by a wide
   margin and increasingly so in 2022-2023 (Maverick 234%, Reeves 229%, Webb 189%, Brooks 184% by May 2023).
   Fourteen are in South Texas or along the Rio Grande; two are in the far-west oil field. Their records cannot be
   read as coverage of residents.
6. **The archived copies are faithful.** A third-party archive of daily CSV copies matches the original workbooks
   cell for cell on all 21 dates where both exist (5,334 county counts), and a table still served by Harris County
   Public Health reproduces the final workbook's Harris County count exactly (3,588,122).

## 2. Decisions that follow

| Item | Proposed | Used | Why |
|---|---|---|---|
| Age group | 18+ | **16+** | DSHS county-by-age bands are 12-15, 16-49, 50-64, 65-79, 80+. An 18+ county count exists only in the CDC file from 22 Oct 2021, and that file does not agree with DSHS. Residents aged 16-17 are 3.7% of Texans aged 16+. |
| Dose definition | first dose | **unchanged**: people with at least one recorded dose | Field "People Vaccinated with at least One Dose". A single-dose Janssen recipient counts once. |
| Time unit | calendar months | **intervals between surviving DSHS editions**, 26-35 days long to February 2022, then 94, 174 and 170 days; uptake is reported **per 30 days** | Editions with county-by-age counts exist only on the dates the Internet Archive happened to capture. The model uses a complementary log-log link with the interval length as an offset, so every estimate is on a common per-30-day scale. |
| Study period, modelled uptake | not fixed | **25 May 2021 to 9 May 2023** (12 intervals) | 24 May 2021 is the first date after which county counts stop being re-assigned between counties (no county's adult count falls in any of the next seven editions). |
| Study period, recorded coverage | not fixed | **baseline 24 May 2021, then every edition to 9 May 2023**; the rollout before the baseline enters as coverage reached by 24 May 2021 | See finding 3. |
| First five months, by county | not fixed | **kept out of the main analysis; reconstructed separately** in six intervals from 14 Dec 2020 to 24 May 2021 ([03_early_rollout.md](03_early_rollout.md)) | The reconstruction needs an assumption about the recipients who had no county (finding 3). Its results are reported apart so that the main results do not rest on it. |
| Counties | 254 | **238 in the models**; all 254 in maps, the other 16 flagged | See finding 5. |
| Denominator | Census estimates | **Census Bureau Vintage 2025 estimate of residents aged 16+ on 1 July 2021**, held fixed | Matches the age group, is based on the 2020 Census, and sits in the middle of the rollout. DSHS and CDC used 2019 estimates (2.7% lower statewide). |
| Role of the CDC file | primary candidate | **cross-check only** | Findings 1 and 4. |

Interval grid (an edition dated *D* holds records through 11:59 pm on *D* - 1):

| k | Records from | to | Days | New first doses, 16+ (all counties) | Recorded 16+ coverage at end (all counties) |
|---|---|---|---|---|---|
| baseline | | 24 May 2021 | | | 52.5% |
| 1 | 25 May 2021 | 22 Jun 2021 | 29 | 949,237 | 56.6% |
| 2 | 23 Jun 2021 | 21 Jul 2021 | 29 | 642,359 | 59.4% |
| 3 | 22 Jul 2021 | 21 Aug 2021 | 31 | 1,288,098 | 65.0% |
| 4 | 22 Aug 2021 | 23 Sep 2021 | 33 | 912,048 | 68.9% |
| 5 | 24 Sep 2021 | 25 Oct 2021 | 32 | 436,759 | 70.8% |
| 6 | 26 Oct 2021 | 20 Nov 2021 | 26 | 363,638 | 72.4% |
| 7 | 21 Nov 2021 | 21 Dec 2021 | 31 | 418,625 | 74.2% |
| 8 | 22 Dec 2021 | 21 Jan 2022 | 31 | 417,417 | 76.0% |
| 9 | 22 Jan 2022 | 25 Feb 2022 | 35 | 270,529 | 77.2% |
| 10 | 26 Feb 2022 | 30 May 2022 | 94 | 400,641 | 78.9% |
| 11 | 31 May 2022 | 20 Nov 2022 | 174 | 490,828 | 81.1% |
| 12 | 21 Nov 2022 | 9 May 2023 | 170 | 284,085 | 82.3% |

No edition was captured between 26 February and 31 May 2022, which forces interval 10. Intervals 11 and 12 pool
editions on purpose: by mid-2022 the net change in most small counties was smaller than routine record corrections
(in the last four editions 35 to 48 counties show a net fall in their adult count). Two sensitivity grids are built
alongside the main one: one adds 23 April to 24 May 2021, one keeps every near-monthly edition after May 2022.

## 3. Source inventory

### A. Texas DSHS, "COVID-19 Vaccine Data by County" workbook (primary source)

| | |
|---|---|
| Publisher | Texas Department of State Health Services, from the Texas Immunization Registry (ImmTrac2) |
| Original addresses | `https://www.dshs.texas.gov/immunize/covid19/COVID-19-Vaccine-Data-by-County.xls` (also under `dshs.state.tx.us`); from late 2022 `https://www.dshs.texas.gov/sites/default/files/LIDS-Immunize-COVID19/COVID%20Dashboard/...` with dated file names. All now removed from the DSHS site. |
| Where obtained | Internet Archive Wayback Machine, unmodified captures (`https://web.archive.org/web/<timestamp>id_/<address>`). Capture index saved as `data/raw/dshs_vax_wayback/cdx_*.txt`; files in `data/raw/dshs_vax_wayback/workbooks/`. |
| Editions | 46 distinct editions, "as of" 19 Dec 2020 to 10 May 2023 ([verify_01](../outputs/tables/verify_01_dshs_workbook_index.csv)). The "This worksheet is current as of" cell equals the workbook's own last-modified date in every edition that has both. |
| Geography | County of residence of the recipient, 254 counties, plus a state row and an "Other" row ("recipient's county of residence is unknown or address is out-of-state"). |
| Sheets and variables used | **By County**: `County Name`, `People Vaccinated with at least One Dose`, `People Fully Vaccinated`, `Vaccine Doses Administered`, `Population, 16+`, `Population, 65+`, `Population 12+`. **By County, Age** (from 2 Mar 2021): `County Name`, `Age Group`/`Agegrp`, `People Vaccinated with at least One Dose`. **By Vaccination Date** (statewide, from 25 May 2021): `Vaccination Date`, `People Vaccinated with at least One Dose`. **About the Data**: definitions and as-of date. |
| Definitions (workbook text) | One dose: "the number of people who have received at least one dose of COVID-19 vaccine". Counts are "aggregated by the recipient's county of residence". Records are "as of 11:59 pm the previous night"; providers have 24 hours to report. |
| Denominators printed in the file | Changed three times: Texas Demographic Center 2019 estimates (to mid-January 2021, 16+ = 22,448,443), TDC 2021 projections (29 Jan 2021, 23,418,623), Census Bureau 2019 estimates (from 13 Feb 2021, 22,421,178; 12+ = 24,068,624). |
| Age bands | 16-49, 50-64, 65-79, 80+, Unknown from the first age sheet; 12-15 first appears in the 25 May 2021 edition, 5-11 on 12 Nov 2021, 6 months-4 years on 11 Jul 2022 ([verify_11](../outputs/tables/verify_11_age_bands_first_seen.csv)). Age appears to be age at vaccination: the 12-15 band keeps growing instead of emptying as people age. The workbook notes do not say. |
| Suppression | None. Counts as small as 41 (Loving County) are printed. |

Problems found in this source:

- **Late county assignment.** See finding 3 and section 4.4.
- **One faulty daily edition** (12 March 2021: the "at least one dose" and "fully vaccinated" columns are
  interchanged, so the one-dose total appears to fall by 2.15 million and return the next day) and one at the end
  of the daily archive (6 October 2021: 271,000 people moved from counties to "Other", not present in the next
  original edition). Neither is used.
- **One corrupted age sheet** (7 May 2021 edition: race rows pasted into the age sheet; its sums disagree with the
  county totals in 46 counties). Not used.
- **Excel damaged two age labels.** From November 2021 "5-11" and "12-15" are stored as dates (11 May, 15 December).
  The parser restores them.
- **"Other" keeps growing** after the April 2021 fix, from 1.2% of the state total to 3.0% by 2023, so county sums
  understate statewide first doses by that margin.
- **Reporting lag.** By vaccination date, the first edition after a month ended already held 86% to 99% of that
  month's eventual first doses, typically 94-98% ([verify_06b](../outputs/tables/verify_06b_backlog_completeness.csv)).
  Counts by report date therefore shift a few percent of each period's doses into the next one.
- **Non-residents.** See finding 5 and section 4.1.

### B. Daily CSV copies of the workbook's "By County" sheet (verification and revision history)

| | |
|---|---|
| Source | `github.com/rdmurphy/tx-covid-vaccine-data`, folder `distribution/snapshots/`, MIT licence, pinned to commit `375efdd971a511cc826e05d5d8f6fd86191a2ada` |
| Content | 275 daily files, 29 Dec 2020 to 6 Oct 2021; file name = date DSHS last modified the workbook |
| Variables | The "By County" sheet as CSV: all-ages counts only, no age detail. From January 2021 the sheet also prints DSHS's estimates of the population in each priority group by county (`Population, Phase 1A Healthcare Workers`, `Population, Phase 1A Long-term Care Residents`, `Population, 16-64 Any Medical Condition`, `Population, Education and Child Care Personnel`). |
| Status | Third-party copy. Identical to the original workbook on all 21 overlapping dates, for one-dose, fully-vaccinated and doses-administered counts in all 254 counties ([verify_02](../outputs/tables/verify_02_github_vs_wayback.csv)). |
| Use | Day-by-day history of revisions (sections 4.4, 4.5). **Not used for any modelled quantity of the main analysis.** The extension to early 2021 ([03_early_rollout.md](03_early_rollout.md)) takes its county counts before the baseline, and the priority-group populations, from these copies. |

### C. CDC, "COVID-19 Vaccinations in the United States, County" (cross-check only)

| | |
|---|---|
| Link | <https://data.cdc.gov/Vaccinations/COVID-19-Vaccinations-in-the-United-States-County/8xkx-amqh> (dataset `8xkx-amqh`; rows last updated 12 May 2023) |
| File | All columns for `Recip_State = 'TX'`: 152,177 rows, 598 report dates |
| Geography | County of residence (`FIPS`, `Recip_County`), plus an "Unknown County" row |
| Dates | Report dates 13 Dec 2020 to 10 May 2023. **Texas county rows are zero until 21 Oct 2021**; counts start 22 Oct 2021; daily to 16 Jun 2022, weekly after. |
| Variables inspected | `Administered_Dose1_Recip` and `_5Plus`, `_12Plus`, `_18Plus`, `_65Plus` (people with at least one dose), the matching `..._Pop_Pct` fields, `Series_Complete_*`, `Completeness_pct` (98.9-99.1 for Texas), `Census2019*` denominators |
| Precision | Percentages have one decimal and are capped: at 99.9 until 8 Dec 2021, at 95.0 from 9 Dec 2021. Counts are not capped, so percentages need not be used. On the last date 13 counties have an 18+ count above their 18+ population (Maverick 239%). |
| Missing values | Loving County is zero until 2022. On 15 Dec 2021, 205 Texas counties are zero for one day. |
| Revisions | 7.7-8.6% of county report-to-report changes are negative. Statewide county sum fell by 297,634 on 3 Aug 2022. |

Comparison with DSHS on the same dates ([verify_04b](../outputs/tables/verify_04b_dshs_vs_cdc_by_date.csv),
[verify_04c](../outputs/tables/verify_04c_dshs_vs_cdc_county.csv)): CDC's Texas county total is 1.65% above DSHS on
26 Oct 2021, 3.26% above on 5 Jun 2022 and 1.9% above after the August 2022 revision. On 26 Oct 2021 the county gap
for ages 12+ ranges from -4.9% (5th percentile) to +6.9% (95th), with Bell +35.9%, Live Oak +24.0%, Wichita +15.7%,
Polk +13.3%, Tom Green +10.6%, El Paso +8.2% and Bexar +8.0%; 56 counties differ by more than 2 points of their
population. CDC's 18+ total is 98.6-100.0% of DSHS's 16+ total, although it should be about 3% lower if the two
systems counted the same people. Several of the counties with the largest positive gaps host large military
installations (Bell, Wichita, El Paso, Bexar, Tom Green), which is the pattern that doses given by federal agencies
and added by CDC would produce. The files do not state the cause.

### D. County health departments

| Department | What was inspected | Finding |
|---|---|---|
| Harris County Public Health, COVID-19 Data Hub (`services.arcgis.com/su8ic9KbA7PYVxPS`, tables `Download_DSHS_COVID_Vaccination_Summary`, `..._for_Ages_12_and_Up`, `Download_COVID_Vaccination_Progress_Overall`, `..._By_Age_Groups`) | Table definitions and all rows, saved in `data/raw/county_hd_harris/` | A single row of DSHS totals for Harris County (3,588,122 people with a first dose, identical to the last DSHS workbook) and weekly series of **cumulative percentages rounded to two decimals**, for fully vaccinated people, in 10-year age bands (10-19 spans the 18-year boundary). No counts over time. One county. |
| San Antonio Metropolitan Health District, weekly "COVID-19 Vaccination Report" PDFs (`covid19.sanantonio.gov/files/assets/public/health/vaccination-reports/`) | One report (21 Feb 2022) was retrieved but its text could not be extracted with the tools available here | Not verified at source. A search-engine index of these reports gives their source as the DSHS registry (ImmTrac2) and says VA and DOD doses are excluded. One county. The city's open-data portal also lists a ZIP-code vaccination dataset. |
| Tarrant County Public Health | Search results and one news report | Weekly PDF "recovery reports" and a dashboard built on a file supplied by the state. NBC 5 DFW (21 July 2021) reported the county showing 33% of residents with one dose against the state's 56%, and quoted DSHS explaining that records missing a county are assigned by address matching that starts from ZIP codes, many of which cross county lines in metropolitan areas. |
| Dallas County Health and Human Services | Search results only | PDF data summaries quoting percentages of residents with one dose. No machine-readable series found. |
| Austin Public Health dashboard page | Page no longer exists | Not inspected. |
| Williamson County and Cities Health District | Dashboard page | Refers readers to the DSHS dashboard. |

No county health department file found can support a statewide county series. Those that could be read or traced
repeat DSHS registry numbers, usually as percentages, for a single county. The Harris County table is useful as
confirmation that the archived workbook is the state's final record. This was a targeted look at the largest
counties, not an exhaustive search of all local health departments.

### E. U.S. Census Bureau population estimates, Vintage 2025 (denominators, age composition)

| | |
|---|---|
| Files | `cc-est2025-syasex-48.csv` (single year of age), `cc-est2025-agesex-48.csv`, layouts `CC-EST2025-SYASEX.pdf`, `CC-EST2025-AGESEX.pdf`, from <https://www2.census.gov/programs-surveys/popest/datasets/2020-2025/counties/asrh/> (released June 2026) |
| Geography, dates | County; `YEAR` 1 = 1 April 2020 base, 2-7 = 1 July 2020 to 2025 |
| Variables used | `STATE`, `COUNTY`, `YEAR`, `AGE` (0-85+), `TOT_POP`; summed to residents aged 16+, 65+ and all ages on 1 July 2021 |
| Limitations | Estimates, not counts. Texas 16+ on 1 July 2021 = 23,054,310, against 22,421,178 in the 2019 estimates DSHS used. Residents are counted where they usually live; people who are in a county temporarily are not in its estimate. |

### F. American Community Survey 2019-2023 five-year estimates (median household income)

| | |
|---|---|
| Files | Table-based summary file, `acsdt5y2023-b19013.dat`, `-b01001.dat`, `-b01002.dat`, from <https://www2.census.gov/programs-surveys/acs/summary_file/2023/table-based-SF/data/5YRData/> |
| Variables | `B19013_E001`/`_M001` median household income and margin of error (2023 dollars); `B01001` sex by age (65+ share, sensitivity only); `B01002_E001` median age |
| Geography, dates | County (`GEO_ID` `0500000US48xxx`); pooled sample of 2019-2023, treated as one multi-year characteristic |
| Limitations | Sample-based. Kenedy County's median income is not published (filled with the median of its four neighbours and flagged). ACS age shares are unreliable in very small counties (Loving County's 65+ share differs from the population estimate by 58 points), so the age predictor is taken from source E; the two agree closely elsewhere (correlation 0.96 for counties with 2,000 or more adults). The Census API now requires a key, so the public summary files are used instead. |

### G. Texas DSHS reported COVID-19 cases by county

| | |
|---|---|
| Link | <https://www.dshs.texas.gov/covid-19-coronavirus-disease-2019/texas-covid-19-data> (files last modified 10 May 2023) |
| Files | `Texas COVID-19 New Confirmed Cases by County.xlsx`, `Texas COVID-19 New Probable Cases by County.xlsx`, data-definition and case-note documents |
| Variables | Daily new confirmed cases (positive molecular test) and new probable cases (positive antigen test, or symptoms plus exposure) by county, 6 Mar 2020 to 10 May 2023 |
| Limitations | 2020 and 2021 are DSHS's final de-duplicated counts; 2022-2023 are provisional daily reports, so the series changes character at 1 January 2022. In the final years 2.9-3.8% of cases have no date and cannot be placed in a period. Cases with no county ("Incomplete Address") are 0.2-2.7% of the total. Home tests are not included, so reported cases increasingly understate infections in 2022-2023. |
| Use | Confirmed plus probable cases in the 30 days before each interval starts, per 100,000 residents. |

### H. Census Bureau county boundaries and adjacency

| | |
|---|---|
| Files | `cb_2021_us_county_500k.zip` (<https://www2.census.gov/geo/tiger/GENZ2021/shp/>), `county_adjacency2023.txt` (<https://www2.census.gov/geo/docs/reference/county_adjacency/>) |
| Use | 254 Texas county polygons; neighbours for the spatial model |
| Check | Shared-boundary neighbours computed from the polygons equal the Census adjacency file exactly: 724 neighbouring pairs, 1 to 9 neighbours per county, one connected map ([verify_10](../outputs/tables/verify_10_adjacency.csv)). |

### I. Texas DSHS news releases on vaccine eligibility (timeline only)

| | |
|---|---|
| Original addresses | `https://dshs.texas.gov/news/releases/2020/20201214.aspx`, `.../20201221.aspx`, `.../20201228.aspx`, `.../2021/20210303.aspx`, `.../20210310.aspx`, `.../20210323.aspx`, `.../20210512.aspx`. The DSHS site now refuses automated requests for these pages. |
| Where obtained | Internet Archive Wayback Machine captures made on the day of each release or the day after, saved unmodified in `data/raw/dshs_news/` (capture timestamps in the manifest) |
| Content used | Who became eligible and from when: first doses delivered 14 Dec 2020 (Phase 1A: front-line health-care workers and long-term-care residents); Phase 1B defined 21 Dec 2020 (people 65+ and people 16+ with a chronic medical condition); school and child-care staff from 3 Mar 2021; people 50-64 from 15 Mar 2021; all adults from 29 Mar 2021; adolescents 12-15 from 12 May 2021 |
| Limitations | The release of 21 Dec 2020 defines Phase 1B but gives no start date; the release of 10 Mar 2021 says it began "later that month". The date of 29 Dec 2020 used in the extension comes from press reports. No number in the analysis comes from these pages. |

## 4. Checks requested in the study brief

### 4.1 County of residence

DSHS and CDC both state that counts are by the recipient's county of residence. Three findings limit that:

- People with no usable address are in "Other": 1.2% of first-dose recipients after the April 2021 fix, 3.0% by 2023.
- County is assigned by address matching. DSHS told NBC 5 DFW in July 2021 that the first step uses ZIP codes and
  that ZIP codes crossing county lines had put some people in the wrong county. The records give no way to measure
  this; it would mostly move people between adjacent counties in metropolitan areas.
- In 16 counties recorded adult first doses exceed the adult population estimate at some edition
  ([county_flags.csv](../data/derived/county_flags.csv)): Maverick, Reeves, Webb, Brooks, Dimmit, Presidio, Hidalgo,
  Loving, Hudspeth, Starr, Cameron, Frio, Val Verde, El Paso, Willacy and Duval. They hold 8.8% of Texans aged 16+
  but account for 10-14% of adult first doses recorded statewide in mid-2021, 35% in January-February 2022 and 55%
  between November 2022 and May 2023. The files do not say who these recipients were; the geography points to
  people who were not usual residents. Those counties are kept out of the uptake models and shown separately.
  Neighbouring counties below 100% (La Salle 97%, Jim Hogg 93%, Zavala 92%) may be affected to a smaller degree
  and are kept.

### 4.2 Age eligibility

All Texans aged 16+ became eligible on 29 March 2021 (DSHS news release of 23 March 2021, source I), so eligibility
did not change for the 16+ group at any point in the modelled period of the main analysis. The records agree: no
one under 16 appears before the 25 May 2021 edition and no one under 12 before 12 November 2021.

Before 29 March 2021 eligibility was restricted in phases (source I): health-care workers and long-term-care
residents from 14 December 2020, people aged 65+ and people with a chronic medical condition from late December,
school and child-care staff from 3 March, people aged 50-64 from 15 March. By DSHS's own county estimates the
first two phases covered at most 60% of adults statewide. This matters only for the extension to early 2021,
which sets it out in its section 4.

### 4.3 Missing or suppressed values

DSHS: none; every county has a count in every edition. CDC: see source C. ACS: one county (source F).

### 4.4 Retrospective revisions

- 15 April 2021 edition: 662,780 people left the "Other" row and county counts rose by 807,099 in one day, against
  about 135,000 on the days either side ([verify_13a](../outputs/tables/verify_13a_unassigned_daily.csv),
  [verify_13b](../outputs/tables/verify_13b_reassignment_by_county.csv)). The jump beyond a county's usual daily change,
  as a share of its previous count: median 4.3%, 5th-95th percentile -0.2% to 16.9%, above 10% in 60 counties.
- 24 March 2021: Tarrant County's count fell by 62,699 in a day and rose by 59,951 the next day; in all, county
  counts fell by 81,391 in 78 counties in that edition. A one-day fault, not a correction.
- 12 to 27 February 2021: the "Other" row fell from 268,993 to 160,979 while reporting continued, so at least
  108,000 earlier records were given a county in those two weeks.
- Corrections continued in smaller numbers after 15 April: 17 counties had a lower adult count on 23 April than
  on 20 April, and 12 had a lower count on 25 May than on 23 April (Cochran fell from 2,192 to 834). The daily
  copies show that these movements ended around 10 May: falls in county counts sum to 47,901 persons between
  16 April and 11 May and to 757 in the two weeks after
  ([early_events.csv](../outputs/tables/early_events.csv)).
- From 25 May 2021 to 24 September 2021 no county's adult count fell between editions. Later falls are small (2 to
  239 persons per edition statewide) and concentrated in counties with fewer than 5,000 adults
  ([verify_14](../outputs/tables/verify_14_count_falls_by_edition.csv)).

### 4.5 Reporting backlogs

See source A (reporting lag) and [verify_06](../outputs/tables/verify_06_first_dose_by_vaxdate_across_editions.csv).
First doses given in January 2021 numbered 1,754,542 in the 25 May 2021 edition and 1,827,899 in the final edition,
a 4% later addition. Counts in this study are by report date.

### 4.6 Rounded or capped percentages

The sources used for modelling give counts, so no percentage is used. Where percentages are all that exist (CDC's
capped fields, Harris County's two-decimal series) they were documented and set aside.

## 5. Outcome definitions

- **Recorded coverage** (observed, not modelled): residents aged 16+ recorded with at least one dose by the edition's
  data-through date, divided by the Census estimate of residents aged 16+ on 1 July 2021. People of unknown age
  (never more than 0.07% of the total) are counted with adults.
- **Uptake in an interval** (modelled): adults newly recorded with a first dose during the interval, divided by adults
  not yet recorded as vaccinated at its start. Reported per 30 days.
- A county-interval enters the model only if the county never exceeds 100% recorded coverage and recorded coverage at
  the start of the interval is below 95%. Where a county's count fell between editions, new first doses are set to
  zero and the row is flagged (40 of 2,855 rows, 257 persons in total).

Both quantities describe vaccine receipt as recorded in the state registry. They say nothing about willingness or
acceptance, which would need survey data.

## 6. Predictors

| Predictor | Definition | Source |
|---|---|---|
| Age composition | Residents aged 65+ as a share of residents aged 16+, 1 July 2021 | E |
| Household income | Median household income, 2019-2023, natural log | F |
| Recent disease burden | Confirmed plus probable cases reported in the 30 days before the interval starts, per 100,000 residents, log(rate + 10) | G |

All three are standardised to mean 0 and standard deviation 1 across counties (or county-intervals); the constants
are in [data/derived/covariate_scaling.csv](../data/derived/covariate_scaling.csv).
