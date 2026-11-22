# Extension: county coverage and uptake from the first doses, 14 December 2020 to 24 May 2021

This document extends the analysis in [02_report.md](02_report.md) back to the start of the rollout. The main
report begins on 24 May 2021 because county counts before mid-April 2021 are incomplete: a share of recipients had
no county on record, and that share differed from county to county. Going further back requires an assumption
about where those recipients lived. The assumption is stated in section 3, tested as far as the files allow, and
varied in section 7. Nothing here changes the main report; its results do not depend on the assumption.

Three terms are used throughout. **Published** is a county count exactly as it stood in a DSHS edition.
**Reconstructed** is the published count plus the county's allocated share of the records that had no county at
the time. **Modelled** is a posterior summary from the model fitted to the reconstructed series. As in the main
report, every number describes vaccine receipt as recorded, not willingness.

## 1. Summary

**What was done.** Daily copies of the DSHS county sheet survive from 29 December 2020. Six intervals were added
before the main baseline: 14-31 December 2020, January, February and March 2021, 1-13 April, and 14 April-24 May.
On 15 April 2021 DSHS assigned about 664,000 previously unassigned recipients to counties in a
single edition. How many each county received that day is observed. The assumption is that at earlier dates each county
was missing the same relative share of its recipients, scaled so that the allocations add up to the number of
unassigned recipients actually published at that date.

**What the reconstructed series shows.**

- Statewide, the share of residents aged 16+ recorded with a first dose was 8.1% on 30 January 2021,
  15.3% on 28 February, 32.6% on 31 March, 41.0% on 13 April and
  52.5% on 24 May. Uptake among adults not yet vaccinated peaked at 26.5% per 30 days in
  the first two weeks of April, just after eligibility opened to all adults.
- **Most of the gap between counties opened early.** Across the 213 counties with usable early records,
  the distance between the 90th- and 10th-percentile county was 9.9 points on 30 January, 17.6
  on 28 February and 22.1 on 24 May 2021. By the end of February it had reached 80% of
  its size at the main baseline and 67% of its size at the end of the study (26.3
  points on 9 May 2023). The size of the gap was set early; which counties were on which side of it was not
  (rank correlation of county coverage on 28 February with coverage on 9 May 2023: 0.37; for
  coverage on 24 May 2021: 0.90).
- **The age association reversed in April 2021.** While eligibility was restricted (to 31 March), counties with
  more adults aged 65+ had, if anything, slightly higher uptake (hazard ratio 1.04 (0.97 to 1.11) per standard
  deviation). From 1 April to 24 May the ratio was 0.89 (0.83 to 0.96), and it stayed below 1 for the rest of the
  study.
- **Income** shows no association before April (0.98 (0.90 to 1.05)) and a positive one in April-May
  (1.11 (1.02 to 1.20)). **Recent cases** are positively associated in both early periods (1.18 (1.11 to 1.27)
  and 1.23 (1.15 to 1.31)).
- **Who was ahead changed when eligibility opened.** The correlation between a county's relative uptake to 31
  March and its relative uptake after 24 May is 0.28. Between April-May 2021 and the period after 24
  May it is 0.77. The pattern that persisted to 2023 was set in the spring of 2021, not in the first
  three months.

**How much rests on the allocation.** Little, for these conclusions. With no allocation at all, or with a
different allocation rule, the gap between the 90th- and 10th-percentile county differs by at most
0.7 points, county ranks are almost unchanged (rank correlation at least 0.97), and
the hazard ratios in the two early periods stay within 1.03 to 1.04 and 0.89 to 0.91 for age,
0.97 to 0.98 and 1.10 to 1.11 for income, and 1.17 to 1.19 and 1.22 to 1.25 for recent
cases. What the allocation does change is the level of individual counties: by up to 8.5 points of
coverage.

**Evidence for the assumption.** It makes a prediction that can be checked: whenever the statewide number of
unassigned recipients fell, the published counts of the counties that received most on 15 April should have grown
abnormally fast, and when it rose they should have grown abnormally slowly. Over 6 two-week windows the
predicted and estimated effects have a correlation of 0.97 when counties are weighted by size and
0.46 when they are weighted equally. The assumption is therefore well supported for the counties where
most people live and less well for small ones.

**Main cautions.** 25 of the 238 modelled counties (1.6% of their
adults) are left out of the early intervals because their records kept changing. Dates are dates of reporting, not
of vaccination. Until 29 March 2021 not every adult was eligible, so uptake per adult not yet vaccinated mixes
eligibility with uptake among those eligible. All county counts before the baseline come from a third-party daily
copy of the DSHS sheet, which matches the original workbooks wherever both survive.

## 2. What the early records look like

**Sources.** The original DSHS workbooks survive in the Internet Archive for only 14 dates
before the baseline. A third-party archive saved the "By County" sheet as a CSV file on almost every day from
29 Dec 2020 ([inventory](01_source_inventory.md), source A2). On all 21 dates in 2020-2021 for which both
exist the two are identical in every county. The five editions used as boundaries below are all from the daily copies. As elsewhere, an edition
dated D holds records through D - 1.

**County totals are counts of adults.** Before 12 May 2021 nobody under 16 was eligible. In the eight original
workbooks from 2 March to 23 April 2021 that carry both sheets, the county total equals the sum of the 16+ age
bands in every one of the 254 counties
([early_county_total_vs_16plus.csv](../outputs/tables/early_county_total_vs_16plus.csv)).

**Records moved between "no county" and counties, and between counties, in four episodes** (Figure 12, upper
panel):

1. *12 to 27 February 2021.* The number of recipients with no county fell from 268,993 (edition of
   12 Feb 2021) to 160,979 (edition of 27 Feb 2021) while reporting continued: at least
   108,014 earlier records were given a county in those two weeks.
2. *24 March 2021.* County counts fell by 81,391 in 78 counties in one edition and
   came back the next day (Tarrant County: down 62,699, then up 59,951). This was a
   one-day fault, not a correction, and no boundary is placed on it.
3. *15 April 2021.* The number with no county fell by 662,780 in one edition, from
   8.1% of the state total to 1.16%.
4. *16 April to 10 May 2021.* Records kept moving between counties: falls in county counts sum to
   47,901 persons across 173 counties. After the edition of 11 May the falls are
   negligible (757 persons in the two weeks to the baseline).

One daily edition (12 March 2021) has the "at least one dose" and "fully vaccinated" columns interchanged and is
not used.

![Figure 12](../outputs/figures/fig12_unassigned_and_correction.png)

*Figure 12. Recipients with no county on record over time (upper), and the share each county received in the April
correction (lower).*

**Intervals.** Boundaries were placed at month ends where a daily edition exists, and on the last edition before
the correction. No edition survives for 1 February 2021, so January ends on the 30th. The interval from 14 April
to 24 May spans the weeks in which records were still moving between counties, so that those movements cancel
within it.

| Interval | Records | Days | New first doses, all counties | Coverage at end, all counties (%) | Uptake per 30 days, all counties (%) | Coverage at end, 213 counties (%) | Uptake per 30 days, 213 counties pooled (%) | Uptake per 30 days, median county (%) |
|---|---|---|---|---|---|---|---|---|
| 1 | 14 Dec 2020 - 31 Dec 2020 | 18 | 336,450 | 1.46 | 2.42 | 1.42 | 2.35 | 1.84 |
| 2 | 01 Jan 2021 - 30 Jan 2021 | 30 | 1,525,501 | 8.08 | 6.71 | 7.86 | 6.53 | 6.52 |
| 3 | 31 Jan 2021 - 28 Feb 2021 | 29 | 1,671,454 | 15.33 | 8.15 | 14.96 | 7.96 | 8.57 |
| 4 | 01 Mar 2021 - 31 Mar 2021 | 31 | 3,973,337 | 32.56 | 19.77 | 31.76 | 19.19 | 15.47 |
| 5 | 01 Apr 2021 - 13 Apr 2021 | 13 | 1,945,177 | 41.00 | 26.54 | 39.96 | 25.56 | 12.80 |
| 6 | 14 Apr 2021 - 24 May 2021 | 41 | 2,646,413 | 52.48 | 14.64 | 50.96 | 13.77 | 6.66 |

## 3. The allocation

**What is observed.** For each county, the number of records it received on 15 April: its rise in that edition
minus its share of that day's new first doses (estimated from its share of the following week's increase).
Together these sum to 664,458: the fall of 662,780 in the number with no county, plus
about 1,700 of that day's new recipients who had none. Divided by the count published for the
county the day before, this
gives the share the county had been missing: 7.6% over all counties, but 1% in Harris
County, 19% in Tarrant and 25% in Denton. Across the 213 counties the
median is 3.8%, the 90th percentile 14.1% and the largest 32%
(Cass). In 36 counties the estimate is slightly negative and is set to zero.

| County | Count published 14 April | Records received 15 April | Share of the previous count (%) |
|---|---|---|---|
| Tarrant | 549,862 | 102,533 | 18.6 |
| Travis | 462,261 | 65,616 | 14.2 |
| Denton | 257,990 | 63,403 | 24.6 |
| Collin | 377,657 | 38,419 | 10.2 |
| Dallas | 843,308 | 36,660 | 4.3 |
| Bexar | 621,769 | 34,976 | 5.6 |
| Fort Bend | 300,462 | 31,832 | 10.6 |
| Williamson | 197,063 | 27,209 | 13.8 |
| Montgomery | 143,256 | 27,196 | 19.0 |
| Nueces | 104,098 | 21,403 | 20.6 |
| Harris | 1,517,829 | 15,928 | 1.0 |
| McLennan | 62,188 | 9,857 | 15.9 |

After the correction 1.16% of the state total still had no county. That share is taken to be
unassignable at every earlier date too.

**What is assumed.** For county *i* at an earlier edition *t*:

```
allocated[i,t] = U[t] * ( published[i,t] * share[i] ) / sum over counties( published[j,t] * share[j] )

U[t]      = no_county[t] - 0.0116 * state_total[t]      records that would later be given a county
share[i]  = records county i received on 15 April / its published count on 14 April
```

In words: at every earlier date each county is missing the same relative share of its recipients as the April
correction revealed, and all the shares are scaled by a common factor *u* so that the allocations add up to the
unassigned total actually published at that date. The scaling matters, because the unassigned total did not move
in step with the county counts: *u* is 1.04 at the end of December, 1.51 at the end of January,
0.51 at the end of February and 0.80 at the end of March. On 14 April *u* is 1 and nothing is
assumed: the allocation is what DSHS did the next day.

| Records through | State total | Sum of county counts | No county | No county (% of state) | Allocated to counties | Allocated (% of county sum) | Scaling u | Largest county uplift (%) |
|---|---|---|---|---|---|---|---|---|
| 31 Dec 2020 | 340,415 | 313,997 | 26,418 | 7.8 | 22,459 | 7.2 | 1.04 | 33 |
| 30 Jan 2021 | 1,883,862 | 1,686,470 | 197,392 | 10.5 | 175,482 | 10.4 | 1.51 | 47 |
| 28 Feb 2021 | 3,574,983 | 3,402,128 | 172,855 | 4.8 | 131,277 | 3.9 | 0.51 | 16 |
| 31 Mar 2021 | 7,595,073 | 7,075,168 | 519,905 | 6.8 | 431,572 | 6.1 | 0.80 | 25 |
| 13 Apr 2021 | 9,563,133 | 8,787,453 | 775,680 | 8.1 | 664,458 | 7.6 | 1.00 | 31 |

| County | Series | 31 Dec 2020 | 30 Jan 2021 | 28 Feb 2021 | 31 Mar 2021 | 13 Apr 2021 |
|---|---|---|---|---|---|---|
| Harris | Published | 1.45 | 7.93 | 13.72 | 32.24 | 41.46 |
| Harris | Reconstructed (H) | 1.46 | 8.06 | 13.79 | 32.51 | 41.90 |
| Tarrant | Published | 1.10 | 6.44 | 13.36 | 26.90 | 33.21 |
| Tarrant | Reconstructed (H) | 1.31 | 8.25 | 14.63 | 30.91 | 39.39 |
| Denton | Published | 0.63 | 3.91 | 13.95 | 28.96 | 34.76 |
| Denton | Reconstructed (H) | 0.80 | 5.36 | 15.69 | 34.65 | 43.28 |
| Travis | Published | 1.44 | 7.04 | 12.86 | 32.82 | 43.29 |
| Travis | Reconstructed (H) | 1.65 | 8.55 | 13.79 | 36.54 | 49.42 |
| Lubbock | Published | 3.04 | 14.68 | 24.12 | 34.90 | 39.36 |
| Lubbock | Reconstructed (H) | 3.05 | 14.76 | 24.16 | 35.01 | 39.51 |
| Gaines | Published | 1.13 | 4.69 | 9.05 | 16.12 | 18.00 |
| Gaines | Reconstructed (H) | 1.13 | 4.69 | 9.05 | 16.12 | 18.00 |

**Two alternatives are carried through every result.** Allocation A spreads the same total by each county's
fixed share of the April assignment, whatever its published count at the time. Allocation N allocates nothing and
uses the counts as published.

**A test of the assumption.** If county *i* is missing the share *u × share[i]* of its recipients, then between
two dates its published count grows faster or slower than its true count by about (*u* at the first date minus
*u* at the second) × *share[i]*. A regression of the growth of published counts on *share[i]* should therefore
have a slope close to that difference: positive when unassigned records were being worked off, negative when they
were piling up.

| Window | No county at start (%) | No county at end (%) | Slope predicted by the assumption | Estimated slope, counties weighted by size | Estimated slope, counties weighted equally |
|---|---|---|---|---|---|
| 13 Jan 2021 to 27 Jan 2021 | 8.4 | 10.2 | -0.33 | -0.40 (s.e. 0.15) | -1.15 (s.e. 0.46) |
| 27 Jan 2021 to 11 Feb 2021 | 10.2 | 9.6 | 0.13 | 0.21 (s.e. 0.17) | -0.78 (s.e. 0.32) |
| 11 Feb 2021 to 26 Feb 2021 | 9.6 | 4.7 | 0.84 | 1.33 (s.e. 0.09) | 1.14 (s.e. 0.15) |
| 26 Feb 2021 to 13 Mar 2021 | 4.7 | 6.7 | -0.28 | -0.04 (s.e. 0.10) | 0.67 (s.e. 0.19) |
| 13 Mar 2021 to 29 Mar 2021 | 6.7 | 6.5 | 0.03 | 0.06 (s.e. 0.07) | 0.75 (s.e. 0.10) |
| 29 Mar 2021 to 13 Apr 2021 | 6.5 | 8.1 | -0.26 | -0.10 (s.e. 0.06) | 0.41 (s.e. 0.09) |

In the window of the February work-off the predicted slope is 0.84 and the estimate
1.33 (standard error 0.09): the counties that gained most on 15 April are the same ones whose counts jumped in February.
Over the 6 windows the correlation between predicted and estimated slopes is 0.97 with counties
weighted by size. With every county given equal weight it is 0.46, and the estimates are positive in
the last three windows where the assumption predicts zero or negative values. The assumption describes the large
counties well. For small counties it is weaker, and something else that is related to the April share was also
raising their published growth in March and April.

**Counties left out.** A county's early records are treated as unsettled if (a) the falls in its count between
16 April and 11 May exceed 5% of its count on 15 April, or (b) more than 5% of its
count at a boundary edition was later taken away again, which happens when a batch of records is credited to the
wrong county for some days. 25 of the 238 modelled counties meet one of these conditions.
Their early intervals do not enter the model or the summaries below; their intervals after 24 May are used as in
the main report. The file of modelled early uptake marks these county-intervals, whose modelled values rest on
the county's later intervals, its neighbours and its predictors rather than on its own early counts.

| County | Adults 16+ | Count on 15 April 2021 | Falls 16 April - 11 May (persons) | Falls as % of the 15 April count | Largest share of a boundary count later removed (%) | At the edition of |
|---|---|---|---|---|---|---|
| Cochran | 1,868 | 2,831 | 2,744 | 96.9 | 71.8 | 15 Apr 2021 |
| Cottle | 1,123 | 422 | 3 | 0.7 | 92.4 | 1 Jan 2021 |
| King | 198 | 68 | 44 | 64.7 | 48.6 | 14 Apr 2021 |
| Hamilton | 6,704 | 2,953 | 48 | 1.6 | 38.8 | 31 Jan 2021 |
| Schleicher | 1,923 | 832 | 2 | 0.2 | 31.9 | 31 Jan 2021 |
| Baylor | 2,732 | 1,444 | 446 | 30.9 | 20.5 | 15 Apr 2021 |
| Bastrop | 79,876 | 28,928 | 8,465 | 29.3 | 0.0 |  |
| Glasscock | 883 | 556 | 144 | 25.9 | 17.6 | 14 Apr 2021 |
| Borden | 493 | 176 | 45 | 25.6 | 18.0 | 14 Apr 2021 |
| Austin | 24,277 | 12,275 | 2,891 | 23.6 | 16.7 | 15 Apr 2021 |
| Foard | 910 | 451 | 74 | 16.4 | 14.1 | 1 Mar 2021 |
| Houston | 18,167 | 5,582 | 884 | 15.8 | 0.0 |  |
| Rockwall | 89,176 | 32,967 | 5,193 | 15.8 | 0.0 |  |
| Terrell | 609 | 369 | 58 | 15.7 | 7.3 | 15 Apr 2021 |
| Hopkins | 29,251 | 8,530 | 0 | 0.0 | 12.6 | 31 Jan 2021 |
| Scurry | 13,095 | 4,393 | 0 | 0.0 | 9.7 | 31 Jan 2021 |
| Edwards | 1,152 | 557 | 49 | 8.8 | 5.0 | 15 Apr 2021 |
| Irion | 1,231 | 462 | 39 | 8.4 | 1.1 | 15 Apr 2021 |
| Donley | 2,771 | 987 | 28 | 2.8 | 8.4 | 1 Apr 2021 |
| Briscoe | 1,121 | 486 | 39 | 8.0 | 5.7 | 14 Apr 2021 |
| DeWitt | 15,957 | 5,544 | 411 | 7.4 | 6.3 | 15 Apr 2021 |
| Calhoun | 15,753 | 7,591 | 524 | 6.9 | 5.5 | 1 Mar 2021 |
| Crosby | 3,944 | 1,814 | 98 | 5.4 | 0.0 |  |
| Bandera | 18,206 | 7,108 | 382 | 5.4 | 0.0 |  |
| Runnels | 7,870 | 3,039 | 21 | 0.7 | 5.2 | 31 Jan 2021 |

## 4. Eligibility

| From | Who could be vaccinated | DSHS population estimate | Share of adults 16+ | Source |
|---|---|---|---|---|
| 14 Dec 2020 | Phase 1A: front-line health-care workers and residents of long-term-care facilities | 1,513,576 | 7% | DSHS news release of 14 Dec 2020 (first doses delivered that day) |
| 29 Dec 2020 | Phase 1B added: people aged 65+ and people aged 16+ with a chronic medical condition | 13,550,779 | 60% | DSHS news release of 21 Dec 2020 (definition); release of 10 Mar 2021 says Phase 1B began later in December; start date of 29 Dec from press reports, not from a DSHS file |
| 3 Mar 2021 | School and child-care staff added | 850,859 | 4% | DSHS news release of 3 Mar 2021 |
| 15 Mar 2021 | Phase 1C added: people aged 50-64 |  |  | DSHS news release of 10 Mar 2021 |
| 29 Mar 2021 | Everyone aged 16+ | 22,421,178 | 100% | DSHS news release of 23 Mar 2021 |
| 12 May 2021 | Adolescents aged 12-15 added (not part of this study's adult counts) |  |  | DSHS news release of 12 May 2021 |

The population estimates are DSHS's own, printed in the county sheet. Until 29 March 2021 the adults "not yet
vaccinated" in a county include many who could not yet be vaccinated: by DSHS's estimates Phases 1A and 1B
together covered at most 60% of adults statewide, and between 48% and
83% across counties (median 67%). Uptake per adult not yet vaccinated in December to
March therefore reflects who was eligible and how much vaccine reached the county, as well as uptake among those
eligible. Section 7 includes a variant in which, for January and February, the population at risk is the
population DSHS estimated to be eligible.

## 5. Reconstructed coverage and uptake

![Figure 13](../outputs/figures/fig13_reconstructed_coverage_maps.png)

*Figure 13. Reconstructed first-dose coverage of residents aged 16+ at four dates in early 2021.*

![Figure 14](../outputs/figures/fig14_extended_uptake_and_spread.png)

*Figure 14. Uptake per 30 days over the whole series (upper), and the spread of coverage across counties (lower).*

Pooled over the 213 counties, 6.5% of adults not yet vaccinated received a first dose per 30
days in January 2021, 8.0% in February, 19.2% in March and 25.6% in the first 13
days of April. From 14 April to 24 May the rate was 13.8%. These are rates of reporting. The main report
(section 3.1) gives the statewide series by date of vaccination, which runs a few weeks ahead: what had been
reported by the end of a month in early 2021 was 0.8 to 3.5 points of coverage below what was eventually
attributed to that month.

| Records through | Source | 10th percentile | Median | 90th percentile | Gap 90th - 10th (points) | Ratio 90th / 10th | Standard deviation |
|---|---|---|---|---|---|---|---|
| 31 Dec 2020 | reconstructed (H) | 0.47 | 1.11 | 2.84 | 2.37 | 6.03 | 1.06 |
| 30 Jan 2021 | reconstructed (H) | 4.74 | 7.95 | 14.61 | 9.87 | 3.08 | 4.44 |
| 28 Feb 2021 | reconstructed (H) | 9.91 | 16.20 | 27.55 | 17.65 | 2.78 | 6.83 |
| 31 Mar 2021 | reconstructed (H) | 21.70 | 30.21 | 41.31 | 19.61 | 1.90 | 7.99 |
| 13 Apr 2021 | reconstructed (H) | 25.34 | 35.20 | 46.36 | 21.03 | 1.83 | 8.27 |
| 24 May 2021 | recorded | 32.21 | 41.18 | 54.29 | 22.09 | 1.69 | 8.50 |
| 23 Sep 2021 | recorded | 44.54 | 54.19 | 67.66 | 23.11 | 1.52 | 9.73 |
| 25 Feb 2022 | recorded | 49.94 | 59.83 | 74.33 | 24.39 | 1.49 | 10.33 |
| 9 May 2023 | recorded | 51.44 | 61.84 | 77.70 | 26.26 | 1.51 | 10.80 |

| Coverage through | With coverage on 24 May 2021 | With coverage on 9 May 2023 |
|---|---|---|
| 31 Dec 2020 | 0.26 | 0.20 |
| 30 Jan 2021 | 0.45 | 0.29 |
| 28 Feb 2021 | 0.57 | 0.37 |
| 31 Mar 2021 | 0.80 | 0.59 |
| 13 Apr 2021 | 0.91 | 0.73 |
| 24 May 2021 | 1.00 | 0.90 |

The gap between the 90th- and 10th-percentile county was 9.9 points on 30 January 2021, 17.6 on
28 February, 19.6 on 31 March and 22.1 at the main baseline. In relative terms the counties were
furthest apart at the start: the 90th-percentile county had 3.1 times the coverage of the
10th-percentile county at the end of January, 1.9 times at the end of March and 1.7 times on
24 May. The widening after May 2021 described in the main report added 4.2 points to a gap that
was already 22.1 points wide. The ranking of counties settled later than the size of the gap: county
coverage at the end of February has a rank correlation of 0.37 with coverage at the end of the study,
coverage on 13 April 0.73, and coverage on 24 May 2021 0.90.

## 6. Modelled uptake and associations by period

The model is the one selected in the main report (M4), fitted to all 18 intervals at once:
4,133 county-intervals, of which 1,278 are early ones. Each predictor's coefficient is allowed to
differ between five periods: 14 December 2020 to 31 March 2021, when eligibility was restricted; 1 April to 24 May
2021; and the three periods of the main report. Where a county-interval has many events the modelled rate equals
the reconstructed one (median absolute difference 0.02 points per 30 days over the early
county-intervals, 0.16 in counties with fewer than 5,000 adults).

![Figure 15](../outputs/figures/fig15_associations_by_period.png)

*Figure 15. County-level associations by period, under the three allocations.*

| Predictor | 14 Dec 2020 to 31 Mar 2021 | 01 Apr 2021 to 24 May 2021 | 25 May 2021 to 23 Sep 2021 | 24 Sep 2021 to 25 Feb 2022 | 26 Feb 2022 to 09 May 2023 |
|---|---|---|---|---|---|
| Share of adults aged 65+ | 1.04 (0.97 to 1.11) | 0.89 (0.83 to 0.96) | 0.87 (0.81 to 0.93) | 0.84 (0.79 to 0.90) | 0.83 (0.77 to 0.88) |
| Median household income | 0.98 (0.90 to 1.05) | 1.11 (1.02 to 1.20) | 1.02 (0.95 to 1.09) | 1.05 (0.98 to 1.13) | 1.11 (1.04 to 1.20) |
| Cases in previous 30 days | 1.18 (1.11 to 1.27) | 1.23 (1.15 to 1.31) | 1.12 (1.07 to 1.18) | 1.06 (1.00 to 1.12) | 1.11 (1.03 to 1.19) |

- **Age composition.** In the restricted period the hazard ratio per standard deviation of the 65+ share is
  1.04 (0.97 to 1.11): older counties were not behind, and may have been slightly ahead, when most of those eligible
  were aged 65 and over. From April 2021 the ratio is 0.89 (0.83 to 0.96) and it declines a little further in each
  later period. The negative association reported in the main report therefore starts when eligibility opens to
  all adults.
- **Household income.** No association in the restricted period (0.98 (0.90 to 1.05)); a positive one in
  April-May 2021 (1.11 (1.02 to 1.20)), which matches the main report's finding that higher-income counties had
  higher coverage by 24 May 2021.
- **Recent cases.** Positive in both early periods (1.18 (1.11 to 1.27) and 1.23 (1.15 to 1.31)) and larger than
  later. As in the main report, the coefficient compares counties with more and fewer reported cases within the
  same interval; the statewide fall in cases after the winter wave is in the shared time effect.
- **The later periods change little when the early data are added.** Their hazard ratios differ from the main
  report's own period estimates by at most 0.04, well inside the credible intervals (both are in
  the variant table of section 7).

**Relative uptake by period.** A county's modelled uptake relative to the average county, averaged over the
intervals of a period, ranges from 0.64 (10th percentile) to
1.59 (90th) in the restricted period, 0.56 to
1.83 in April-May 2021, and 0.61 to 1.82 after 24 May.

| Periods | Counties | Correlation | Interval from the uncertainty in modelled county rates | Rank correlation |
|---|---|---|---|---|
| 14 Dec 2020 - 31 Mar 2021 with 1 Apr - 24 May 2021 | 213 | -0.03 | -0.05 to -0.00 | -0.06 |
| 14 Dec 2020 - 31 Mar 2021 with 25 May 2021 - 9 May 2023 | 213 | 0.28 | 0.26 to 0.30 | 0.23 |
| 1 Apr - 24 May 2021 with 25 May 2021 - 9 May 2023 | 213 | 0.77 | 0.76 to 0.78 | 0.78 |

![Figure 16](../outputs/figures/fig16_early_versus_later_uptake.png)

*Figure 16. County relative uptake in the restricted period against relative uptake after 24 May 2021.*

A county's position in the first three and a half months says little about its position later (correlation
0.28), while its position in April-May 2021 says a great deal (0.77). The intervals in the
table reflect only the uncertainty in the modelled county rates, which is small; they do not say how different
the correlation might be in another set of counties. Age composition is part of the reason:

| Counties grouped by share aged 65+ | Counties | Median share aged 65+ (%) | 14 Dec 2020 - 31 Mar 2021 | 1 Apr - 24 May 2021 | 25 May 2021 - 9 May 2023 |
|---|---|---|---|---|---|
| Youngest third of counties | 71 | 18.2 | 1.03 | 1.20 | 1.17 |
| Middle third | 71 | 23.7 | 0.95 | 0.91 | 0.95 |
| Oldest third (by share aged 65+) | 71 | 30.3 | 1.05 | 0.83 | 0.80 |

The oldest third of counties ran level with the youngest third while eligibility was restricted and well below it
from April 2021 on.

## 7. How much depends on the allocation

| Variant | Predictor | 14 Dec 2020 to 31 Mar 2021 | 01 Apr 2021 to 24 May 2021 | 25 May 2021 to 23 Sep 2021 | 24 Sep 2021 to 25 Feb 2022 | 26 Feb 2022 to 09 May 2023 |
|---|---|---|---|---|---|---|
| Main allocation (H) | Share of adults aged 65+ | 1.04 (0.97 to 1.11) | 0.89 (0.83 to 0.96) | 0.87 (0.81 to 0.93) | 0.84 (0.79 to 0.90) | 0.83 (0.77 to 0.88) |
| Main allocation (H) | Median household income | 0.98 (0.90 to 1.05) | 1.11 (1.02 to 1.20) | 1.02 (0.95 to 1.09) | 1.05 (0.98 to 1.13) | 1.11 (1.04 to 1.20) |
| Main allocation (H) | Cases in previous 30 days | 1.18 (1.11 to 1.27) | 1.23 (1.15 to 1.31) | 1.12 (1.07 to 1.18) | 1.06 (1.00 to 1.12) | 1.11 (1.03 to 1.19) |
| Fixed April shares (A) | Share of adults aged 65+ | 1.03 (0.97 to 1.11) | 0.89 (0.83 to 0.96) | 0.87 (0.81 to 0.93) | 0.84 (0.79 to 0.90) | 0.83 (0.77 to 0.88) |
| Fixed April shares (A) | Median household income | 0.98 (0.90 to 1.05) | 1.10 (1.02 to 1.19) | 1.02 (0.95 to 1.09) | 1.05 (0.98 to 1.13) | 1.11 (1.04 to 1.20) |
| Fixed April shares (A) | Cases in previous 30 days | 1.17 (1.10 to 1.25) | 1.22 (1.15 to 1.31) | 1.12 (1.07 to 1.17) | 1.05 (1.00 to 1.11) | 1.11 (1.03 to 1.19) |
| No allocation (N) | Share of adults aged 65+ | 1.04 (0.97 to 1.11) | 0.91 (0.84 to 0.98) | 0.87 (0.81 to 0.93) | 0.84 (0.79 to 0.90) | 0.82 (0.77 to 0.88) |
| No allocation (N) | Median household income | 0.97 (0.90 to 1.05) | 1.10 (1.02 to 1.20) | 1.02 (0.95 to 1.09) | 1.05 (0.98 to 1.13) | 1.11 (1.04 to 1.20) |
| No allocation (N) | Cases in previous 30 days | 1.19 (1.11 to 1.28) | 1.25 (1.17 to 1.33) | 1.12 (1.07 to 1.18) | 1.05 (1.00 to 1.12) | 1.11 (1.03 to 1.19) |
| H, unsettled counties kept | Share of adults aged 65+ | 1.04 (0.98 to 1.11) | 0.87 (0.81 to 0.93) | 0.87 (0.82 to 0.93) | 0.85 (0.80 to 0.90) | 0.83 (0.78 to 0.88) |
| H, unsettled counties kept | Median household income | 0.98 (0.91 to 1.05) | 1.13 (1.04 to 1.21) | 1.01 (0.95 to 1.09) | 1.04 (0.97 to 1.11) | 1.12 (1.04 to 1.20) |
| H, unsettled counties kept | Cases in previous 30 days | 1.17 (1.10 to 1.26) | 1.19 (1.11 to 1.27) | 1.15 (1.09 to 1.21) | 1.06 (1.00 to 1.13) | 1.13 (1.05 to 1.22) |
| H, eligible population at risk in Jan-Feb | Share of adults aged 65+ | 1.00 (0.94 to 1.07) | 0.89 (0.83 to 0.96) | 0.87 (0.81 to 0.93) | 0.84 (0.79 to 0.90) | 0.83 (0.77 to 0.88) |
| H, eligible population at risk in Jan-Feb | Median household income | 0.99 (0.92 to 1.07) | 1.11 (1.02 to 1.20) | 1.02 (0.95 to 1.09) | 1.05 (0.98 to 1.12) | 1.11 (1.04 to 1.20) |
| H, eligible population at risk in Jan-Feb | Cases in previous 30 days | 1.18 (1.10 to 1.26) | 1.23 (1.15 to 1.31) | 1.12 (1.07 to 1.18) | 1.06 (1.00 to 1.12) | 1.11 (1.03 to 1.19) |
| Main analysis (no early intervals) | Share of adults aged 65+ |  |  | 0.86 (0.80 to 0.92) | 0.83 (0.77 to 0.89) | 0.81 (0.76 to 0.87) |
| Main analysis (no early intervals) | Median household income |  |  | 1.00 (0.93 to 1.08) | 1.04 (0.96 to 1.12) | 1.09 (1.01 to 1.17) |
| Main analysis (no early intervals) | Cases in previous 30 days |  |  | 1.08 (1.04 to 1.13) | 1.04 (1.00 to 1.09) | 1.07 (1.00 to 1.14) |

- **Other allocation rules (A, N).** The hazard ratios of the two early periods move in the second decimal place.
  The later periods cannot move, because their data do not depend on the allocation; their small differences
  between variants come from refitting the shared parts of the model.
- **Keeping the 25 counties with unsettled records** changes the early ratios to
  1.04 (0.98 to 1.11), 0.98 (0.91 to 1.05) and 1.17 (1.10 to 1.26) (restricted period) and 0.87 (0.81 to 0.93),
  1.13 (1.04 to 1.21) and 1.19 (1.11 to 1.27) (April-May).
- **Eligible population at risk in January and February.** With DSHS's Phase 1A and 1B population as the
  population at risk in those two months, the ratios of the restricted period are 1.00 (0.94 to 1.07) for age,
  0.99 (0.92 to 1.07) for income and 1.18 (1.10 to 1.26) for recent cases. Counties with more adults aged 65+
  have more eligible people, so part of what the all-adult denominator attributes to age is eligibility.

| Records through | Main allocation (H) | Fixed April shares (A) | No allocation (N) |
|---|---|---|---|
| 31 Dec 2020 | 2.37 | 2.22 | 2.26 |
| 30 Jan 2021 | 9.87 | 9.51 | 9.92 |
| 28 Feb 2021 | 17.65 | 17.63 | 17.82 |
| 31 Mar 2021 | 19.61 | 19.77 | 20.35 |
| 13 Apr 2021 | 21.03 | 21.03 | 20.55 |
| 24 May 2021 | 22.09 | 22.09 | 22.09 |

| Records through | Median uplift of the county count (%) | 90th percentile uplift (%) | Largest uplift (%) | Median change in coverage, H against none (points) | Largest change, H against none (points) | Largest change, H against fixed shares (points) | Rank correlation of county coverage, H against none |
|---|---|---|---|---|---|---|---|
| 31 Dec 2020 | 4.0 | 14.6 | 33 | 0.04 | 0.48 | 0.26 | 0.996 |
| 30 Jan 2021 | 5.8 | 21.2 | 47 | 0.39 | 3.34 | 1.75 | 0.986 |
| 28 Feb 2021 | 2.0 | 7.2 | 16 | 0.28 | 2.02 | 0.83 | 0.997 |
| 31 Mar 2021 | 3.1 | 11.3 | 25 | 0.79 | 5.69 | 0.78 | 0.986 |
| 13 Apr 2021 | 3.8 | 14.1 | 31 | 1.13 | 8.52 | 0.00 | 0.974 |

The allocation raises a county's count by a median of 2% to 6% depending on the date, and by up to
47%. It moves county coverage by a median of at most 1.1 points and by as much as
8.5 points in the most affected county. It does not change which counties are ahead: the rank
correlation between reconstructed and published coverage is 0.97 or higher at every date.

| Allocation | Counties | 14 Dec 2020 - 31 Mar 2021 with 1 Apr - 24 May 2021 | 14 Dec 2020 - 31 Mar 2021 with 25 May 2021 - 9 May 2023 | 1 Apr - 24 May 2021 with 25 May 2021 - 9 May 2023 |
|---|---|---|---|---|
| Published count x share received in April (H) | 167 | 0.13 | 0.43 | 0.74 |
| Fixed April shares (A) | 167 | 0.14 | 0.43 | 0.75 |
| No allocation (N) | 167 | 0.09 | 0.39 | 0.73 |

The weak link between the restricted period and later periods is not produced by the allocation: it is as weak
with no allocation at all.

## 8. Limitations

- **The allocation is an assumption.** It is observed on one date and carried back. Even on that date each
  county's share is an estimate: its rise in one edition, less an estimate of that day's new first doses. The test in section 3 supports
  it for large counties and less for small ones. A county whose missing share changed over the winter in a way
  that differed from the statewide pattern is misallocated, and such errors move first doses between adjacent
  intervals of that county.
- **25 counties are left out of the early intervals**, in addition to the 16 that are left out of
  every model. The rule that selects them looks only at falls in counts. A batch of earlier vaccinations credited
  to a county for the first time after 15 April shows up as a rise and cannot be told apart from new
  vaccinations.
- **Dates are reporting dates.** Early in the rollout reporting lagged vaccination by days to weeks, and the lag
  may have differed between counties.
- **Eligibility.** Before 29 March 2021 the population at risk includes people who were not eligible. The
  eligible-population variant uses DSHS estimates whose groups overlap and is limited to January and February.
- **Third-party copies.** Every county count before the baseline comes from the daily copies. They are identical
  to the original workbooks on all 21 dates where both exist, but the other dates cannot be checked against an
  original.
- **Unequal intervals.** The April boundary falls on the 13th because of the correction, so "April" is split, and
  the interval that follows is 41 days long.
- **No separate validation exercise.** The out-of-sample experiments of the main report were not repeated for
  the early intervals.

## 9. Files and reproduction

```
Rscript --vanilla R/13_early_reconstruction.R   # allocation, checks, extended datasets
Rscript --vanilla R/14_early_models.R           # model on the extended series, five variants
Rscript --vanilla R/15_early_outputs.R          # tables, figures 12-16 and this document
```

| Result | File |
|---|---|
| Per county: records received on 15 April, share, stability flags, DSHS phase populations | [early_county_allocation.csv](../data/derived/early_county_allocation.csv) |
| Per county and boundary: published, allocated and reconstructed counts and coverage, three allocations | [early_reconstruction.csv](../data/derived/early_reconstruction.csv) |
| Extended analysis datasets (18 intervals), one per allocation | `data/derived/panel_ext_H.csv`, `panel_ext_A.csv`, `panel_ext_N.csv` |
| Allocation by date, test of the assumption, boundary checks | [early_allocation_by_date.csv](../outputs/tables/early_allocation_by_date.csv), [early_persistence_test.csv](../outputs/tables/early_persistence_test.csv), [early_boundary_checks.csv](../outputs/tables/early_boundary_checks.csv) |
| Hazard ratios by period and variant | [early_period_associations.csv](../outputs/tables/early_period_associations.csv) |
| Modelled uptake for every county and early interval, with intervals | [early_modelled_uptake.csv](../outputs/tables/early_modelled_uptake.csv) |
| County relative uptake by period | [early_relative_uptake_by_period.csv](../outputs/tables/early_relative_uptake_by_period.csv) |
| DSHS news releases on eligibility (archived copies) | `data/raw/dshs_news/` |
