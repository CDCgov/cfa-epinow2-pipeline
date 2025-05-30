test_that("Fitted model extracts diagnostics (rstan)", {
  # Expected diagnostics
  expected <- data.frame(
    diagnostic = c(
      "mean_accept_stat",
      "p_divergent",
      "n_divergent",
      "p_max_treedepth",
      "p_high_rhat",
      "n_high_rhat",
      "diagnostic_flag",
      "low_case_count_flag"
    ),
    value = c(
      0.94240233,
      0.00000000,
      0.00000000,
      0.00000000,
      0.00000000,
      0.00000000,
      0.00000000,
      0.00000000
    ),
    job_id = rep("test", 8),
    task_id = rep("test", 8),
    disease = rep("test", 8),
    geo_value = rep("test", 8),
    model = rep("test", 8),
    stringsAsFactors = FALSE
  )
  actual <- extract_diagnostics(
    fit_rstan,
    data,
    "test",
    "test",
    "test",
    "test",
    "test",
    backend = "rstan"
  )

  testthat::expect_equal(
    actual,
    expected
  )
})

test_that("Fitted model extracts diagnostics (cmdstanr)", {
  # Expected diagnostics
  expected <- data.frame(
    diagnostic = c(
      "mean_accept_stat",
      "p_divergent",
      "n_divergent",
      "p_max_treedepth",
      "p_high_rhat",
      "n_high_rhat",
      "diagnostic_flag",
      "low_case_count_flag"
    ),
    value = c(
      0.9147865,
      0.0000000,
      0.0000000,
      0.0000000,
      0.1960784,
      20.000000,
      1.0000000,
      0.0000000
    ),
    job_id = rep("test", 8),
    task_id = rep("test", 8),
    disease = rep("test", 8),
    geo_value = rep("test", 8),
    model = rep("test", 8),
    stringsAsFactors = FALSE
  )
  actual <- extract_diagnostics(
    fit_cmdstanr,
    data,
    "test",
    "test",
    "test",
    "test",
    "test",
    backend = "cmdstanr"
  )

  # Assert
  testthat::expect_equal(
    actual,
    expected,
    tolerance = 1e-5
  )
})

test_that("Mean accept state approximately equal between cmdstanr and rstan", {
  # Sampler
  sampler_opts <- list(
    cores = 1,
    chains = 2,
    adapt_delta = 0.90,
    max_treedepth = 10,
    iter_warmup = 500,
    iter_sampling = 200
  )
  # fit cmdstanr
  fit_cmdstanr <- fit_model(
    data = data,
    parameters = parameters,
    seed = 12345,
    horizon = 0,
    priors = priors,
    sampler = c(backend = "cmdstanr", sampler_opts)
  )
  # fit rstan
  fit_rstan <- fit_model(
    data = data,
    parameters = parameters,
    seed = 12345,
    horizon = 0,
    priors = priors,
    sampler = c(backend = "rstan", sampler_opts)
  )
  cmdstanr_diagnostics <- extract_diagnostics(
    fit_cmdstanr,
    data,
    "test",
    "test",
    "test",
    "test",
    "test",
    backend = "cmdstanr"
  )
  rstan_diagnostics <- extract_diagnostics(
    fit_rstan,
    data,
    "test",
    "test",
    "test",
    "test",
    "test",
    backend = "rstan"
  )

  rstan_ma_stat <- rstan_diagnostics |>
    dplyr::filter(diagnostic == "mean_accept_stat") |>
    dplyr::pull(value)

  cmdstanr_ma_stat <- cmdstanr_diagnostics |>
    dplyr::filter(diagnostic == "mean_accept_stat") |>
    dplyr::pull(value)

  # Assert
  testthat::expect_true(
    rstan_ma_stat > 0.9 && cmdstanr_ma_stat > 0.9
  )
})

test_that("Cases below threshold returns TRUE", {
  # Arrange
  true_df <- data.frame(
    reference_date = seq.Date(
      from = as.Date("2023-01-01"),
      by = "day",
      length.out = 14
    ),
    confirm = c(9, rep(0, 12), 9)
  )

  # Act
  diagnostic <- low_case_count_diagnostic(true_df)

  # Assert
  expect_true(diagnostic)
})

test_that("Cases above threshold returns FALSE", {
  # Arrange
  false_df <- data.frame(
    reference_date = seq.Date(
      from = as.Date("2023-01-01"),
      by = "day",
      length.out = 14
    ),
    confirm = rep(10, 14)
  )

  # Act
  diagnostic <- low_case_count_diagnostic(false_df)

  # Assert
  expect_false(diagnostic)
})


test_that("Only the last two weeks are evaluated", {
  # Arrange
  # 3 weeks, first week would pass but last week does not
  df <- data.frame(
    reference_date = seq.Date(
      from = as.Date("2023-01-01"),
      by = "day",
      length.out = 21
    ),
    # Week 1: 700, Week 2: 700, Week 3: 0
    confirm = c(rep(100, 14), rep(0, 7))
  )

  # Act
  diagnostic <- low_case_count_diagnostic(df)

  # Assert
  expect_true(diagnostic)
})

test_that("Old approach's negative is now positive", {
  # Arrange
  df <- data.frame(
    reference_date = seq.Date(
      from = as.Date("2023-01-01"),
      by = "day",
      length.out = 14
    ),
    # Week 1: 21, Week 2: 0
    confirm = c(rep(3, 7), rep(0, 7))
  )

  # Act
  diagnostic <- low_case_count_diagnostic(df)

  # Assert
  expect_true(diagnostic)
})

test_that("NAs are evalated as 0", {
  # Arrange
  df <- data.frame(
    reference_date = seq.Date(
      from = as.Date("2023-01-01"),
      by = "day",
      length.out = 14
    ),
    # Week 1: 6 (not NA!), Week 2: 700
    confirm = c(NA_real_, rep(1, 6), rep(100, 7))
  )

  # Act
  diagnostic <- low_case_count_diagnostic(df)

  # Assert
  expect_true(diagnostic)
})
