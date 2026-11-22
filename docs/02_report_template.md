# Bayesian spatiotemporal small-area analysis of COVID-19 vaccination coverage across Texas counties

Results report. The companion document, [01_source_inventory.md](01_source_inventory.md), lists every source, what
was verified in it, and why the age group, time intervals and study period differ from the original proposal.

Throughout, **recorded** means a number taken from Texas DSHS records and a Census population estimate, and
**modelled** means a posterior summary from the Bayesian model. Both describe vaccine receipt as recorded in the
state registry. Neither measures willingness or acceptance.

## 1. Summary

**What could be studied.** The records support first-dose coverage of residents aged 16 and over (not 18 and over),
for 254 counties, from 24 May 2021 to 9 May 2023, at the dates on which original DSHS workbooks survive. County
counts before mid-April 2021 are incomplete in a county-specific way, so the first five months of the rollout enter
only as the coverage each county had reached by 24 May 2021. Sixteen counties, most of them along the Mexican
border, have more recorded vaccinated adults than adult residents; they are shown but not modelled. A separate
extension, [03_early_rollout.md](03_early_rollout.md), reconstructs county coverage back to December 2020 under an
explicit assumption about the recipients who had no county on record; it is kept apart because nothing in this
report rests on that assumption.

**Recorded coverage.**

- Statewide, recorded 16+ first-dose coverage rose from 52.5% on 24 May 2021 to 82.3% on 9 May 2023. In the 238
  counties whose records can be read as resident coverage it rose from 50.9% to 77.2%.
- The median county went from 41.3% to 61.9%, a gain of 20.6 percentage points.
- **The gaps between counties widened.** The distance between the 90th- and 10th-percentile county grew from 21.7 to
  26.2 points, and the standard deviation across counties from 8.4 to 10.8 points. Counties that were ahead in May
  2021 gained more afterwards: each extra point of starting coverage went with 0.18 more points of later gain (95%
  confidence interval 0.11 to 0.24).
- County ranks barely moved (rank correlation between start and end 0.90); 71% of the counties in the lowest fifth in
  May 2021 were still there in May 2023.

**Modelled uptake among adults not yet vaccinated.**

- Pooled over the 238 counties, {{v:pool_k1}}% of still-unvaccinated adults received a first dose per 30 days in the
  first interval (25 May to 22 June 2021). The rate peaked at {{v:pool_k3}}% during the Delta wave (22 July to 21
  August 2021), stayed near 5% through January 2022, and was at or below 1% from June 2022. The median county was always
  below the pooled rate ({{v:med_k1}}% and {{v:med_k3}}% in the same two intervals) because the most populous
  counties vaccinated faster.
- Uptake differed widely between counties: the rate in the 90th-percentile county was {{v:rel_ratio}} times that in
  the 10th-percentile county. Rates were lowest in the Panhandle, the Rolling Plains and deep East Texas, and
  highest in the large metropolitan counties and South Texas. Counties with higher coverage in May 2021 also had
  higher uptake among their remaining unvaccinated adults afterwards ({{v:base_hr10_pt}} times higher per 10 points
  of starting coverage, 95% confidence interval {{v:base_hr10_ols}}), which is why the gaps widened.
- Counties with a larger share of older adults had lower later uptake (hazard ratio {{v:hr_age}} per
  {{v:sd_age_pts}} points of the 65+ share). Counties with more reported cases in the previous 30 days had higher
  uptake ({{v:hr_case}} per {{v:sd_case_fold}}-fold higher case rate). Household income was positively associated
  with coverage reached by May 2021 (odds ratio {{v:or_inc}} per {{v:sd_inc_pct}} higher income); its association
  with later uptake is {{v:hr_inc}}, an interval that includes no association.

**Model checks.**

- Spatial structure lowered the prediction error for counties with no data by {{v:impr_A_M1}} when random counties
  were withheld and by {{v:impr_B_M1}} when whole regions were, compared with the same model without it.
- Letting each county follow its own course over time (a mean-reverting process, model M4) lowered the error for a
  county's next interval by {{v:impr_C1_final}} and made the uncertainty intervals for later intervals better
  calibrated. It did not reduce the average error further ahead, and it made predictions for counties with no data
  {{v:worse_A_M4}} worse. No model was best at everything, so the report uses M4 for modelled uptake and the plain
  spatial model (M1) for statements about spatial structure. County results differ little between the two (median
  {{v:rob_med_M1}}).
- No model forecast the statewide level of the next interval well: forecasts for the two intervals after the
  Delta-wave peak and for the Omicron wave were 1.5 to 5 points per 30 days too high.
- Modelled uptake reproduces recorded uptake except in very small counties (median difference {{v:sm_large}} points
  per 30 days in counties with more than 50,000 adults, {{v:sm_small}} points below 5,000 adults). For
  {{v:n_distinct}} of {{v:n_local}} counties the county effect differs from its neighbours' with 95% posterior
  probability, so local differences are kept. A prediction from neighbours and predictors alone would miss a
  county's May 2023 coverage by {{v:ho_mae}} points on average.

**Main cautions.** Recorded coverage is a complete count, not a sample, so its uncertainty comes from the records
and the population estimates, not from sampling, and the credible intervals do not cover it. Uptake among "adults
not yet vaccinated" depends on a population estimate; where recorded coverage is high, a small error in that
estimate is a large error in the number of people left. Associations are between county characteristics and county
outcomes and say nothing about individuals.

## 2. What was analysed

| | |
|---|---|
| Outcome | Residents aged 16+ recorded with at least one COVID-19 vaccine dose, by county of residence |
| Source | "By County, Age" sheet of original Texas DSHS "COVID-19 Vaccine Data by County" workbooks, recovered from the Internet Archive (40 usable editions) |
| Recorded coverage | Count divided by the Census Bureau (Vintage 2025) estimate of residents aged 16+ on 1 July 2021 |
| Uptake in an interval | Adults newly recorded with a first dose, divided by adults not yet recorded as vaccinated at the start of the interval; reported per 30 days |
| Time grid | Baseline 24 May 2021, then 12 intervals to 9 May 2023: nine of 26 to 35 days (to 25 February 2022), then 94, 174 and 170 days |
| Counties | 254 described; 238 in the models |
| Predictors | Share of adults aged 65+ (Census estimates, 2021); median household income (ACS 2019-2023); confirmed plus probable COVID-19 cases reported in the 30 days before each interval, per 100,000 residents (DSHS) |
| Neighbours | Census county adjacency: 724 neighbouring pairs |

The proposal asked for adults 18+, calendar months, and a study period chosen from the verified overlap. The
inventory explains each change. In brief: the only 18+ county counts are in a CDC file that has no Texas data
before 22 October 2021 and disagrees with DSHS by up to 36% in individual counties; DSHS's own age bands start at
16; and its workbooks survive only on the dates the Internet Archive captured them.

## 3. Recorded coverage

### 3.1 The rollout before the baseline

Statewide, the rollout before the baseline can be described by month from the last DSHS edition's count of first
doses by date of vaccination. Everyone vaccinated in these months was 16 or older.

{{TABLE:Statewide first doses by month of vaccination, before the baseline}}

Uptake among adults not yet vaccinated was 8-9% per 30 days in January and February 2021 and about 22% in March and
April, as supply grew and eligibility widened (to everyone aged 16 and over from 29 March). The last column shows
reporting lag: what the state had published by the first day of the following month was 0.8 to 3.5 points below
what was eventually attributed to the month (no edition survives for 1 February 2021).

By county, no such description is possible without an assumption. Until the edition of 15 April 2021, 5-11% of
recipients had no county on record, and the correction added 1% to Harris County's count but 19% to Tarrant's and
25% to Denton's (Figure 1). The extension [03_early_rollout.md](03_early_rollout.md) makes the assumption explicit
and follows the counties from the first doses.

![Figure 1](../outputs/figures/fig01_unassigned_records.png)

*Figure 1. First-dose recipients without a county, and how unevenly the April 2021 correction fell.*

### 3.2 County coverage and change

![Figure 2](../outputs/figures/fig02_recorded_coverage_maps.png)

*Figure 2. Recorded 16+ first-dose coverage at the baseline, at the end of the near-monthly intervals, and at the end
of the study.*

![Figure 3](../outputs/figures/fig03_coverage_change_map.png)

*Figure 3. Percentage-point change in recorded coverage over the study.*

Recorded first doses, coverage and uptake by interval:

{{TABLE:Recorded first doses and coverage by interval}}

Coverage rose fastest between 22 July and 23 September 2021, during the Delta wave, when 12.6% and then 9.7% of
still-unvaccinated adults in the 238 counties were vaccinated per 30 days. From mid-2022 the rate was below 1% per
30 days.

The ten most populous counties kept in the analysis:

{{TABLE:Ten most populous kept counties}}

Largest and smallest recorded gains:

{{TABLE:Largest recorded gains (kept counties)}}

{{TABLE:Smallest recorded gains (kept counties)}}

La Salle County's recorded coverage (96.8%) is close to the ceiling and it borders flagged counties; its gain should
be read with the caution in section 3.4. The full county table is
[outputs/tables/county_results.csv](../outputs/tables/county_results.csv).

### 3.3 Did the gaps between counties widen or narrow?

They widened (Figure 4, upper panel).

{{TABLE:Recorded 16+ coverage across the 238 counties kept in the model}}

- The 10th percentile of county coverage rose by 19.1 points and the 90th percentile by 23.6.
- Later gains were positively related to starting coverage (Figure 4, lower panel): slope 0.18 points per point,
  correlation 0.32.
- In relative terms the divergence is larger. On 24 May 2021 the 10th-percentile county had 1.5 times the
  unvaccinated share of the 90th-percentile county (67.8% against 46.0%); on 9 May 2023 it had 2.2 times (48.7%
  against 22.4%).
- The gap had reached 24.4 points by 25 February 2022 and was 26.2 points at the end.

A widening in percentage points is not automatic. If every county vaccinated the same share of its remaining
unvaccinated adults, counties that started lower would gain more points and the gap would shrink. It grew because
uptake among the unvaccinated was itself higher where coverage was already higher (section 4.4).

![Figure 4](../outputs/figures/fig04_gaps_between_counties.png)

*Figure 4. Spread of recorded coverage across counties over time, and later gain against starting coverage.*

### 3.4 Counties whose records exceed their population

{{TABLE:Counties left out of the models (recorded count exceeds population estimate)}}

These 16 counties hold 8.8% of Texans aged 16+ but 35% of the adult first doses recorded statewide in
January-February 2022 and 55% of those recorded between November 2022 and May 2023. Their counts keep rising long
after they pass 100% of the population estimate. Fourteen of the 16 are in South Texas or along the Rio Grande;
Reeves and Loving are in the far-west oil field. The records do not identify the recipients. A plausible reading,
which these files cannot confirm, is that people who were not usual residents (cross-border patients, people held
in custody, temporary workers) were recorded at local addresses. The counts are reported as recorded and are not
interpreted as resident coverage. Statewide figures that include these counties (the "all counties" columns of the
interval table) are inflated to an unknown degree for the same reason.

## 4. Modelled uptake

### 4.1 Model

For county *i* and interval *k* of length *d* days:

```
new first doses[i,k] ~ Binomial(adults not yet vaccinated[i,k], p[i,k])

log(-log(1 - p[i,k])) = log(d[k] / 30)
                        + intercept
                        + b_age * age[i] + b_income * income[i] + b_cases * cases[i,k]
                        + time[k]            shared time effect (random walk over interval midpoints)
                        + county[i]          county effect
                        + path[i,k]          county-specific course over time (models M2-M4)
                        + deviation[i,k]     county-interval deviation
```

The complementary log-log link with the interval length as an offset means that everything on the right-hand side
describes the rate per 30 days at which still-unvaccinated adults are vaccinated (a hazard), whatever the length of
the interval. Exponentiated coefficients are hazard ratios.

| Model | County effect | County-specific course |
|---|---|---|
| M0 | Independent across counties (no spatial structure) | none |
| M1 | BYM2: a spatially smooth part shared with neighbours plus an independent part | none |
| M2 | BYM2 | a straight-line trend per county |
| M3 | BYM2 | a random walk per county, summing to zero over time (Knorr-Held type II) |
| M4 | BYM2 | a mean-reverting process per county in continuous time (Ornstein-Uhlenbeck) |

The county-interval deviation absorbs variation beyond the binomial. Without it, counties with millions of
residents would be treated as measured without error and would dictate every estimate. Predictors are standardised.
Standard deviations have penalised-complexity priors with a 1% prior probability of exceeding 1 on the log-hazard
scale; the BYM2 mixing parameter has prior probability two-thirds of being below 0.5. The models were fitted with
R-INLA 26.08.07 (integrated nested Laplace approximation). Medians and 95% credible intervals of coefficients and
variance parameters are quantiles of R-INLA's posterior marginals; those of quantities that combine several
parameters (county rates, relative uptake, modelled change in coverage) come from 1,000 joint posterior draws.
Partial pooling enters through the county effect, the county course and the deviation:
where a county-interval has few events its estimate leans on the county's other intervals, its neighbours and its
predictors, and where it has many the estimate follows the count.

A second, cross-sectional model describes the coverage each county had reached at the baseline (binomial, logit
link, BYM2 county effect, the same age and income predictors, and cumulative reported cases before vaccination
began on 14 December 2020).

### 4.2 Which model predicts best

Four out-of-sample experiments, each refitting the model with the tested county-intervals withheld:

- **A. Counties with no data.** Ten random folds of counties; every interval of the held-out counties is predicted.
- **B. Regions with no data.** Each of the eight DSHS public health regions is held out in turn, so most of a held-out
  county's neighbours are held out with it.
- **C. Later intervals.** For a random half of the counties, every interval after an origin (21 August 2021, 20
  November 2021 or 25 February 2022) is withheld while the other half stays observed. The statewide level of the
  later intervals is then known, and the test isolates what the model knows about each county's own course.
- **D. Next interval.** Everything after an origin is withheld for all counties and the next interval is predicted,
  for nine origins. This is a true forecast.

![Figure 5](../outputs/figures/fig05_validation.png)

*Figure 5. Mean continuous ranked probability score by model and experiment.*

{{TABLE:Out-of-sample performance (lower CRPS and errors are better; higher log score and correlation are better)}}

The continuous ranked probability score (CRPS) measures how far the whole predictive distribution lies from what
was recorded, in percentage points of uptake per 30 days; lower is better. The log score is the log of the
probability the prediction gave to the recorded count; higher is better, and it penalises a confident miss much
more heavily than CRPS does. "Relative log-hazard correlation" is the correlation between predicted and recorded
county positions within an interval, after removing whatever error all counties share. "End coverage" is coverage
on 9 May 2023 computed from the predicted interval rates.

The statements below rest on differences between models scored on the same county-intervals. The next table gives
those differences with 95% intervals obtained by resampling whole counties (whole forecast origins in experiment
D, where every county shares the error in the statewide level, so there are only nine independent units).

{{TABLE:Differences between models on the same county-intervals (second model minus first, 95% bootstrap interval)}}

**Counties with no data (A, B): spatial structure helps.** With random counties withheld, the BYM2 model's CRPS is
{{v:crps_A_M1}} against {{v:crps_A_M0}} for the non-spatial model ({{v:impr_A_M1}} lower). Its 95% predictive
intervals are narrower ({{v:width_A_M1}} against {{v:width_A_M0}} points) and contain the recorded count as often
({{v:cov1_A_M1}} against {{v:cov1_A_M0}}). It predicts a withheld county's coverage on 9 May 2023 to within
{{v:end_A_M1}} points on average, against {{v:end_A_M0}}. With whole regions withheld the CRPS advantage is
{{v:impr_B_M1}} ({{v:crps_B_M1}} against {{v:crps_B_M0}}), but the model then says much less about which county in
the region is ahead of which: the correlation between predicted and recorded county positions is {{v:cor_B_M1}},
against {{v:cor_A_M1}} when only scattered counties are withheld.

County-specific courses cannot help a county that has no data. A straight-line trend per county (M2) leaves the
CRPS where it was ({{v:crps_A_M2}} in A, {{v:crps_B_M2}} in B). The mean-reverting course (M4) makes it
{{v:worse_A_M4}} worse in experiment A ({{v:crps_A_M4}}) and {{v:worse_B_M4}} worse in experiment B
({{v:crps_B_M4}}). M4's intervals for an unseen county are wider ({{v:width_A_M4}} points against
{{v:width_A_M1}}), because part of what sets a county apart is carried by its own course, which its neighbours
cannot inform. Its CRPS stays below the non-spatial model's in both experiments (M4 minus M0:
{{v:d_crps_A_M0_M4}} in A and {{v:d_crps_B_M0_M4}} in B), though in A the interval for that difference reaches zero.

**Later intervals (C): county-specific courses help the next interval and the calibration, not the average error
further ahead.** Over all withheld intervals the CRPS is almost the same for every model: {{v:crps_C_M0}},
{{v:crps_C_M1}}, {{v:crps_C_M2}}, {{v:crps_C_M3}} and {{v:crps_C_M4}} for M0 to M4. The difference is in the first
withheld interval, where M4 scores {{v:crps_C1_M4}} and M3 {{v:crps_C1_M3}} against {{v:crps_C1_M1}} for M1 (M4 is
{{v:impr_C1_final}} lower). Further ahead the county-specific courses bring no reduction in CRPS: M4 minus M1 is
{{v:d_crps_C23_M1_M4}} two to three intervals ahead and {{v:d_crps_C4_M1_M4}} four or more ahead.

What improves at every horizon is how honest the predictions are about their uncertainty. The log score is higher
for all three models with county-specific courses (M4 minus M1: {{v:d_ls_C_M1_M4}}). Their 95% intervals contained
the recorded count more often: {{v:cov1_C_M3}} for M3, {{v:cov1_C_M4}} for M4 and {{v:cov1_C_M2}} for M2, against
{{v:cov1_C_M1}} for M1. All are below the nominal 95%, so every model is somewhat overconfident about later
intervals. The intervals for coverage on 9 May 2023 contained the recorded figure for {{v:endin_C_M3}} of withheld
counties with M3 and {{v:endin_C_M4}} with M4, against {{v:endin_C_M1}} with M1. The average error of that coverage
prediction is nearly the same for every model ({{v:end_C_M4}} points for M4, {{v:end_C_M1}} for M1). Spatial
structure makes no difference in this experiment (M1 minus M0: {{v:d_crps_C_M0_M1}} points of CRPS), because a
county's own history is more informative than its neighbours.

M3 and M4 are close. M4 has the lower CRPS (M4 minus M3: {{v:d_crps_C_M3_M4}}) and M3 the higher log score
({{v:d_ls_C_M3_M4}}), which comes from intervals two or more steps ahead; for the next interval the two are
indistinguishable.

**Next interval (D): no model forecasts the statewide level.** CRPS is {{v:crps_D_M0}}, {{v:crps_D_M1}},
{{v:crps_D_M2}}, {{v:crps_D_M3}} and {{v:crps_D_M4}} for M0 to M4, well above the one-interval-ahead error in
experiment C ({{v:crps_C1_M4}} for M4), where the statewide level was known. Most of the excess comes from three of
the nine forecasts, in which every model predicted too much uptake:

{{TABLE:Experiment D by forecast interval: mean error, predicted minus recorded (points per 30 days)}}

The two intervals after the Delta-wave peak and the interval of the Omicron wave were forecast 1.5 to 5 points per
30 days too high. The models carry the last level forward, and nothing in them anticipates the end of a surge. The
case-rate predictor does not help here: it describes differences between counties at the same time, and during the
Omicron wave uptake halved while reported cases rose to their highest level. With only nine forecasts the
differences between models are imprecise: M4's CRPS is lower than M1's by an amount whose interval includes zero
({{v:d_crps_D_M1_M4}}) and lower than M3's ({{v:d_crps_D_M3_M4}}). The
models still place counties correctly relative to one another: the correlation between predicted and recorded
county positions in the next interval is {{v:cor_D_M4}} for M4 and {{v:cor_D_M0}} for M0.

**Which model is used for what.** No model is best at everything.

- **{{v:final}} is used for modelled uptake** (sections 4.3 to 4.5). It has the lowest CRPS in experiment C, the
  best scores for a county's next interval, and the best leave-one-out score below. Those are the tests closest to
  what partial pooling has to do in this study: steady the estimate for a county-interval with few events by using
  the same county's other intervals. M3 is the close alternative, with better-calibrated predictions two or more
  intervals ahead and a slightly higher CRPS. M4 was preferred because it is at least as good at the nearest
  interval and each fit takes about one minute instead of about ten, which made it practical to refit it in every
  validation experiment and in the sensitivity analysis.
- **{{v:spatial}} is used for statements about spatial structure** (the share of variance that is spatially
  structured, the right-hand map of Figure 8) and for the neighbours-only check in section 5. It is the simplest
  of the models that do best for counties with no data (M2 matches it there), and its county effect separates
  cleanly into a smooth part and an independent part.

The choice matters little for what is reported below. County relative uptake (section 4.4) computed from M3 instead
of M4 differs by a median of {{v:rob_med_M3}} and by more than {{v:rob_p95_M3}} in one county in twenty; the
largest difference is {{v:rob_max_M3}} ({{v:rob_maxcounty_M3}}). Computed from M1, the median difference is
{{v:rob_med_M1}} and the largest {{v:rob_max_M1}} ({{v:rob_maxcounty_M1}}). The predictor associations are similar
in all five models (section 4.5). M3 was run only in experiments C and D, because of the time its fits take.

In-sample statistics separate the models poorly, because the county-interval deviation lets every model reproduce
the data it was fitted to. WAIC differs by only {{v:waic_spread}} units in about {{v:waic_level}} between the best
and the worst model, and it puts {{v:waic_worst}} last. With about {{v:pwaic}} effective parameters for
{{v:n_usable}} county-intervals WAIC is outside the range in which it is reliable, and what it measures here is
mostly how well a model would predict a repeat count for the same county-interval with its deviation known, which
every model does equally well. It is shown for completeness and was not used to choose a model. The leave-one-out
measure (mean log conditional predictive ordinate, higher is better) withholds the county-interval itself. It
puts M4 first and, like the log score in experiment C, puts the three models with county-specific courses ahead of
the two without. R-INLA flagged its leave-one-out approximation as unreliable for {{v:cpo_fail_M3}} county-intervals
under M3 and {{v:cpo_fail_M2}} under M2, against {{v:cpo_fail_M4}} under M4, so the M2 and M3 values are less secure.

{{TABLE:In-sample statistics}}

Variance parameters of the five models:

{{TABLE:Variance parameters of the fitted models (posterior median, 95% credible interval)}}

### 4.3 Uptake over time

![Figure 6](../outputs/figures/fig06_uptake_curves.png)

*Figure 6. Uptake per 30 days among adults not yet vaccinated: all 238 counties pooled, the median county with the
10th-90th percentile range, and counties grouped by their coverage at baseline.*

Pooled over the 238 counties, the rate fell from {{v:pool_k1}}% per 30 days (25 May to 22 June 2021) to
{{v:pool_k2}}%, doubled to {{v:pool_k3}}% from 22 July to 21 August 2021 as the Delta wave arrived, and eased to
{{v:pool_k4}}% and then to about 5% for the four intervals from late September 2021 to late January 2022. It was
{{v:pool_k9}}% from 22 January to 25 February 2022, {{v:pool_k10}}% to 30 May 2022, {{v:pool_k11}}% to 20 November
2022 and {{v:pool_k12}}% to 9 May 2023.

The typical county was well below the pooled rate throughout. The modelled median county ran at {{v:med_k1}}% in the
first interval and {{v:med_k3}}% at the peak, when the 10th- and 90th-percentile counties were at {{v:p10_k3}}% and
{{v:p90_k3}}%. In every interval the third of counties with the highest coverage at baseline also had the highest
uptake rate among their remaining unvaccinated adults (Figure 6, lower panel).

![Figure 7](../outputs/figures/fig07_county_examples.png)

*Figure 7. Recorded and modelled uptake in six counties, with 95% credible intervals.*

Figure 7 shows what the model adds to the records. In Harris County the modelled rate equals the recorded one and
its interval is too narrow to see. In King County, with 198 adults, one first dose moves the recorded rate by more
than half a percentage point; the modelled rate follows the county's general level and its interval is wide.

### 4.4 Where uptake was higher or lower

![Figure 8](../outputs/figures/fig08_relative_uptake_maps.png)

*Figure 8. Modelled uptake relative to the average county (left, model {{v:final}}) and the spatially smooth part of
the county effect that the predictors do not explain (right, model {{v:spatial}}).*

![Figure 9](../outputs/figures/fig09_relative_uptake_extremes.png)

*Figure 9. The 12 highest and 12 lowest counties, with 95% credible intervals.*

Figure 8 (left) maps each county's modelled uptake rate relative to the average county, averaged over the 12
intervals. The 10th-percentile county is at {{v:rel_p10}} and the 90th-percentile county at {{v:rel_p90}}, a
{{v:rel_ratio}}-fold difference. For {{v:n_low}} of the {{v:n_kept}} counties the 95% credible interval lies wholly
below 1 and for {{v:n_high}} wholly above. The six most populous counties are all above the average county
({{v:rel_big}}). The lowest county is {{v:rel_min_county}} at {{v:rel_min}} and the highest {{v:rel_max_county}} at
{{v:rel_max}}. Several of the highest are small South Texas counties next to flagged ones (La Salle, Zavala, Jim
Hogg), where non-resident recipients may also be present.

Starting coverage and later uptake go together: across the {{v:n_kept}} counties the correlation between coverage
on 24 May 2021 and modelled relative uptake afterwards is {{v:base_cor_pt}}, and uptake was {{v:base_hr10_pt}} times
higher per 10 points of starting coverage (95% confidence interval {{v:base_hr10_ols}}, from the scatter between
counties). This describes these counties; it is not adjusted for the three predictors.

The right-hand map shows the part of the county effect that is spatially smooth and not explained by the three
predictors. In the model without county-specific courses (M1), {{v:phi_m1_pct}} of the between-county variance left
after the predictors is of this spatially structured kind (posterior median and 95% credible interval
{{v:phi_m1}}). The standard deviation of the county effect is {{v:sd_county_m1}} on the log scale: a county at the
97.5th percentile of that effect has {{v:county_fold_m1}} times the uptake rate of one at the 2.5th percentile with
the same predictors. Coverage reached by 24 May 2021 was spatially structured to a similar or greater degree: in
the baseline model the structured share of the county effect is {{v:base_phi}}.

Counties also drift around their own level. In {{v:final}} the county-specific course has a standard
deviation of {{v:sd_path_final}} and a half-life of {{v:ou_halflife}}: a county running above its usual level is,
on average, half as far above it that much later.

### 4.5 Associations with age composition, income and recent cases

![Figure 10](../outputs/figures/fig10_predictor_associations.png)

*Figure 10. County-level associations, per standard deviation of each predictor.*

{{TABLE:Predictor associations, selected model and baseline model}}

- **Age composition.** One standard deviation is {{v:sd_age_pts}} points of the share of adults aged 65+. By 24 May
  2021 counties with older adult populations had, if anything, slightly higher coverage (odds ratio {{v:or_age}}),
  consistent with people aged 65+ having been eligible since late December 2020. Afterwards the direction is the
  opposite: uptake among adults still unvaccinated was lower in older counties (hazard ratio {{v:hr_age}}; per 5
  points of the 65+ share, {{v:hr_age_5}}).
- **Household income.** One standard deviation is a {{v:sd_inc_pct}} difference in median household income.
  Higher-income counties had higher coverage at baseline (odds ratio {{v:or_inc}}). For later uptake the hazard
  ratio is {{v:hr_inc}} (per 10% higher income, {{v:hr_inc_10}}).
- **Recent cases.** One standard deviation is a {{v:sd_case_fold}}-fold difference in cases reported in the previous
  30 days. The hazard ratio is {{v:hr_case}} ({{v:hr_case_dbl}} per doubling). Because the model has a shared time
  effect, this compares counties with more and fewer reported cases at the same time; the statewide rise in uptake
  during the Delta wave is in the time effect, not in this coefficient. At baseline, counties with more cumulative
  reported cases before vaccination began had higher coverage (odds ratio {{v:or_case}}).

The associations by period, from a version of {{v:final}} with separate coefficients for three periods:

{{TABLE:Hazard ratios per standard deviation by period}}

The age association is below 1 in all three periods and somewhat stronger later. The association with recent cases
is clearest in the summer of 2021 ({{v:hr_cases_P1}}) and weakest in the period that includes the Omicron wave
({{v:hr_cases_P2}}), where its interval reaches 1. Income shows no association in the first period
({{v:hr_income_P1}}) and a positive one only in the last ({{v:hr_income_P3}}).

The choice of model changes the coefficients little (hazard ratio per standard deviation, 95% credible interval):

{{TABLE:Hazard ratios per standard deviation, all uptake models}}

These are associations between county characteristics and county outcomes. Older and lower-income counties in Texas
are also more rural and differ in many unmeasured ways, so the coefficients should not be read as effects of age or
income, and they do not describe individuals.

## 5. Does smoothing hide local differences?

![Figure 11](../outputs/figures/fig11_smoothing_checks.png)

*Figure 11. Recorded against modelled uptake by county size (upper), and the error made when a county's coverage is
predicted from its neighbours and predictors alone (lower).*

For the fitted model the answer is no, because each county's estimate rests mainly on its own counts. Three checks:

1. **Modelled uptake against recorded uptake.** In counties with more than 50,000 adults the two differ by a median
   of {{v:sm_large}} points per 30 days, and in counties with 5,000 to 50,000 adults by {{v:sm_mid}} points
   ({{v:sm_mid_rel}} of the recorded rate). Only below 5,000 adults does the model move the estimate noticeably:
   {{v:sm_small}} points, or {{v:sm_small_rel}} of the recorded rate (Figure 11, upper panel).

{{TABLE:Recorded versus modelled uptake by county size}}

2. **Differences from neighbours survive.** For {{v:n_distinct}} of {{v:n_local}} counties the county effect differs
   from the mean of its neighbours' effects with at least 95% posterior probability ({{v:n_distinct_low}} lower,
   {{v:n_distinct_high}} higher). The counties that stand furthest from their neighbours:

{{TABLE:Counties most different from the mean of their neighbours (residual county effect ratio)}}

3. **What smoothing alone would have done.** Experiment A predicts each county from the others without using its
   own uptake data, which is what a purely smoothed map would show. With {{v:spatial}}, which does as well as any
   model at this task, coverage on 9 May 2023 predicted that way misses the recorded figure by a mean of
   {{v:ho_mae}} points (median {{v:ho_median}}), by more than 5 points in {{v:ho_over5}} of {{v:ho_n}} counties and
   by more than 10 points in {{v:ho_over10}} (Figure 11, lower panel). The largest miss is {{v:ho_worst}}.

So the spatial pattern is real (Moran's I of the county effects from the non-spatial model is {{v:moran}}), and
neighbours are informative, but neighbours alone would hide persistent local differences of several points of
coverage. The fitted model does not hide them. The smoothing matters only for very small counties and for the 16
counties with no usable data, for which no modelled estimate is reported.

## 6. What the credible intervals cover, and what they do not

**Recorded coverage is observed.** The registry is meant to hold every dose given to a county's residents, so
recorded coverage is a complete count rather than an estimate from a sample. It has no sampling error and is
reported without intervals. The model does not improve on it; for the cumulative change in coverage over the study
the modelled and recorded figures differ by a median of {{v:chg_med}} points across counties (largest difference
{{v:chg_max}} points).

**What the model's intervals include:** chance variation in the number of first doses given a county's underlying
rate; uncertainty about that rate where numbers are small; uncertainty in the county, time and county-course
effects, in the predictor coefficients and in the variance parameters.

**What they leave out:**

- *Errors in the counts.* After April 2021, 1.2% to 3.0% of first-dose recipients statewide have no county. A few
  percent of each interval's doses are reported late and land in the next interval. Record corrections move small
  numbers between counties. Recipients who are not residents are counted where they were recorded. Doses given by
  federal agencies may be missing: CDC's count for Bell County (Fort Hood) is 36% above DSHS's. As a general check,
  CDC's 18+ coverage and DSHS's 16+ coverage, computed on the same population estimates, agreed closely across the
  modelled counties on 26 October 2021 (correlation {{v:cdc0_cor}}, median absolute difference {{v:cdc0_medabs}}
  points, more than 5 points apart in {{v:cdc0_over5}} counties). By 9 May 2023 they agreed less well (rank
  correlation {{v:cdc_rank}}, median absolute difference {{v:cdc_medabs}} points, more than 5 points apart in
  {{v:cdc_over5}} counties and more than 10 in {{v:cdc_over10}}).
- *Errors in the population estimates.* The denominator is an estimate for one date, 1 July 2021. The numerator
  keeps people who later died or moved away and misses doses that newcomers received elsewhere, and DSHS appears to
  classify people by age at vaccination while the population ages.
- *Model form.* Other reasonable models would give somewhat different intervals.

**Why denominator error matters most where coverage is high.** The number of adults "not yet vaccinated" is the
population estimate minus the recorded count. A 3% error in the population estimate changes that number by 6% when
recorded coverage is 50%, by 12% at 75% and by 30% at 90%. Uptake rates for high-coverage counties late in the study
are therefore the least reliable numbers in this report, and county-intervals starting at 95% or more were not
modelled at all.

**Sensitivity of the main results to the choices made** (each row refits {{v:final}}; hazard ratios per standard
deviation with 95% credible intervals):

{{TABLE:Sensitivity analysis}}

Across the {{v:sens_n}} alternatives the hazard ratio per standard deviation ranges from {{v:sens_age}} for the 65+
share, {{v:sens_inc}} for income and {{v:sens_case}} for recent cases.

- **Age composition.** The hazard ratio is below 1 in every variant. It is furthest from 1 with the 2019 denominators
  that DSHS used (S3, {{v:s_S3_age}}).
- **Recent cases.** Above 1 in every variant, and smallest when the last year is cut into finer intervals (S2,
  {{v:s_S2_case}}).
- **Income.** The least stable of the three. It is {{v:s_S0_inc}} in the main analysis, {{v:s_S10_inc}} when the
  study ends in May 2022, {{v:s_S3_inc}} with the 2019 denominators and {{v:s_S9_inc}} when the kept counties that
  border flagged ones are also left out. The data do not settle whether income is associated with later uptake.
- **Flagged counties.** Keeping them until their recorded coverage reaches 95% (S4) moves the income ratio to
  {{v:s_S4_inc}} and raises the standard deviation of the county effect, which is what counties that do not behave
  like the rest would do.
- **Uptake per adult resident** instead of per adult not yet vaccinated (S8) gives the same directions:
  {{v:s_S8_age}}, {{v:s_S8_inc}} and {{v:s_S8_case}}.
- **The approximation.** Refitting with R-INLA's older approximation strategy (S12) gives {{v:s_S12_age}},
  {{v:s_S12_inc}} and {{v:s_S12_case}}, the same as the main analysis.

## 7. Limitations

- **Sixteen counties and 8.8% of adults are outside the models**, including El Paso, Hidalgo, Cameron and Webb.
  Conclusions about gaps and associations are about the other 238 counties.
- **The first five months of the rollout are not modelled in this report.** They are represented by coverage on
  24 May 2021. A county series for December 2020 to May 2021 needs an assumption about where the then-unassigned
  recipients lived; [03_early_rollout.md](03_early_rollout.md) builds one, tests it and shows how little of its
  conclusions depends on it. One of its findings bears on section 4.5: the negative association with the share of
  older adults begins in April 2021, when eligibility opened to all adults.
- **Adults means 16 and over**, the youngest adult band in the records.
- **Intervals are unequal** and three are long. Month-level detail after February 2022 is not recoverable from the
  surviving files.
- **Counties with large institutions.** A prison, military base or university puts people in the population estimate
  whose vaccinations may be recorded elsewhere or by another system, which lowers recorded coverage. The records
  cannot separate this from real differences in uptake. The CDC comparison suggests it matters in places: CDC's
  count is 36% above DSHS's in Bell County (Fort Hood) and 24% above in Live Oak County, one of the counties that
  differs most from its neighbours.
- **Reported cases** changed character on 1 January 2022 (final counts before, provisional daily reports after),
  omit home tests, and reflect testing as well as infection.
- **Three predictors only.** Age composition and income are correlated with rurality, health-care access, political
  preference and ethnic composition, none of which is in the model. The coefficients describe which counties had
  higher uptake, not why.
- **Approximate inference.** R-INLA approximates the posterior. A second approximation strategy gave the same
  estimates (variant S12), but no simulation-based (MCMC) fit was run to confirm them.

## 8. Reproducing and tracing results

[README.md](../README.md) lists the commands. Every raw file is in `data/raw/` with its address and SHA-256 in
[data/raw/MANIFEST.csv](../data/raw/MANIFEST.csv). The numbers in this report's tables are produced by
[R/10_report_tables.R](../R/10_report_tables.R) from the CSV files in `outputs/tables/`; the figures and their data
by [R/08_outputs.R](../R/08_outputs.R).

| Result | File |
|---|---|
| County results (recorded coverage, change, modelled relative uptake with intervals) | [county_results.csv](../outputs/tables/county_results.csv) |
| Modelled uptake for every county and interval, with intervals | [modelled_uptake_county_interval.csv](../outputs/tables/modelled_uptake_county_interval.csv) |
| Gap measures at every edition | [fig04_gap_over_time.csv](../outputs/tables/fig04_gap_over_time.csv) |
| Model parameters | [fixed_effects.csv](../outputs/models/fixed_effects.csv), [hyperparameters.csv](../outputs/models/hyperparameters.csv) |
| Validation scores, row by row | `outputs/tables/validation_*_rows_*.csv` |
| Differences between models with bootstrap intervals | [validation_paired_differences.csv](../outputs/tables/validation_paired_differences.csv) |
| County relative uptake under each of the five models | [relative_uptake_by_model.csv](../outputs/tables/relative_uptake_by_model.csv) |
| Sensitivity analysis | [sensitivity.csv](../outputs/tables/sensitivity.csv) |
| Analysis dataset | [panel.csv](../data/derived/panel.csv) |
| Extension to December 2020 - May 2021 | [03_early_rollout.md](03_early_rollout.md) |
