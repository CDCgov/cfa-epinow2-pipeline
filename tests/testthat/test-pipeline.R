test_that("Bad config throws warning and returns failure", {
  # Arrange
  config_path <- test_path("data", "bad_config.json")
  config <- jsonlite::read_json(config_path)
  # Read from locally
  blob_storage_container <- NULL
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  expect_warning(
    pipeline_success <- orchestrate_pipeline(
      config_path = config_path,
      blob_storage_container = blob_storage_container,
      output_dir = output_dir
    ),
    class = "Bad_config"
  )
  expect_false(pipeline_success)
})

test_that("Pipeline run produces expected outputs with NO exclusions", {
  # Arrange
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config <- jsonlite::read_json(config_path)
  # Read from locally
  blob_storage_container <- NULL
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  pipeline_success <- orchestrate_pipeline(
    config_path = config_path,
    blob_storage_container = blob_storage_container,
    output_dir = output_dir
  )
  expect_true(pipeline_success)
  expect_pipeline_files_written(
    output_dir,
    config[["job_id"]],
    config[["task_id"]]
  )
})

test_that("Pipeline run produces expected outputs with exclusions", {
  # Arrange
  config_path <- test_path("data", "sample_config_with_exclusion.json")
  config <- jsonlite::read_json(config_path)
  # Read from locally
  blob_storage_container <- NULL
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  pipeline_success <- orchestrate_pipeline(
    config_path = config_path,
    blob_storage_container = blob_storage_container,
    output_dir = output_dir
  )

  ########
  # Assert output files all exist
  expect_pipeline_files_written(
    output_dir,
    config[["job_id"]],
    config[["task_id"]]
  )
  expect_true(pipeline_success)
})

test_that("Process pipeline produces expected outputs and returns success", {
  # Arrange
  config_path <- test_path("data", "sample_config_with_exclusion.json")
  config <- read_json_into_config(config_path, c("exclusions"))
  # Read from locally
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  pipeline_success <- execute_model_logic(
    config = config,
    output_dir = output_dir
  )
  expect_true(pipeline_success)

  ########
  # Assert output files all exist
  expect_pipeline_files_written(
    output_dir,
    config@job_id,
    config@task_id,
    # Don't check logs here, bc logs are set up by orchestrate_pipeline(), but
    # this test is just for execute_model_logic() which is called after logs are
    # set up in orchestrate_pipeline().
    check_logs = FALSE
  )
})

test_that("Runs on config from generator as of 2024-11-26", {
  # Arrange
  config_path <- test_path("data", "CA_COVID-19.json")
  config <- read_json_into_config(config_path, c("exclusions"))
  # Read from locally
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  pipeline_success <- execute_model_logic(
    config = config,
    output_dir = output_dir
  )
  expect_true(pipeline_success)

  ########
  # Assert output files all exist
  expect_pipeline_files_written(
    output_dir,
    config@job_id,
    config@task_id,
    # Do not check for log output here, bc logs get created in
    # `orchestrate_pipeline()`, and this test only calls `execute_model_logic()`
    # which gets called after the log files have been created.
    check_logs = FALSE
  )
})

test_that("Warning and exit for bad config file", {
  # Arrange
  config_path <- test_path("data", "v_bad_config.json")
  # Read from locally
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  expect_warning(
    pipeline_success <- orchestrate_pipeline(
      config_path = config_path,
      blob_storage_container = NULL,
      output_dir = output_dir
    ),
    class = "Bad_config"
  )
  expect_false(pipeline_success)
})
