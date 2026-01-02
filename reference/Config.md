# Config Class

Represents the complete configuration for the pipeline.

## Usage

``` r
Config(
  job_id = class_missing,
  task_id = class_missing,
  min_reference_date = class_missing,
  max_reference_date = class_missing,
  report_date = class_missing,
  production_date = class_missing,
  disease = class_missing,
  low_case_count_thresholds = class_missing,
  geo_value = class_missing,
  geo_type = class_missing,
  seed = class_missing,
  horizon = class_missing,
  model = class_missing,
  config_version = class_missing,
  quantile_width = class_missing,
  data = class_missing,
  priors = class_missing,
  parameters = class_missing,
  sampler_opts = class_missing,
  exclusions = class_missing,
  output_container = class_missing
)
```

## Arguments

- job_id:

  A string specifying the job.

- task_id:

  A string specifying the task.

- min_reference_date:

  A string representing the minimum reference date. Formatted as
  "YYYY-MM-DD".

- max_reference_date:

  A string representing the maximum reference date. Formatted as
  "YYYY-MM-DD".

- report_date:

  A string representing the report date. Formatted as "YYYY-MM-DD".

- production_date:

  A string representing the production date. Formatted as "YYYY-MM-DD".

- disease:

  A string specifying the disease being modeled. One of `"COVID-19"` or
  `"Influenza"` or `"RSV"`.

- low_case_count_thresholds:

  A named list of thresholds to use for determining n_low_case_count in
  diagnostic file Example: list(`COVID-19` = 10,
  ``` Influenza`` = 10,  ```RSV\` = 5)

- geo_value:

  An uppercase, two-character string specifying the geographic value,
  usually a state or `"US"` for national data.

- geo_type:

  A string specifying the geographic type, usually "state".

- seed:

  An integer for setting the random seed.

- horizon:

  An integer specifying the forecasting horizon.

- model:

  A string specifying the model to be used.

- config_version:

  A numeric value specifying the configuration version.

- quantile_width:

  A vector of numeric values representing the desired quantiles. Passed
  to
  [`tidybayes::median_qi()`](https://mjskay.github.io/tidybayes/reference/reexports.html).

- data:

  An instance of `Data` class containing data configurations.

- priors:

  A list of lists. The first level should contain the key `rt` with
  elements `mean` and `sd` and the key `gp` with element `alpha_sd`.

- parameters:

  An instance of `Parameters` class containing parameter configurations.

- sampler_opts:

  A list. The Stan sampler options to be passed through EpiNow2. It has
  required keys: `cores`, `chains`, `iter_warmup`, `iter_sampling`,
  `max_treedepth`, and `adapt_delta`.

- exclusions:

  An instance of `Exclusions` class containing exclusion criteria.

- output_container:

  An optional string specifying the output blob storage container.

## See also

Other config:
[`Data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Data.md),
[`Interval`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Interval.md),
[`Parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/Parameters.md),
[`read_json_into_config()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_json_into_config.md)
