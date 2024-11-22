expect_pipeline_files_written <- function(output_dir, job_id, task_id) {
  ########
  # Assert output files all exist
  job_path <- file.path(output_dir, job_id)
  task_path <- file.path(job_path, "tasks", task_id)

  # Samples
  expect_true(
    file.exists(
      file.path(
        job_path,
        "samples",
        paste0(task_id, ".parquet")
      )
    )
  )
  # Summaries
  expect_true(
    file.exists(
      file.path(
        job_path,
        "summaries",
        paste0(task_id, ".parquet")
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
}
