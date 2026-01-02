# Extract diagnostic metrics from model fit and data

This function extracts various diagnostic metrics from a fitted
`EpiNow2` model and provided data. It checks for low case counts and
computes diagnostics from the fitted model, including the mean
acceptance statistic, divergent transitions, maximum tree depth, and
Rhat values. Additionally, a combined flag is computed indicating if any
diagnostics are outside an acceptable range. The results are returned as
a data frame.

## Usage

``` r
extract_diagnostics(
  fit,
  data,
  low_count_threshold,
  job_id,
  task_id,
  disease,
  geo_value,
  model
)
```

## Arguments

- fit:

  The model fit object from `EpiNow2`

- data:

  A data frame containing the input data used in the model fit.

- low_count_threshold:

  an integer that determines cutoff for determining low_case_count flag.
  If the jurisdiction has less than X DDI counts for the respective
  pathogen, it will be considered as having too few cases and later on
  in post-processing the Rt estimate and growth category will be edited
  to NA and "Not Estimated", respectively, in release

- job_id:

  A string specifying the job.

- task_id:

  A string specifying the task.

- disease:

  A string specifying the disease being modeled. One of `"COVID-19"` or
  `"Influenza"` or `"RSV"`.

- geo_value:

  An uppercase, two-character string specifying the geographic value,
  usually a state or `"US"` for national data.

- model:

  A string specifying the model to be used.

## Value

A `data.frame` containing the extracted diagnostic metrics. The data
frame includes the following columns:

- `diagnostic`: The name of the diagnostic metric.

- `value`: The value of the diagnostic metric.

- `job_id`: The unique identifier for the job.

- `task_id`: The unique identifier for the task.

- `disease,geo_value,model`: Metadata for downstream processing.

## Details

The following diagnostics are calculated:

- `mean_accept_stat`: The average acceptance statistic across all
  chains.

- `p_divergent`: The *proportion* of divergent transitions across all
  samples.

- `n_divergent`: The *number* of divergent transitions across all
  samples.

- `p_max_treedepth`: The proportion of samples that hit the maximum tree
  depth.

- `p_high_rhat`: The *proportion* of parameters with Rhat values greater
  than 1.05, indicating potential convergence issues.

- `n_high_rhat`: The *number* of parameters with Rhat values greater
  than 1.05, indicating potential convergence issues.

- `low_case_count_flag`: A flag indicating if there are low case counts
  in the data. See
  [`low_case_count_diagnostic()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/low_case_count_diagnostic.md)
  for more information on this diagnostic.

- `epinow2_diagnostic_flag`: A combined flag that indicates if any
  diagnostic metrics are outside an accepted range, as determined by the
  thresholds: (1) mean_accept_stat \< 0.1, (2) p_divergent \>
  0.0075, (3) p_max_treedepth \> 0.05, and (4) p_high_rhat \> 0.0075.

## See also

Other diagnostics:
[`low_case_count_diagnostic()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/low_case_count_diagnostic.md),
[`low_case_count_threshold()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/low_case_count_threshold.md)
