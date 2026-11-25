# Texas COVID-19 vaccination coverage: Bayesian spatiotemporal small-area analysis

County-level analysis of first-dose COVID-19 vaccination among Texas residents aged 16 and over,
24 May 2021 to 9 May 2023, built from archived Texas DSHS records.

Start here:

1. [docs/00_summary.md](docs/00_summary.md): the summary report. Main findings, key numbers, what was analysed, how
   the study differs from the proposal, how far the results can be trusted, and limitations, in a few pages.
   [docs/00_summary.pdf](docs/00_summary.pdf) is the copy to send to someone who does not have this folder: a
   short Letter-size document with the figures, and no links or file paths from this computer in it.
2. [docs/01_source_inventory.md](docs/01_source_inventory.md): what each source contains, what was verified,
   and why the age group, time intervals and study period differ from the original proposal.
3. [docs/02_report.md](docs/02_report.md): methods, results, validation and limitations.
4. [docs/03_early_rollout.md](docs/03_early_rollout.md): an extension back to the first doses (14 December 2020 to
   24 May 2021). It rests on an explicit assumption about recipients who had no county on record, so it is kept
   apart from the main report.
5. [site/index.html](site/index.html): an interactive version of the results, also on the web at
   <https://efkopru.github.io/texas-covid-coverage/>. A standalone app in one file: open it
   in a browser (double-click). It holds its own data and county map outlines and loads nothing from the network.
   Choose what to map, move through time from December 2020 to May 2023, and select a county to see its record.
   It also offers: a light, dark or automatic colour theme (top right; the choice is remembered in that browser);
   map zoom (on a touch screen, by pinching with two fingers) and city names; a strip ranking every county on the
   mapped measure; a second county to compare with
   (Shift and click, or the "Compare with" box); each county's neighbours; a chart of any two county measures
   against each other; a link that reopens the same view; and a CSV download of the county figures.

## Layout

| Path | Contents |
|---|---|
| `R/` | All code. Scripts are numbered in the order they run. |
| `data/raw/` | Source files exactly as downloaded, one folder per source, plus `MANIFEST.csv` (URL, retrieval time, size, SHA-256 of every file). |
| `data/derived/` | Tidy tables produced by the scripts (county lookup, parsed vaccination and case counts, population, the analysis panel). |
| `outputs/tables/` | Result tables (`verify_*` source checks, `validation_*` out-of-sample scores, county results, sensitivity analysis, `early_*` for the extension). |
| `outputs/figures/` | Figures used in the report. |
| `outputs/models/` | Model summaries. The posterior draws (`samples_*.rds`) are attached to the release [posterior-draws-v1](https://github.com/efkopru/texas-covid-coverage/releases/tag/posterior-draws-v1). |
| `logs/` | Console output of each script run. |
| `site/` | The interactive report: `index.html` (built, standalone) and `src/page.html` (its template: layout, styles and code). |
| `.github/` | Publication on the web with GitHub Pages: a workflow and the script that arranges the files it serves. |
| `r-lib/` | Project-local R package library created by `R/00_setup.R`. |

## What a copy from GitHub does not contain

Three things are left out of the repository (see `.gitignore`). Everything else, including the other raw source
files, is in it.

| Left out | Size | How to get it |
|---|---|---|
| `r-lib/`, the installed R packages | 152 MB | `Rscript --vanilla R/00_setup.R` |
| `data/raw/census_acs/acsdt5y2023-b01001.dat` and `Geos20235YR.txt`, two national Census ACS files | 191 MB and 88 MB | `Rscript --vanilla R/01_download_sources.R` fetches them and skips the files already present; `data/raw/MANIFEST.csv` holds their checksums. GitHub refuses files over 100 MB. |
| `outputs/models/samples_*.rds`, the posterior draws | 340 MB | Download them from the release [posterior-draws-v1](https://github.com/efkopru/texas-covid-coverage/releases/tag/posterior-draws-v1) and put them in `outputs/models/`. With them, steps 8, 14 (`tables`), 15 and 10 regenerate the stored tables, figures and documents byte for byte. Steps 6 and 14 can also fit the models again, which gives draws that are close to these but not identical (see "How exactly results repeat"). |

Without the two Census files, step 4 cannot be rerun and `verify_manifest()` reports them as missing; nothing else
depends on them, because their parsed content is in `data/derived/`.

## The web copy

<https://efkopru.github.io/texas-covid-coverage/> serves `site/index.html` and the HTML and PDF copies of the four
documents, exactly as committed. Nothing is built on GitHub: after a push that changes one of those files, the
workflow in `.github/workflows/pages.yml` arranges them with `.github/scripts/assemble_pages.py` and publishes them.
In the served documents, links to files that are not served (code, tables, logs) lead to the same file in this
repository. To update the web copy, rebuild locally (steps 11, 16 and 17 below), commit and push. If a publication
fails, open it on the repository's Actions page and choose "Re-run failed jobs": only the publish job runs again,
with the files already uploaded.

## Reproducing the analysis

Requirements: R 4.6 (developed with 4.6.1 on Windows), internet access for steps 0 and 1. About 0.5 GB of downloads.
Run every command from the project root. `--vanilla` keeps R from loading any workspace or profile file.

```
Rscript --vanilla R/00_setup.R                 # packages into r-lib/ (R-INLA comes from its own repository)
Rscript --vanilla R/01_download_sources.R      # raw files + data/raw/MANIFEST.csv   (skips files already present)
Rscript --vanilla R/02_parse_vaccination.R     # DSHS workbooks, daily copies, CDC file -> tidy tables
Rscript --vanilla R/03_verify_vaccination.R    # source cross-checks -> outputs/tables/verify_*.csv
Rscript --vanilla R/04_parse_covariates.R      # population, ACS, cases, boundaries, neighbours
Rscript --vanilla R/05_build_panel.R           # county-by-interval analysis dataset
Rscript --vanilla R/06_fit_models.R            # five uptake models + baseline coverage model
Rscript --vanilla R/07_validate.R counties     # A. held-out counties         (each experiment can run
Rscript --vanilla R/07_validate.R regions      # B. held-out health regions     in its own terminal)
Rscript --vanilla R/07_validate.R later        # C. later intervals, half the counties withheld
Rscript --vanilla R/07_validate.R forecast     # D. next interval, all counties withheld
Rscript --vanilla R/07_validate.R summary
Rscript --vanilla R/08_outputs.R               # tables and figures for the selected model
Rscript --vanilla R/09_sensitivity.R           # alternative data choices
Rscript --vanilla R/10_report_tables.R         # fills docs/02_report_template.md -> docs/02_report.md
Rscript --vanilla R/13_early_reconstruction.R  # extension: allocation of records without a county, extended datasets
Rscript --vanilla R/14_early_models.R          # extension: model on 18 intervals, five variants
Rscript --vanilla R/15_early_outputs.R         # extension: tables, figures 12-16, docs/03_early_rollout.md
Rscript --vanilla R/17_summary_report.R        # summary report: fills docs/00_summary_template.md -> docs/00_summary.md
Rscript --vanilla R/11_render_report.R         # HTML copies of the four documents; PDF of the summary (needs Edge or Chrome)
Rscript --vanilla R/12_audit_trace.R           # re-derives county numbers from raw cells; checks checksums
Rscript --vanilla R/16_build_site.R            # interactive report: site/index.html (standalone, one file)
Rscript --vanilla R/18_rerun_check.R           # optional: fits every model again in a temporary copy -> outputs/tables/rerun_*.csv
```

Steps 13-15 and 17 are numbered after the main pipeline because they were added to it; run them before steps 11
and 12 so that the HTML copies and the audit cover them. Each document in `docs/` is filled from a template beside
it (`*_template.md`), so edit the template, not the filled document. The variants of step 14 can be run side by side
(`R/14_early_models.R H`, `... A,N`, `... HU,HE`, then `... tables`).

Timing on a 14-core desktop: steps 0-5 about 15 minutes (mostly downloads); step 6 about 20 minutes; step 7 one
to two hours, dominated by model M3 (five to ten minutes per fit, which is why it is run only in experiments C
and D); step 9 about 15 minutes; steps 13-15 about 10 minutes; steps 8 and 10-12 a few minutes together; step 18 about 44 minutes
(about 10 with `quick`, which leaves out the experiments of step 7). Set the environment variable
`TXCOV_THREADS` (for example `4:1`) to control the threads each R-INLA fit uses. A model can be named after the
experiment, for example `Rscript --vanilla R/07_validate.R later M3`, and finished results are not recomputed.
The `summary` step also writes `outputs/tables/validation_paired_differences.csv`: differences in scores between
models on the same county-intervals, with bootstrap intervals. Do not edit a script while a run of it is in
progress: R reads the file as it goes.

Step 1 depends on third-party hosts staying available: the Internet Archive for the DSHS workbooks and GitHub for
the daily copies. If a file has changed or vanished, `verify_manifest()` in `R/_common.R` compares what is on disk
with the recorded checksums. Step 2 onward needs no network.

**How exactly results repeat.** The steps that parse the sources and build the datasets (2, 3, 5 and 13) and those
that build the report tables, documents and site from stored results (10, 11, 16 and 17) repeat byte for byte,
apart from the build date. This was checked in a clean copy of the repository; step 4 was not rechecked because it
needs a file that is not in the repository. The model fits do not repeat exactly. R-INLA does not return exactly
the same fit twice on the same computer, with several threads or with one, and the 1,000 posterior draws then come
out as a different sample although their seed is fixed. Step 18 measures this: it fits every model again in a temporary copy, including the out-of-sample
experiments of step 7, and compares the tables. In its run of 24 November 2026 (R-INLA 26.08.07),
hazard ratios changed by at most 0.0013, county relative uptake by at most 1.2% (its interval bounds by at
most 2.9%), and 29 of the 510 other values that the scripts take from the models and the records came
out differently, each by at most 5 units in its last printed digit.
Of the 373 values quoted from the out-of-sample experiments, 192 came out differently. Their mean
scores changed by at most 0.027 points (2.6%). The comparisons between models gave the same verdict in
124 of 126 cases in experiments A, B and C, but in only 12 of 20 in experiment D, the forecast of the
next interval, from which no ranking of the models should be read.
The details are in `outputs/tables/rerun_differences.csv`, `rerun_changed_values.csv`, `rerun_validation_verdicts.csv` and
`rerun_repeat_fit.csv`.
The published numbers are those of one run and are the reference. Anyone who fits the models again, here or from a
GitHub copy, should expect differences of this size, and a different R-INLA version can be expected to differ at
least as much. Package versions are recorded in `outputs/r_package_versions.csv`.

## Tracing a number back to its source

Every result table carries county FIPS codes and interval numbers. From there:

- `data/derived/panel.csv` holds, for each county and interval, the two DSHS editions that bound it
  (`start_asof`, `end_asof`), the recorded counts at each (`cum_start`, `cum_end`), the population estimate
  (`pop16`) and every predictor.
- `data/derived/coverage_editions.csv` holds the recorded counts at every usable edition, and
  `data/derived/dshs_workbook_index.csv` maps each edition date to its workbook file in
  `data/raw/dshs_vax_wayback/workbooks/`.
- `data/raw/MANIFEST.csv` gives that file's Internet Archive address and checksum.
- For the extension, `data/derived/early_reconstruction.csv` holds the published count, the allocated amount and
  the reconstructed count for each county and boundary edition, and `data/derived/early_county_allocation.csv` the
  records each county received on 15 April 2021. `R/12_audit_trace.R` recomputes four of these from the raw daily
  files.

## Data licences and attribution

Texas DSHS, CDC and Census Bureau files are public U.S. or Texas government records. The daily copies of the DSHS
county sheet come from `github.com/rdmurphy/tx-covid-vaccine-data` (MIT licence, copy included in
`data/raw/dshs_vax_github/LICENSE`). Archived workbooks and DSHS news releases were retrieved from the Internet
Archive Wayback Machine.
