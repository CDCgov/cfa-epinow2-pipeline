# Process posterior samples from a Stan fit object (raw draws).

Extracts raw posterior samples from a Stan fit object and post-processes
them, including merging with a fact table and standardizing the
parameter names. If calling `[process_quantiles()]` the 50% and 95%
intervals are returned in `tidybayes` format.

## Usage

``` r
process_samples(fit, geo_value, model, disease)

process_quantiles(fit, geo_value, model, disease, quantile_width)
```

## Arguments

- fit:

  An `EpiNow2` fit object with posterior estimates.

- geo_value:

  An uppercase, two-character string specifying the geographic value,
  usually a state or `"US"` for national data.

- model:

  A string specifying the model to be used.

- disease:

  A string specifying the disease being modeled. One of `"COVID-19"` or
  `"Influenza"` or `"RSV"`.

- quantile_width:

  A vector of numeric values representing the desired quantiles. Passed
  to
  [`tidybayes::median_qi()`](https://mjskay.github.io/tidybayes/reference/reexports.html).

## Value

A data.table of posterior draws or quantiles, merged and processed.

## See also

Other write_output:
[`write_model_outputs()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/write_model_outputs.md),
[`write_output_dir_structure()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/write_output_dir_structure.md)
