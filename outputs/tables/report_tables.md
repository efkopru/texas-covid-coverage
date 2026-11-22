
### Recorded first doses and coverage by interval

| Interval | Records | Days | New first doses, all counties | Coverage at end, all counties (%) | Uptake per 30 days, all counties (%) | Coverage at end, 238 counties (%) | Uptake per 30 days, 238 counties (%) |
|---|---|---|---|---|---|---|---|
| 1 | 25 May 2021 - 22 Jun 2021 | 29 | 949,237 | 56.59 | 8.95 | 54.85 | 8.38 |
| 2 | 23 Jun 2021 - 21 Jul 2021 | 29 | 642,359 | 59.38 | 6.63 | 57.48 | 6.02 |
| 3 | 22 Jul 2021 - 21 Aug 2021 | 31 | 1,288,098 | 64.97 | 13.34 | 62.99 | 12.56 |
| 4 | 22 Aug 2021 - 23 Sep 2021 | 33 | 912,048 | 68.92 | 10.32 | 66.92 | 9.70 |
| 5 | 24 Sep 2021 - 25 Oct 2021 | 32 | 436,759 | 70.82 | 5.73 | 68.77 | 5.25 |
| 6 | 26 Oct 2021 - 20 Nov 2021 | 26 | 363,638 | 72.40 | 6.21 | 70.20 | 5.26 |
| 7 | 21 Nov 2021 - 21 Dec 2021 | 31 | 418,625 | 74.21 | 6.37 | 71.78 | 5.14 |
| 8 | 22 Dec 2021 - 21 Jan 2022 | 31 | 417,417 | 76.02 | 6.80 | 73.35 | 5.37 |
| 9 | 22 Jan 2022 - 25 Feb 2022 | 35 | 270,529 | 77.20 | 4.21 | 74.18 | 2.69 |
| 10 | 26 Feb 2022 - 30 May 2022 | 94 | 400,641 | 78.93 | 2.50 | 75.25 | 1.34 |
| 11 | 31 May 2022 - 20 Nov 2022 | 174 | 490,828 | 81.06 | 1.82 | 76.61 | 0.97 |
| 12 | 21 Nov 2022 - 09 May 2023 | 170 | 284,085 | 82.30 | 1.18 | 77.22 | 0.46 |

### Statewide first doses by month of vaccination, before the baseline

| Month of vaccination | First doses | Texans 16+ with a first dose at month end (%) | Uptake among those not yet vaccinated, per 30 days (%) | Coverage the state reported at the time (%) |
|---|---|---|---|---|
| December 2020 | 514,176 | 2.2 | 3.7 | 1.5 |
| January 2021 | 1,827,899 | 10.2 | 7.9 |  |
| February 2021 | 1,703,270 | 17.5 | 8.8 | 15.5 |
| March 2021 | 4,360,448 | 36.5 | 22.3 | 32.9 |
| April 2021 | 3,194,801 | 50.3 | 21.8 | 48.1 |

### Recorded 16+ coverage across the 238 counties kept in the model

| Records through | 10th percentile | 25th | Median | 75th | 90th percentile | Gap 90th - 10th (points) | Standard deviation | Pooled coverage |
|---|---|---|---|---|---|---|---|---|
| 24 May 2021 | 32.23 | 36.33 | 41.27 | 47.25 | 53.95 | 21.73 | 8.42 | 50.86 |
| 23 Sep 2021 | 44.68 | 48.45 | 54.49 | 61.36 | 67.56 | 22.87 | 9.68 | 66.92 |
| 25 Feb 2022 | 49.86 | 54.46 | 60.21 | 67.89 | 74.23 | 24.37 | 10.34 | 74.18 |
| 30 May 2022 | 50.68 | 55.14 | 61.02 | 68.65 | 75.29 | 24.60 | 10.47 | 75.25 |
| 09 May 2023 | 51.33 | 55.89 | 61.91 | 70.37 | 77.57 | 26.24 | 10.82 | 77.22 |

### Gap summary

| measure | value |
|---|---|
| Counties | 238.00 |
| Gap between 90th and 10th percentile county, baseline (points) | 21.73 |
| Gap, end (points) | 26.24 |
| Standard deviation across counties, baseline (points) | 8.42 |
| Standard deviation, end (points) | 10.82 |
| Population-weighted standard deviation, baseline | 8.63 |
| Population-weighted standard deviation, end | 11.28 |
| Slope of change on baseline coverage (points per point) | 0.18 |
| Slope, 95% confidence interval low | 0.11 |
| Slope, high | 0.24 |
| Correlation of baseline coverage with change | 0.32 |
| Rank correlation of baseline with end coverage | 0.90 |
| Bottom-fifth counties at baseline still in bottom fifth at end (%) | 70.83 |
| Unvaccinated share ratio, 10th vs 90th percentile county, baseline | 1.47 |
| Unvaccinated share ratio, end | 2.17 |

### Out-of-sample performance (lower CRPS and errors are better; higher log score and correlation are better)

| Experiment | Model | County-intervals | Mean CRPS (points) | Mean absolute error (points) | Mean log score | 95% interval coverage | Mean 95% interval width (points) | Relative log-hazard RMSE | Relative log-hazard correlation | End coverage: counties | End coverage: mean abs. error (points) | End coverage: inside 95% interval |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A. Counties with no data (10 random folds) | M0 | 2,855 | 0.888 | 1.173 | -6.152 | 0.930 | 7.46 | 0.542 | 0.292 | 237 | 4.59 | 0.966 |
| A. Counties with no data (10 random folds) | M1 | 2,855 | 0.768 | 1.034 | -6.003 | 0.934 | 6.40 | 0.471 | 0.557 | 237 | 3.65 | 0.966 |
| A. Counties with no data (10 random folds) | M2 | 2,855 | 0.769 | 1.035 | -5.972 | 0.936 | 6.32 | 0.470 | 0.558 | 237 | 3.65 | 0.970 |
| A. Counties with no data (10 random folds) | M4 | 2,855 | 0.829 | 1.101 | -6.028 | 0.957 | 8.09 | 0.478 | 0.549 | 237 | 4.02 | 0.987 |
| B. Regions with no data (8 public health regions) | M0 | 2,855 | 0.921 | 1.214 | -6.198 | 0.925 | 7.55 | 0.491 | 0.314 | 237 | 4.84 | 0.949 |
| B. Regions with no data (8 public health regions) | M1 | 2,855 | 0.803 | 1.075 | -6.074 | 0.930 | 6.49 | 0.479 | 0.373 | 237 | 3.88 | 0.962 |
| B. Regions with no data (8 public health regions) | M2 | 2,855 | 0.807 | 1.080 | -6.051 | 0.930 | 6.41 | 0.480 | 0.370 | 237 | 3.90 | 0.966 |
| B. Regions with no data (8 public health regions) | M4 | 2,855 | 0.845 | 1.105 | -6.086 | 0.956 | 8.10 | 0.482 | 0.370 | 237 | 4.09 | 0.992 |
| C. Later intervals, half the counties withheld | M0 | 4,281 | 0.420 | 0.559 | -5.793 | 0.874 | 2.81 | 0.491 | 0.687 | 711 | 1.23 | 0.796 |
| C. Later intervals, half the counties withheld | M1 | 4,281 | 0.419 | 0.565 | -5.782 | 0.875 | 2.77 | 0.485 | 0.694 | 711 | 1.22 | 0.789 |
| C. Later intervals, half the counties withheld | M2 | 4,281 | 0.421 | 0.572 | -5.655 | 0.896 | 2.60 | 0.499 | 0.665 | 711 | 1.24 | 0.844 |
| C. Later intervals, half the counties withheld | M3 | 4,281 | 0.423 | 0.577 | -5.609 | 0.915 | 2.70 | 0.501 | 0.665 | 711 | 1.28 | 0.890 |
| C. Later intervals, half the counties withheld | M4 | 4,281 | 0.412 | 0.558 | -5.647 | 0.906 | 2.84 | 0.486 | 0.692 | 711 | 1.20 | 0.880 |
| D. Next interval, all counties withheld | M0 | 2,141 | 1.121 | 1.514 | -6.174 | 0.937 | 10.70 | 0.430 | 0.724 |  |  |  |
| D. Next interval, all counties withheld | M1 | 2,141 | 1.058 | 1.407 | -6.152 | 0.938 | 10.41 | 0.430 | 0.724 |  |  |  |
| D. Next interval, all counties withheld | M2 | 2,141 | 1.048 | 1.399 | -6.138 | 0.944 | 10.60 | 0.423 | 0.725 |  |  |  |
| D. Next interval, all counties withheld | M3 | 2,141 | 1.063 | 1.423 | -6.165 | 0.939 | 10.63 | 0.419 | 0.734 |  |  |  |
| D. Next interval, all counties withheld | M4 | 2,141 | 1.033 | 1.368 | -6.129 | 0.950 | 10.59 | 0.421 | 0.737 |  |  |  |

### In-sample statistics

| Model | WAIC | Mean log CPO | CPO values flagged | Seconds to fit |
|---|---|---|---|---|
| M0 non-spatial county effects | 25,737 | -5.971 | 0 | 4 |
| M1 BYM2 county effects | 25,732 | -5.956 | 0 | 30 |
| M2 BYM2 + county linear trends | 25,722 | -5.844 | 10 | 35 |
| M3 BYM2 + county random-walk trajectories | 25,724 | -5.853 | 44 | 583 |
| M4 BYM2 + county mean-reverting trajectories | 25,757 | -5.787 | 1 | 65 |

### Experiment C by origin: mean CRPS (points)

| origin | M0 | M1 | M2 | M3 | M4 |
|---|---|---|---|---|---|
| 3 | 0.55 | 0.55 | 0.55 | 0.56 | 0.54 |
| 6 | 0.36 | 0.35 | 0.36 | 0.36 | 0.35 |
| 9 | 0.15 | 0.15 | 0.14 | 0.15 | 0.15 |

### Experiment C by origin: coverage on 9 May 2023 predicted for the withheld counties, mean absolute error (points)

| origin | M0 | M1 | M2 | M3 | M4 |
|---|---|---|---|---|---|
| 3 | 1.86 | 1.87 | 1.88 | 1.96 | 1.84 |
| 6 | 1.13 | 1.11 | 1.18 | 1.20 | 1.10 |
| 9 | 0.68 | 0.68 | 0.66 | 0.68 | 0.67 |

### Experiment C by horizon: mean CRPS (points)

| hgroup | M0 | M1 | M2 | M3 | M4 |
|---|---|---|---|---|---|
| 1 interval ahead | 0.72 | 0.73 | 0.72 | 0.68 | 0.67 |
| 2-3 ahead | 0.44 | 0.44 | 0.44 | 0.44 | 0.44 |
| 4 or more ahead | 0.31 | 0.30 | 0.31 | 0.32 | 0.31 |

### Experiment D by forecast interval: mean CRPS (points)

| Interval forecast | Pooled recorded uptake in the interval before (%) | Pooled recorded uptake in this interval (%) | M0 | M1 | M2 | M3 | M4 |
|---|---|---|---|---|---|---|---|
| 22 Aug 2021 - 23 Sep 2021 | 12.56 | 9.70 | 2.36 | 2.00 | 2.03 | 1.94 | 1.87 |
| 24 Sep 2021 - 25 Oct 2021 | 9.70 | 5.25 | 3.51 | 3.38 | 3.15 | 3.25 | 3.22 |
| 26 Oct 2021 - 20 Nov 2021 | 5.25 | 5.26 | 0.71 | 0.70 | 0.71 | 0.70 | 0.68 |
| 21 Nov 2021 - 21 Dec 2021 | 5.26 | 5.14 | 0.72 | 0.72 | 0.72 | 0.72 | 0.71 |
| 22 Dec 2021 - 21 Jan 2022 | 5.14 | 5.37 | 0.65 | 0.64 | 0.65 | 0.65 | 0.65 |
| 22 Jan 2022 - 25 Feb 2022 | 5.37 | 2.69 | 1.12 | 1.08 | 1.16 | 1.19 | 1.16 |
| 26 Feb 2022 - 30 May 2022 | 2.69 | 1.34 | 0.54 | 0.55 | 0.51 | 0.59 | 0.53 |
| 31 May 2022 - 20 Nov 2022 | 1.34 | 0.97 | 0.23 | 0.23 | 0.24 | 0.26 | 0.23 |
| 21 Nov 2022 - 09 May 2023 | 0.97 | 0.46 | 0.23 | 0.22 | 0.28 | 0.27 | 0.23 |

### Experiment D by forecast interval: mean error, predicted minus recorded (points per 30 days)

| Interval forecast | Pooled recorded uptake in the interval before (%) | Pooled recorded uptake in this interval (%) | M0 | M1 | M2 | M3 | M4 |
|---|---|---|---|---|---|---|---|
| 22 Aug 2021 - 23 Sep 2021 | 12.56 | 9.70 | 2.82 | 1.83 | 1.91 | 1.85 | 1.65 |
| 24 Sep 2021 - 25 Oct 2021 | 9.70 | 5.25 | 4.91 | 4.68 | 4.45 | 4.56 | 4.53 |
| 26 Oct 2021 - 20 Nov 2021 | 5.25 | 5.26 | -0.46 | -0.30 | -0.30 | -0.34 | -0.25 |
| 21 Nov 2021 - 21 Dec 2021 | 5.26 | 5.14 | -0.23 | -0.15 | -0.11 | -0.08 | -0.02 |
| 22 Dec 2021 - 21 Jan 2022 | 5.14 | 5.37 | -0.04 | -0.05 | 0.00 | -0.03 | -0.07 |
| 22 Jan 2022 - 25 Feb 2022 | 5.37 | 2.69 | 1.56 | 1.51 | 1.61 | 1.65 | 1.63 |
| 26 Feb 2022 - 30 May 2022 | 2.69 | 1.34 | 0.68 | 0.73 | 0.65 | 0.80 | 0.70 |
| 31 May 2022 - 20 Nov 2022 | 1.34 | 0.97 | 0.06 | 0.08 | 0.08 | 0.11 | 0.06 |
| 21 Nov 2022 - 09 May 2023 | 0.97 | 0.46 | 0.23 | 0.22 | 0.31 | 0.30 | 0.22 |

### Differences between models on the same county-intervals (second model minus first, 95% bootstrap interval)

| Experiment | County-intervals | Comparison | Mean CRPS (points) | Mean log score | End coverage: mean abs. error (points) |
|---|---|---|---|---|---|
| A | all scored | M1 minus M0 | -0.121 (-0.177 to -0.071) | 0.148 (0.094 to 0.203) | -0.937 (-1.364 to -0.527) |
| A | all scored | M2 minus M1 | 0.001 (-0.002 to 0.005) | 0.031 (0.020 to 0.042) | -0.002 (-0.045 to 0.038) |
| A | all scored | M4 minus M1 | 0.062 (0.041 to 0.083) | -0.024 (-0.048 to 0.000) | 0.368 (0.194 to 0.533) |
| B | all scored | M1 minus M0 | -0.117 (-0.170 to -0.070) | 0.124 (0.069 to 0.179) | -0.962 (-1.432 to -0.501) |
| B | all scored | M4 minus M1 | 0.042 (0.027 to 0.056) | -0.011 (-0.034 to 0.013) | 0.209 (0.080 to 0.335) |
| C | all scored | M1 minus M0 | -0.001 (-0.007 to 0.005) | 0.011 (-0.003 to 0.025) | -0.007 (-0.040 to 0.025) |
| C | all scored | M3 minus M1 | 0.004 (-0.005 to 0.013) | 0.172 (0.100 to 0.250) | 0.061 (0.012 to 0.110) |
| C | all scored | M4 minus M1 | -0.007 (-0.014 to 0.000) | 0.135 (0.085 to 0.190) | -0.015 (-0.048 to 0.020) |
| C | all scored | M4 minus M3 | -0.011 (-0.017 to -0.006) | -0.037 (-0.064 to -0.012) | -0.076 (-0.104 to -0.049) |
| C | 1 interval ahead | M3 minus M1 | -0.048 (-0.066 to -0.030) | 0.067 (0.029 to 0.108) |  |
| C | 1 interval ahead | M4 minus M1 | -0.056 (-0.077 to -0.035) | 0.076 (0.038 to 0.115) |  |
| C | 1 interval ahead | M4 minus M3 | -0.008 (-0.017 to 0.000) | 0.008 (-0.003 to 0.019) |  |
| C | 2-3 ahead | M3 minus M1 | 0.005 (-0.006 to 0.015) | 0.177 (0.111 to 0.244) |  |
| C | 2-3 ahead | M4 minus M1 | -0.001 (-0.012 to 0.009) | 0.123 (0.079 to 0.168) |  |
| C | 2-3 ahead | M4 minus M3 | -0.006 (-0.012 to -0.001) | -0.054 (-0.079 to -0.030) |  |
| C | 4 or more ahead | M3 minus M1 | 0.021 (0.011 to 0.032) | 0.204 (0.104 to 0.314) |  |
| C | 4 or more ahead | M4 minus M1 | 0.006 (0.000 to 0.011) | 0.162 (0.095 to 0.239) |  |
| C | 4 or more ahead | M4 minus M3 | -0.016 (-0.023 to -0.009) | -0.042 (-0.078 to -0.007) |  |
| D | all scored | M1 minus M0 | -0.063 (-0.144 to -0.006) | 0.022 (0.006 to 0.039) |  |
| D | all scored | M4 minus M1 | -0.025 (-0.076 to 0.017) | 0.023 (0.002 to 0.050) |  |
| D | all scored | M4 minus M3 | -0.031 (-0.046 to -0.017) | 0.036 (0.016 to 0.067) |  |

### Hazard ratios per standard deviation, all uptake models

| Model | Share of adults aged 65+ | Median household income | Cases in previous 30 days |
|---|---|---|---|
| M0 | 0.87 (0.82 to 0.92) | 1.04 (0.98 to 1.10) | 1.09 (1.06 to 1.13) |
| M1 | 0.85 (0.81 to 0.89) | 1.02 (0.96 to 1.07) | 1.09 (1.06 to 1.12) |
| M2 | 0.85 (0.81 to 0.89) | 1.02 (0.96 to 1.07) | 1.09 (1.07 to 1.12) |
| M3 | 0.85 (0.81 to 0.89) | 1.01 (0.96 to 1.07) | 1.07 (1.04 to 1.10) |
| M4 | 0.83 (0.78 to 0.88) | 1.05 (0.98 to 1.13) | 1.06 (1.03 to 1.09) |

### Variance parameters of the fitted models (posterior median, 95% credible interval)

| Parameter (log-hazard scale) | M0 | M1 | M2 | M3 | M4 |
|---|---|---|---|---|---|
| County effect, standard deviation | 0.40 (0.36 to 0.44) | 0.37 (0.33 to 0.42) | 0.38 (0.34 to 0.43) | 0.39 (0.34 to 0.44) | 0.35 (0.28 to 0.42) |
| County effect, spatially structured share |  | 0.70 (0.49 to 0.87) | 0.69 (0.48 to 0.86) | 0.68 (0.46 to 0.85) | 0.93 (0.78 to 0.99) |
| Shared time effect, standard deviation | 0.80 (0.57 to 1.15) | 0.80 (0.56 to 1.15) | 0.80 (0.57 to 1.15) | 0.80 (0.57 to 1.15) | 0.79 (0.58 to 1.16) |
| County slope per year, standard deviation (M2) |  |  | 0.37 (0.33 to 0.42) |  |  |
| County-specific course, standard deviation (M3, M4) |  |  |  | 0.30 (0.28 to 0.33) | 0.43 (0.39 to 0.47) |
| County-specific course, mean-reversion rate per month (M4) |  |  |  |  | 0.12 (0.09 to 0.16) |
| County-interval deviation, standard deviation | 0.33 (0.32 to 0.34) | 0.33 (0.32 to 0.34) | 0.28 (0.27 to 0.29) | 0.19 (0.18 to 0.21) | 0.17 (0.15 to 0.19) |

### Predictor associations, selected model and baseline model

| Outcome | Predictor | Contrast | Measure | Estimate |
|---|---|---|---|---|
| Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023 | Share of adults aged 65+ | per 1 SD (6.2 points) | hazard ratio | 0.83 (0.78 to 0.88) |
| Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023 | Share of adults aged 65+ | per 5 points | hazard ratio | 0.86 (0.82 to 0.90) |
| Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023 | Median household income | per 1 SD (27% higher) | hazard ratio | 1.05 (0.98 to 1.13) |
| Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023 | Median household income | per 10% higher | hazard ratio | 1.02 (0.99 to 1.05) |
| Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023 | Cases in previous 30 days | per 1 SD (4.0-fold) | hazard ratio | 1.06 (1.03 to 1.09) |
| Uptake hazard among adults not yet vaccinated, 25 May 2021 - 9 May 2023 | Cases in previous 30 days | per doubling | hazard ratio | 1.03 (1.02 to 1.05) |
| Coverage reached by 24 May 2021 | Share of adults aged 65+ | per 1 SD | odds ratio | 1.03 (0.99 to 1.08) |
| Coverage reached by 24 May 2021 | Median household income | per 1 SD | odds ratio | 1.05 (1.01 to 1.10) |
| Coverage reached by 24 May 2021 | Cumulative cases before 14 Dec 2020 | per 1 SD | odds ratio | 1.07 (1.02 to 1.13) |

### Hazard ratios per standard deviation by period

| Predictor | 25 May 2021 to 23 Sep 2021 | 24 Sep 2021 to 25 Feb 2022 | 26 Feb 2022 to 09 May 2023 |
|---|---|---|---|
| Share of adults aged 65+ | 0.86 (0.80 to 0.92) | 0.83 (0.77 to 0.89) | 0.81 (0.76 to 0.87) |
| Median household income | 1.00 (0.93 to 1.08) | 1.04 (0.96 to 1.12) | 1.09 (1.01 to 1.17) |
| Cases in previous 30 days | 1.08 (1.04 to 1.13) | 1.04 (1.00 to 1.09) | 1.07 (1.00 to 1.14) |

### Baseline coverage model hyperparameters

| parameter | B0 | B1 |
|---|---|---|
| Phi for cid |  | 0.82 (0.59 to 0.95) |
| SD of cid | 0.34 (0.31 to 0.38) | 0.34 (0.30 to 0.39) |

### Largest recorded gains (kept counties)

| County | Adults 16+ | Coverage 24 May 2021 (%) | Coverage 9 May 2023 (%) | Change (points) | Relative uptake (95% CrI) |
|---|---|---|---|---|---|
| La Salle | 5,406 | 59.8 | 96.8 | 37.0 | 4.72 (4.29 to 5.21) |
| Bexar | 1,587,099 | 54.4 | 89.1 | 34.7 | 3.67 (3.65 to 3.70) |
| Kinney | 2,599 | 47.6 | 80.9 | 33.3 | 2.39 (2.21 to 2.59) |
| Harris | 3,660,544 | 55.6 | 87.0 | 31.4 | 3.07 (3.05 to 3.09) |
| Karnes | 12,207 | 49.3 | 79.5 | 30.3 | 2.23 (2.16 to 2.31) |
| Pecos | 11,836 | 55.2 | 84.8 | 29.6 | 2.47 (2.37 to 2.57) |
| Dallam | 5,189 | 48.4 | 77.5 | 29.1 | 1.84 (1.71 to 1.96) |
| Uvalde | 19,062 | 53.8 | 82.6 | 28.8 | 2.38 (2.30 to 2.46) |
| Caldwell | 36,809 | 43.7 | 72.5 | 28.8 | 1.60 (1.56 to 1.64) |
| Dallas | 2,021,919 | 55.3 | 84.0 | 28.7 | 2.54 (2.52 to 2.56) |

### Smallest recorded gains (kept counties)

| County | Adults 16+ | Coverage 24 May 2021 (%) | Coverage 9 May 2023 (%) | Change (points) | Relative uptake (95% CrI) |
|---|---|---|---|---|---|
| Jeff Davis | 1,754 | 62.2 | 71.2 | 9.0 | 0.73 (0.63 to 0.85) |
| Throckmorton | 1,216 | 44.2 | 55.0 | 10.9 | 0.43 (0.35 to 0.51) |
| King | 198 | 18.7 | 29.8 | 11.1 | 0.44 (0.31 to 0.62) |
| Lipscomb | 2,317 | 34.2 | 45.6 | 11.4 | 0.44 (0.38 to 0.50) |
| Cottle | 1,123 | 39.4 | 51.2 | 11.8 | 0.48 (0.40 to 0.58) |
| Newton | 10,029 | 24.3 | 36.4 | 12.1 | 0.30 (0.27 to 0.32) |
| Motley | 873 | 40.9 | 53.0 | 12.1 | 0.50 (0.40 to 0.61) |
| Borden | 493 | 31.6 | 43.8 | 12.2 | 0.40 (0.30 to 0.52) |
| Donley | 2,771 | 36.8 | 49.4 | 12.6 | 0.46 (0.41 to 0.52) |
| Gaines | 15,021 | 21.2 | 34.1 | 12.9 | 0.36 (0.33 to 0.38) |

### Lowest recorded coverage on 9 May 2023 (kept counties)

| County | Adults 16+ | Coverage 24 May 2021 (%) | Coverage 9 May 2023 (%) | Change (points) | Relative uptake (95% CrI) |
|---|---|---|---|---|---|
| King | 198 | 18.7 | 29.8 | 11.1 | 0.44 (0.31 to 0.62) |
| Gaines | 15,021 | 21.2 | 34.1 | 12.9 | 0.36 (0.33 to 0.38) |
| Newton | 10,029 | 24.3 | 36.4 | 12.1 | 0.30 (0.27 to 0.32) |
| Borden | 493 | 31.6 | 43.8 | 12.2 | 0.40 (0.30 to 0.52) |
| Mitchell | 7,476 | 29.3 | 45.1 | 15.8 | 0.50 (0.46 to 0.54) |
| Lipscomb | 2,317 | 34.2 | 45.6 | 11.4 | 0.44 (0.38 to 0.50) |
| Live Oak | 9,503 | 32.2 | 47.0 | 14.8 | 0.49 (0.45 to 0.52) |
| Delta | 4,270 | 31.2 | 47.0 | 15.8 | 0.55 (0.50 to 0.61) |
| Roberts | 618 | 30.6 | 47.1 | 16.5 | 0.59 (0.47 to 0.72) |
| Van Zandt | 48,977 | 30.3 | 48.0 | 17.7 | 0.62 (0.61 to 0.64) |

### Ten most populous kept counties

| County | Adults 16+ | Coverage 24 May 2021 (%) | Coverage 9 May 2023 (%) | Change (points) | Relative uptake (95% CrI) |
|---|---|---|---|---|---|
| Harris | 3,660,544 | 55.6 | 87.0 | 31.4 | 3.07 (3.05 to 3.09) |
| Dallas | 2,021,919 | 55.3 | 84.0 | 28.7 | 2.54 (2.52 to 2.56) |
| Tarrant | 1,655,595 | 50.6 | 75.7 | 25.1 | 1.67 (1.66 to 1.69) |
| Bexar | 1,587,099 | 54.4 | 89.1 | 34.7 | 3.67 (3.65 to 3.70) |
| Travis | 1,067,760 | 64.0 | 89.1 | 25.1 | 3.08 (3.06 to 3.11) |
| Collin | 866,220 | 59.7 | 83.4 | 23.8 | 2.23 (2.21 to 2.25) |
| Denton | 742,179 | 54.7 | 76.8 | 22.1 | 1.61 (1.60 to 1.63) |
| Fort Bend | 655,321 | 65.1 | 89.7 | 24.6 | 3.09 (3.06 to 3.11) |
| Williamson | 502,765 | 58.7 | 83.4 | 24.7 | 2.33 (2.31 to 2.35) |
| Montgomery | 501,882 | 47.5 | 74.6 | 27.1 | 1.79 (1.78 to 1.81) |

### Counties left out of the models (recorded count exceeds population estimate)

| County | Adults 16+ | Recorded coverage 24 May 2021 (%) | Recorded coverage 9 May 2023 (%) |
|---|---|---|---|
| Maverick | 42,158 | 73.8 | 233.8 |
| Reeves | 10,182 | 50.2 | 229.2 |
| Webb | 194,896 | 80.1 | 188.9 |
| Brooks | 5,405 | 58.0 | 184.0 |
| Dimmit | 6,387 | 73.6 | 148.5 |
| Presidio | 4,754 | 104.3 | 148.0 |
| Hidalgo | 644,648 | 67.7 | 140.3 |
| Loving | 32 | 100.0 | 137.5 |
| Hudspeth | 2,692 | 93.1 | 136.3 |
| Starr | 47,947 | 75.1 | 130.1 |
| Cameron | 317,378 | 71.0 | 126.4 |
| Frio | 13,780 | 47.1 | 123.9 |
| Val Verde | 35,905 | 60.0 | 114.2 |
| El Paso | 673,152 | 67.3 | 113.2 |
| Willacy | 16,100 | 58.9 | 104.2 |
| Duval | 7,850 | 65.9 | 101.4 |

### Modelled versus recorded change in coverage (kept counties)

| Counties | Median absolute difference (points) | Largest absolute difference (points) | Recorded change inside modelled 95% interval (%) |
|---|---|---|---|
| 238 | 0.027 | 3.70 | 99.58 |

### Recorded versus modelled uptake by county size

| County size | County-intervals | Counties | Median absolute difference (points per 30 days) | 95th percentile of the difference (points) | Median difference as % of the recorded rate | Recorded rate inside the modelled 95% interval (%) | Median width of the 95% interval (points) | Correlation, recorded and modelled | Correlation, recorded and modelled without the county-interval deviation |
|---|---|---|---|---|---|---|---|---|---|
| Fewer than 5,000 adults | 720 | 60 | 0.159 | 1.148 | 7.8 | 87.5 | 1.43 | 0.9846 | 0.9515 |
| 5,000 to 50,000 | 1,523 | 127 | 0.018 | 0.157 | 0.8 | 98.4 | 0.67 | 0.9996 | 0.9850 |
| More than 50,000 | 612 | 51 | 0.002 | 0.011 | 0.1 | 100.0 | 0.26 | 1.0000 | 0.9917 |

### Smoothing summary

| item | value |
|---|---|
| Moran's I, county effects of the non-spatial model | 0.475 |
| p-value | 2.3e-33 |
| counties significantly different from neighbours (95%) | 136.000 |
| of which lower | 68.000 |
| of which higher | 68.000 |

### Counties most different from the mean of their neighbours (residual county effect ratio)

| County | Adults 16+ | Ratio to neighbours (95% CrI) | Coverage 9 May 2023 (%) |
|---|---|---|---|
| Live Oak | 9,503 | 0.33 (0.29 to 0.38) | 47.0 |
| Gaines | 15,021 | 0.36 (0.31 to 0.41) | 34.1 |
| Waller | 46,936 | 0.40 (0.35 to 0.45) | 54.9 |
| Newton | 10,029 | 0.48 (0.39 to 0.57) | 36.4 |
| Kimble | 3,674 | 0.49 (0.41 to 0.57) | 56.5 |
| King | 198 | 0.49 (0.34 to 0.70) | 29.8 |
| Erath | 35,342 | 0.58 (0.50 to 0.67) | 49.5 |
| Ward | 8,341 | 0.59 (0.51 to 0.68) | 60.4 |
| Grimes | 24,304 | 1.81 (1.59 to 2.06) | 72.0 |
| Zavala | 6,969 | 1.81 (1.51 to 2.14) | 92.0 |
| Jim Wells | 29,653 | 1.82 (1.60 to 2.09) | 84.6 |
| Stonewall | 1,002 | 1.88 (1.51 to 2.34) | 64.1 |
| Bexar | 1,587,099 | 1.91 (1.64 to 2.21) | 89.1 |
| Harris | 3,660,544 | 2.01 (1.77 to 2.26) | 87.0 |
| Glasscock | 883 | 2.20 (1.75 to 2.73) | 78.4 |
| La Salle | 5,406 | 2.83 (2.36 to 3.41) | 96.8 |

### Sensitivity analysis

| Variant | Description | Counties | County-intervals | Age 65+ share | Income | Recent cases | SD county | Spatial share (phi) | SD trajectory | SD county-interval |
|---|---|---|---|---|---|---|---|---|---|---|
| S0 | Main analysis | 238 | 2,855 | 0.83 (0.78 to 0.88) | 1.05 (0.98 to 1.13) | 1.06 (1.03 to 1.09) | 0.35 | 0.94 | 0.43 | 0.17 |
| S1 | Adds the interval 23 April - 24 May 2021 (before county re-assignments had settled) | 238 | 3,092 | 0.81 (0.76 to 0.86) | 1.04 (0.97 to 1.11) | 1.05 (1.02 to 1.09) | 0.35 | 0.92 | 0.45 | 0.22 |
| S2 | Keeps every near-monthly edition after May 2022 (18 intervals instead of 12) | 238 | 4,279 | 0.84 (0.79 to 0.89) | 1.05 (0.98 to 1.13) | 1.03 (1.00 to 1.06) | 0.40 | 0.90 | 0.47 | 0.20 |
| S3 | Denominator: the 2019 Census estimate of residents aged 16+ printed in the DSHS workbook | 242 | 2,903 | 0.77 (0.72 to 0.82) | 1.10 (1.02 to 1.18) | 1.06 (1.03 to 1.09) | 0.37 | 0.96 | 0.46 | 0.17 |
| S4 | Keeps the 16 flagged counties until their recorded coverage reaches 95% | 252 | 2,937 | 0.78 (0.73 to 0.84) | 1.01 (0.94 to 1.09) | 1.06 (1.03 to 1.09) | 0.43 | 0.96 | 0.48 | 0.16 |
| S5 | Case rate from confirmed cases only (probable cases left out) | 238 | 2,855 | 0.83 (0.78 to 0.88) | 1.05 (0.98 to 1.13) | 1.05 (1.02 to 1.08) | 0.35 | 0.93 | 0.43 | 0.17 |
| S6 | Age composition from the ACS 2019-2023 instead of the population estimates | 238 | 2,855 | 0.82 (0.77 to 0.88) | 1.05 (0.98 to 1.13) | 1.06 (1.03 to 1.09) | 0.36 | 0.94 | 0.43 | 0.17 |
| S7 | Drops the county-intervals where a fall in the recorded count was set to zero | 238 | 2,815 | 0.84 (0.80 to 0.89) | 1.05 (0.98 to 1.12) | 1.06 (1.03 to 1.09) | 0.35 | 0.92 | 0.37 | 0.18 |
| S8 | Rate per adult resident instead of per adult not yet vaccinated | 238 | 2,855 | 0.88 (0.85 to 0.92) | 1.03 (0.98 to 1.07) | 1.07 (1.04 to 1.10) | 0.19 | 0.92 | 0.34 | 0.17 |
| S9 | Also leaves out the 23 kept counties that border a flagged county | 215 | 2,580 | 0.84 (0.79 to 0.89) | 1.08 (1.00 to 1.16) | 1.05 (1.02 to 1.08) | 0.32 | 0.94 | 0.42 | 0.17 |
| S10 | Ends on 30 May 2022 (drops the two half-year intervals) | 238 | 2,380 | 0.84 (0.80 to 0.88) | 1.00 (0.95 to 1.05) | 1.08 (1.05 to 1.11) | 0.34 | 0.78 | 0.26 | 0.14 |
| S11 | Leaves out counties with fewer than 1,000 adults | 228 | 2,735 | 0.83 (0.77 to 0.88) | 1.05 (0.97 to 1.12) | 1.06 (1.03 to 1.10) | 0.35 | 0.96 | 0.43 | 0.17 |
| S12 | Same data, R-INLA classic mode with simplified Laplace approximation | 238 | 2,855 | 0.83 (0.78 to 0.88) | 1.05 (0.98 to 1.13) | 1.06 (1.03 to 1.09) | 0.35 | 0.94 | 0.43 | 0.17 |

### Baseline coverage and later modelled uptake

| quantity | median | lo | hi |
|---|---|---|---|
| correlation of baseline coverage with modelled relative uptake (interval: uncertainty in modelled county rates only) | 0.73 | 0.72 | 0.74 |
| hazard ratio per 10 points higher baseline coverage (interval: uncertainty in modelled county rates only) | 1.49 | 1.47 | 1.50 |
| hazard ratio per 10 points higher baseline coverage, least squares across counties (95% confidence interval from scatter between counties) | 1.49 | 1.42 | 1.56 |

### County relative uptake under the other models, compared with the selected model

| Model | Compared with | Counties | Correlation (log scale) | Median absolute difference (%) | 95th percentile (%) | Largest (%) | County with the largest difference | Its adults 16+ |
|---|---|---|---|---|---|---|---|---|
| M0 | M4 | 238 | 0.9993 | 0.46 | 4.26 | 11.17 | Borden | 493 |
| M1 | M4 | 238 | 0.9993 | 0.46 | 4.07 | 10.66 | King | 198 |
| M2 | M4 | 238 | 0.9998 | 0.17 | 1.69 | 10.07 | King | 198 |
| M3 | M4 | 238 | 0.9998 | 0.19 | 2.05 | 8.81 | King | 198 |
