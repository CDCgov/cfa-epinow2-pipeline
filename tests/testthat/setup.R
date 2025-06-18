# Save model fit parameters into global testing environment for reuse

parameters <- list(
  generation_interval = sir_gt_pmf,
  delay_interval = c(0.2, 0.8),
  right_truncation = c(0.7, 0.3)
)
# Data -- 5 points only
data_path <- test_path("data", "test_data.parquet")
con <- DBI::dbConnect(duckdb::duckdb())
data <- DBI::dbGetQuery(
  con,
  "
                       SELECT
                         report_date,
                         reference_date,
                         disease,
                         geo_value AS state_abb,
                         value AS confirm
                       FROM read_parquet(?)
                       ORDER BY reference_date
                       LIMIT 5
                        ",
  params = list(data_path)
)
DBI::dbDisconnect(con)
# Priors
priors <- list(
  rt = list(
    mean = 1,
    sd = 0.2
  ),
  gp = list(
    alpha_sd = 0.05
  )
)
# Sampler
sampler_opts <- list(
  cores = 1,
  chains = 1,
  adapt_delta = 0.8,
  max_treedepth = 10,
  iter_warmup = 25,
  iter_sampling = 25
)

fit_rstan <- fit_model(
  data = data,
  parameters = parameters,
  seed = 12345,
  horizon = 7,
  priors = priors,
  sampler = c(backend = "cmdstanr", sampler_opts)
)

fit_cmdstanr <- fit_model(
  data = data,
  parameters = parameters,
  seed = 12345,
  horizon = 7,
  priors = priors,
  sampler = c(backend = "cmdstanr", sampler_opts)
)
