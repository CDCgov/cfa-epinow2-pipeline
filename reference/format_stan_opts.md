# Format Stan options for input to EpiNow2

Format configuration `sampler_opts` for input to `EpiNow2` via a call to
[`EpiNow2::stan_opts()`](https://epiforecasts.io/EpiNow2/reference/stan_opts.html).

## Usage

``` r
format_stan_opts(sampler_opts, seed)
```

## Arguments

- sampler_opts:

  A list. The Stan sampler options to be passed through EpiNow2. It has
  required keys: `cores`, `chains`, `iter_warmup`, `iter_sampling`,
  `max_treedepth`, and `adapt_delta`.

- seed:

  A stochastic seed passed here to the Stan sampler and as the R PRNG
  seed for `EpiNow2` initialization

## Value

A `stan_opts` object of arguments

## See also

Other pipeline:
[`fit_model()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/fit_model.md),
[`orchestrate_pipeline()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/pipeline.md)
