test_that("extract_samples_from_fit works as expected", {
  # Load the sample fit object
  fit <- readRDS(test_path("data", "sample_fit.RDS"))

  # Run the function on the fit object
  result <- extract_samples_from_fit(fit)

  # Test 1: Check if the result is a data.table
  expect_true(
    data.table::is.data.table(result),
    "The result should be a data.table"
  )

  # Test 2: Check if the necessary columns exist in the result
  expected_columns <- c(
    "time", "_draw", "_chain", "parameter",
    "value", "reference_date"
  )
  expect_true(
    all(expected_columns %in% colnames(result)),
    "The result should contain the required columns"
  )

  # Test 3: Check if the result contains the correct number of rows
  expected_num_rows <- 2000 # Replace with actual expected value
  expect_equal(nrow(result), expected_num_rows,
    info = paste("The result should have", expected_num_rows, "rows")
  )

  # Test 4: Check if the `parameter` column contains the expected values
  expected_parameters <- c("latent_cases", "obs_cases", "Rt", "growth_rate")
  unique_parameters <- unique(result$parameter)
  expect_true(
    setequal(expected_parameters, unique_parameters),
    "The `parameter` column should have standardized parameter names"
  )

  # Test 5: Check if there are no missing values
  expect_false(
    anyNA(result),
    "Colummns have NA"
  )

  # Test 6: Verify the left join: all `time` values from
  #  `stan_draws` should exist in the result
  stan_draws <- tidybayes::spread_draws(
    fit[["estimates"]][["fit"]],
    imputed_reports[time],
    obs_reports[time],
    R[time],
    r[time]
  ) |>
    data.table::as.data.table()

  expect_true(
    all(stan_draws$time %in% result$time),
    "All time values from the Stan fit should be present in the result"
  )
})
