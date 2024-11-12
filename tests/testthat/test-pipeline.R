test_that("Pipeline run produces expected outputs", {
  # Arrange
  config_path <- test_path("data", "sample_config.json")
  config <- jsonlite::read_json(config_path)
  # Read from locally
  blob_storage_container <- NULL
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  pipeline_success <- run_pipeline(
    config_path = config_path,
    blob_storage_container = blob_storage_container,
    output_dir = output_dir
  )

  ########
  # Assert output files all exist
  job_path <- file.path(output_dir, config[["job_id"]])
  task_path <- file.path(job_path, "tasks", config[["task_id"]])

  # Samples
  expect_true(
    file.exists(
      file.path(
        job_path,
        "samples",
        paste0(
          config[["task_id"]],
          ".parquet"
        )
      )
    )
  )
  # Summaries
  expect_true(
    file.exists(
      file.path(
        job_path,
        "summaries",
        paste0(
          config[["task_id"]],
          ".parquet"
        )
      )
    )
  )
  # Model
  file.exists(
    file.path(task_path, "model.rds")
  )
  # Logs
  file.exists(
    file.path(task_path, "logs.txt")
  )
})

test_that("Process pipeline produces expected outputs and returns success", {
  # Arrange
  config_path <- test_path("data", "sample_config.json")
  config <- jsonlite::read_json(config_path)
  # Read from locally
  output_dir <- "pipeline_test"
  on.exit(unlink(output_dir, recursive = TRUE))

  # Act
  pipeline_success <- process_pipeline(
    config = config,
    output_dir = output_dir
  )
  expect_true(pipeline_success)

  ########
  # Assert output files all exist
  job_path <- file.path(output_dir, config[["job_id"]])
  task_path <- file.path(job_path, "tasks", config[["task_id"]])

  # Samples
  expect_true(
    file.exists(
      file.path(
        job_path,
        "samples",
        paste0(
          config[["task_id"]],
          ".parquet"
        )
      )
    )
  )
  # Summaries
  expect_true(
    file.exists(
      file.path(
        job_path,
        "summaries",
        paste0(
          config[["task_id"]],
          ".parquet"
        )
      )
    )
  )
  # Model
  file.exists(
    file.path(task_path, "model.rds")
  )
  # Logs
  file.exists(
    file.path(task_path, "logs.txt")
  )
})
