test_that("Minimal model fit all params runs", {
  # Parameters
  parameters <- list(
    generation_interval = gostic_gt_pmf,
    delay_interval = c(0.2, 0.8),
    right_truncation = c(0.7, 0.3)
  )
  # Data -- 5 points only
  data_path <- test_path("data", "test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  data <- DBI::dbGetQuery(con, "
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
    iter_warmup = 100,
    iter_samples = 100
  )

  fit <- fit_model(
    data = data,
    parameters = parameters,
    seed = 12345,
    horizon = 0,
    priors = priors,
    sampler = sampler_opts
  )

  expect_s3_class(fit, "epinow")
})

test_that("Minimal model fit with no right trunc or delay runs", {
  # Parameters
  parameters <- list(
    generation_interval = gostic_gt_pmf,
    delay_interval = NA,
    right_truncation = NA
  )
  # Data -- 5 points only
  data_path <- test_path("data", "test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  data <- DBI::dbGetQuery(con, "
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
    iter_warmup = 100,
    iter_samples = 100
  )

  fit <- fit_model(
    data = data,
    parameters = parameters,
    seed = 12345,
    horizon = 0,
    priors = priors,
    sampler = sampler_opts
  )

  expect_s3_class(fit, "epinow")
})

test_that("Bad params w/ failing fit issues warning and returns NA", {
  # Parameters
  parameters <- list(
    generation_interval = gostic_gt_pmf,
    delay_interval = NA,
    right_truncation = NA
  )
  # Data -- 5 points only
  data_path <- test_path("data", "test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  data <- DBI::dbGetQuery(con, "
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
    iter_warmup = -100,
    iter_samples = 100
  )

  expect_warning(
    fit <- fit_model(
      data = data,
      parameters = parameters,
      seed = 12345,
      horizon = 0,
      priors = priors,
      sampler = sampler_opts
    ),
    class = "failing_fit"
  )

  expect_true(is.na(fit))
})

test_that("Right truncation longer than data throws error", {
  data <- data.frame(x = c(1, 2))
  right_truncation_pmf <- c(0.1, 0.2, 0.7)

  expect_error(
    format_right_truncation(
      right_truncation_pmf,
      data
    ),
    class = "right_trunc_too_long"
  )
})

test_that("Missing GI throws error", {
  expect_error(format_generation_interval(NA),
    class = "Missing_GI"
  )
})
