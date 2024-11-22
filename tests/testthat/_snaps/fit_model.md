# Right truncation longer than data throws error

    Removing right-truncation PMF elements after 2
    Right truncation PMF longer than the data
    PMF length: 3
    Data length: 2
    PMF can only be up to the length of the data

# Missing keys throws error

    Code
      format_stan_opts(list(), random_seed)
    Condition
      Error in `format_stan_opts()`:
      ! Missing expected keys/values in "sampler_opts"
      Missing keys: "cores", "chains", "iter_warmup", "iter_sampling", "adapt_delta", and "max_treedepth"
      Missing values:

