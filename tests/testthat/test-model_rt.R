test_that("Model fit returns reasonable Rt, p_divergent values", {
  # Data loaded in from setup.R
  # Parameters
  parameters <- list(
    generation_interval = sir_gt_pmf,
    delay_interval = NA,
    right_truncation = NA
  )

  # incidence - number of cases with no delays
  test_data <- gostic_toy_rt %>%
    dplyr::mutate(reference_date = as.Date("2023-01-01") + time) %>%
    dplyr::filter(reference_date < as.Date("2023-02-01")) %>%
    dplyr::rename(confirm = incidence)

  fit <- fit_model(
    data = test_data,
    parameters = parameters,
    seed = 12345,
    horizon = 0,
    priors = priors,
    sampler = sampler_opts
  )

  diagnostic_df <- extract_diagnostics(
    fit,
    data,
    "test",
    "test",
    "test",
    "test",
    "test"
  )

  # Test 1: Test that mean accept stat is above 0.85
  ma_stat <- diagnostic_df %>%
    dplyr::filter(diagnostic == "mean_accept_stat") %>%
    dplyr::pull(value)

  testthat::expect_true(ma_stat > 0.85)

  # Test 2: Test that p_divergent < 0.05
  p_divergent <- diagnostic_df %>%
    dplyr::filter(diagnostic == "p_divergent") %>%
    dplyr::pull(value)

  testthat::expect_true(p_divergent < 0.05)

  # Test 3: Test that Rt estimate range covers true_rt (2.0)
  actual_rt <- fit$summary %>%
    dplyr::filter(measure == "Effective reproduction no.") %>%
    dplyr::select(estimate) %>%
    gsub("[()--]", " ", .)

  # Split the string into numbers
  rt_estimates <- unlist(strsplit(actual_rt, "\\s+"))
  actual_rt_lower <- rt_estimates[length(rt_estimates) - 1]
  actual_rt_upper <- rt_estimates[length(rt_estimates)]

  expected_rt <- 2.0

  testthat::expect_true(
    actual_rt_lower < expected_rt & actual_rt_upper > expected_rt
  )
})
