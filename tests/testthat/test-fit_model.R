test_that("Minimal model fit all params runs", {
  # fit object created in setup.R
  expect_s3_class(fit, "epinow")
})

test_that("Minimal model fit with no right trunc or delay runs", {
  # Data loaded in from setup.R
  expect_s3_class(fit, "epinow")
})

test_that("Bad params w/ failing fit issues warning and returns NA", {
  # Parameterization is same as above except Stan argument `iter_warmup` is
  # negative, which is an illegal parameterizaion. As a result, EpiNow2 starts
  # the Stan sampler but it terminates unexpectedly with an error, which is the
  # desired testing condition.

  # Data loaded in from setup.R
  # Parameters
  parameters <- list(
    generation_interval = sir_gt_pmf,
    delay_interval = NA,
    right_truncation = NA
  )
  # Sampler
  sampler_opts <- list(
    cores = 1,
    chains = 1,
    adapt_delta = 0.8,
    max_treedepth = 10,
    iter_warmup = -25,
    iter_sampling = 25
  )

  expect_error(
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
})

test_that("Right truncation longer than data throws error", {
  data <- data.frame(x = c(1, 2))
  right_truncation_pmf <- c(0.1, 0.2, 0.7)

  expect_snapshot_warning(
    format_right_truncation(
      right_truncation_pmf,
      data
    )
  )
})

test_that("Model fit returns reasonable R0 estimate", {
  # Data loaded in from setup.R
  # Parameters
  diagnostic_df <- extract_diagnostics(
    gostic_fit,
    gostic_data,
    "test",
    "test",
    "test",
    "test",
    "test"
  )

  # Test 1: Test that mean accept stat is above 0.85
  ma_stat <- diagnostic_df |>
    dplyr::filter(diagnostic == "mean_accept_stat") |>
    dplyr::pull(value)

  testthat::expect_true(ma_stat > 0.85)

  # Test 2: Test that Rt estimate range covers true_rt (~2.0)
  estimate <- gostic_fit$summary |>
    dplyr::filter(measure == "Effective reproduction no.") |>
    dplyr::pull(estimate)
  actual_rt <- gsub("[()--]", " ", estimate)

  # Split the string into numbers
  rt_estimates <- unlist(strsplit(actual_rt, "\\s+"))
  actual_rt_lower <- rt_estimates[length(rt_estimates) - 1]
  actual_rt_upper <- rt_estimates[length(rt_estimates)]

  expected_rt <- gostic_data |>
    dplyr::slice_max(reference_date, n = 1) |>
    dplyr::pull(true_rt)

  testthat::expect_true(
    actual_rt_lower < expected_rt & actual_rt_upper > expected_rt
  )
})


test_that("Missing GI throws error", {
  expect_error(format_generation_interval(NA), class = "Missing_GI")
})

test_that("Missing keys throws error", {
  random_seed <- 12345
  expect_snapshot(format_stan_opts(list(), random_seed), error = TRUE)
})
