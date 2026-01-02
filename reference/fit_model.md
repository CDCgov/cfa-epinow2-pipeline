# Fit an `EpiNow2` model

Fit an `EpiNow2` model

## Usage

``` r
fit_model(data, parameters, seed, horizon, priors, sampler_opts)
```

## Arguments

- data, :

  in the format returned by
  [`read_data()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_data.md)

- parameters:

  As returned from
  [`read_disease_parameters()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/read_disease_parameters.md)

- seed:

  The random seed, used for both initialization by `EpiNow2` in R and
  sampling in Stan

- horizon:

  The number of days, as an integer, to forecast

- priors:

  A list of lists. The first level should contain the key `rt` with
  elements `mean` and `sd` and the key `gp` with element `alpha_sd`.

- sampler_opts:

  A list. The Stan sampler options to be passed through EpiNow2. It has
  required keys: `cores`, `chains`, `iter_warmup`, `iter_sampling`,
  `max_treedepth`, and `adapt_delta`.

## Value

A fitted model object of class `epinow` or, if model fitting fails, an
NA is returned with a warning

## See also

Other pipeline:
[`format_stan_opts()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/format_stan_opts.md),
[`orchestrate_pipeline()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/pipeline.md)
