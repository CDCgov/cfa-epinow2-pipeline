test_that("write_model_outputs writes files and directories correctly", {
  # Setup: Create a temporary directory and mock inputs
  temp_output_dir <- tempfile()
  dir.create(temp_output_dir)

  job_id <- "job_123"
  task_id <- "task_456"

  # Create mock fit object
  mock_fit <- list(estimates = 1:5)
  mock_samples <- data.frame(x = 1)
  mock_summaries <- data.frame(y = 2)
  mock_metadata <- list(author = "Test", date = "2023-01-01")
  mock_diagnostics <- list(diagnostic = "Test")

  # Run the function
  withr::with_tempdir({
    write_model_outputs(
      mock_fit,
      mock_samples,
      mock_summaries,
      ".",
      job_id,
      task_id,
      mock_metadata,
      mock_diagnostics
    )

    # Check if the directory structure was created
    expect_true(dir.exists(file.path(job_id, "samples")))
    expect_true(dir.exists(file.path(job_id, "summaries")))
    expect_true(dir.exists(file.path(job_id, "tasks", task_id)))

    # Check if raw samples Parquet file was written
    samples_file <- file.path(
      job_id,
      "samples",
      paste0(task_id, ".parquet")
    )
    expect_true(file.exists(samples_file))

    # Check if summarized quantiles Parquet file was written
    summarized_file <- file.path(
      job_id,
      "summaries",
      paste0(task_id, ".parquet")
    )
    expect_true(file.exists(summarized_file))

    # Check if model rds file was written
    model_file <- file.path(
      job_id,
      "tasks",
      task_id,
      "model.rds"
    )
    expect_true(file.exists(model_file))

    # Check if the diagnostics file was written
    diagnostics_file <- file.path(
      job_id,
      "tasks",
      task_id,
      "diagnostics.parquet"
    )
    expect_true(file.exists(diagnostics_file))

    # Check if metadata JSON file was written
    metadata_file <- file.path(
      job_id,
      "tasks",
      task_id,
      "metadata.json"
    )
    expect_true(file.exists(metadata_file))

    # Check file contents are right
    con <- DBI::dbConnect(duckdb::duckdb())
    on.exit(expr = DBI::dbDisconnect(con))
    raw_samples_data <- DBI::dbGetQuery(con,
      "SELECT * FROM read_parquet(?)",
      params = list(samples_file)
    )
    expect_equal(raw_samples_data, mock_samples)

    raw_summaries_data <- DBI::dbGetQuery(con,
      "SELECT * FROM read_parquet(?)",
      params = list(summarized_file)
    )
    expect_equal(raw_summaries_data, mock_summaries)


    written_metadata <- jsonlite::read_json(metadata_file)
    jsonlite::write_json(mock_metadata, "expected.json")
    expected_metadata <- jsonlite::read_json(metadata_file)

    expect_equal(written_metadata, expected_metadata)
  })
})

test_that("write_model_outputs handles errors correctly", {
  # Setup: Use an invalid directory to trigger an error
  invalid_output_dir <- "/invalid/path"

  # Create mock inputs
  mock_fit <- list(samples = 1:5)
  mock_metadata <- list(author = "Test", date = Sys.Date())
  samples <- data.frame(x = 1)
  summaries <- data.frame(y = 2)
  mock_diagnostics <- list(diagnostic = "Test")


  # Expect the function to raise a warning due to the invalid directory
  withr::with_tempdir({
    expect_error(
      write_model_outputs(
        fit = mock_fit,
        samples = samples,
        summaries = summaries,
        output_dir = invalid_output_dir,
        job_id = "job_123",
        task_id = "task_456",
        metadata = mock_metadata,
        diagnostics = mock_diagnostics
      ),
      class = "no_outputs"
    )
  })
})

test_that("write_output_dir_structure generates dirs", {
  withr::with_tempdir({
    write_output_dir_structure(".", job_id = "job", task_id = "task")

    expect_true(dir.exists(file.path("job", "tasks", "task")))
    expect_true(dir.exists(file.path("job", "samples")))
    expect_true(dir.exists(file.path("job", "summaries")))
  })
})

test_that("process_quantiles works as expected", {
  # Load the sample fit object
  fit <- readRDS(test_path("data", "sample_fit_rstan.rds"))

  # Run the function on the fit object
  result <- process_quantiles(
    fit,
    "test_geo",
    "test_model",
    "test_disease",
    c(0.5, 0.95)
  )

  # Test 1: Check if the result is a data.table
  expect_true(
    data.table::is.data.table(result),
    "The result should be a data.table"
  )

  # Test 2: Check if the necessary columns exist in the result
  expected_columns <- c(
    "time",
    "_variable",
    "value",
    "_lower",
    "_upper",
    "_width",
    "_point",
    "_interval",
    "reference_date",
    "geo_value",
    "model",
    "disease"
  )
  expect_setequal(
    colnames(result), expected_columns
  )

  # Test 3: Check if the result contains the correct number of rows
  expected_num_rows <- 55
  expect_equal(nrow(result), expected_num_rows,
    info = paste("The result should have", expected_num_rows, "rows")
  )

  # Test 4: Check if the `parameter` column contains the expected values
  expected_parameters <- c(
    "Rt",
    "expected_nowcast_cases",
    "expected_obs_cases",
    "growth_rate",
    "pp_nowcast_cases",
    "processed_obs_data"
  )
  unique_parameters <- sort(unique(as.character(result[["_variable"]])))
  expect_equal(
    unique_parameters, expected_parameters
  )

  # Test 5: Check if there are no missing values
  expect_false(
    anyNA(result[result[["_variable"]] != "processed_obs_data", ]),
    "Relevant columns have NA values"
  )

  # Test 6: Verify the left join: all `time` values from
  # `stan_draws` should exist in the result
  stan_draws <- tidybayes::gather_draws(
    fit[["estimates"]][["fit"]],
    imputed_reports[time],
    obs_reports[time],
    R[time],
    r[time]
  ) |>
    tidybayes::median_qi(.width = c(0.5, 0.95)) |>
    data.table::as.data.table()

  expect_true(
    all(stan_draws$time %in% result$time),
    "All time values from the Stan fit should be present in the result"
  )
})

test_that("process_samples works as expected", {
  # Load the sample fit object
  fit <- readRDS(test_path("data", "sample_fit_rstan.rds"))

  # Run the function on the fit object
  result <- process_samples(fit, "test_geo", "test_model", "test_disease")

  # Test 1: Check if the result is a data.table
  expect_true(
    data.table::is.data.table(result),
    "The result should be a data.table"
  )

  # Test 2: Check if the necessary columns exist in the result
  expected_columns <- c(
    "time",
    "_variable",
    "_chain",
    "_iteration",
    "_draw",
    "value",
    "reference_date",
    "geo_value",
    "model",
    "disease"
  )
  expect_setequal(
    colnames(result), expected_columns
  )

  # Test 3: Check if the result contains the correct number of rows
  expected_num_rows <- 2505 # Replace with actual expected value
  expect_equal(nrow(result), expected_num_rows,
    info = paste("The result should have", expected_num_rows, "rows")
  )

  # Test 4: Check if the `parameter` column contains the expected values
  expected_parameters <- c(
    "Rt",
    "expected_nowcast_cases",
    "expected_obs_cases",
    "growth_rate",
    "pp_nowcast_cases",
    "processed_obs_data"
  )
  unique_parameters <- sort(unique(as.character(result[["_variable"]])))
  expect_equal(
    unique_parameters, expected_parameters
  )

  # Test 5: Check if there are no missing values
  expect_false(
    anyNA(result[result[["_variable"]] != "processed_obs_data", ]),
    "Columns have NA values"
  )

  # Test 6: Verify the left join: all `time` values from
  # `stan_draws` should exist in the result
  stan_draws <- tidybayes::gather_draws(
    fit[["estimates"]][["fit"]],
    imputed_reports[time],
    obs_reports[time],
    R[time],
    r[time]
  ) |>
    tidybayes::median_qi(.width = c(0.5, 0.95)) |>
    data.table::as.data.table()

  expect_true(
    all(stan_draws$time %in% result$time),
    "All time values from the Stan fit should be present in the result"
  )
})

test_that("write_parquet successfully writes data to parquet", {
  # Prepare temporary file and sample data


  temp_path <- "test.parquet"
  test_data <- data.frame(
    id = 1:5,
    value = c("A", "B", "C", "D", "E")
  )

  # Run the function
  withr::with_tempdir({
    result <- write_parquet(test_data, temp_path)

    # Check if the function returns the correct path
    expect_equal(result, temp_path)

    # Check if the parquet file exists
    expect_true(file.exists(temp_path))

    # Read the file back to ensure data was written correctly
    con <- DBI::dbConnect(duckdb::duckdb())
    on.exit(expr = DBI::dbDisconnect(con))
    actual <- DBI::dbGetQuery(con, "SELECT * FROM 'test.parquet'")

    # Verify the data matches the input
    expect_equal(actual, test_data)
  })
})

test_that("write_parquet handles errors correctly", {
  # Prepare a temporary path that should fail (invalid directory)
  invalid_path <- "/invalid/path/test.parquet"
  test_data <- data.frame(id = 1:5, value = c("A", "B", "C", "D", "E"))

  # Expect the function to throw an error when writing to an invalid path
  expect_error(
    write_parquet(test_data, invalid_path),
    class = "wrapped_invalid_query"
  )
})
