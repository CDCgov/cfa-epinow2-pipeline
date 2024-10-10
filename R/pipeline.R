#' Rt estimation model pipeline
#' @export
run_pipeline <- function(config_path,
                         blob_storage_container = NULL,
                         output_dir = "/") {
  # TODO: Add config reader here
  config <- jsonlite::read_json("sample_config.json")

  write_output_dir_structure(
    output_dir = output_dir,
    job_id = config[["job_id"]],
    task_id = config[["task_id"]]
  )

  # Set up logs
  logfile_path <- file.path(
    output_dir,
    config[["job_id"]],
    "tasks",
    config[["task_id"]]
  )
  stdout_log <- file(file.path(logfile_path, "stdout.txt"), open = "wt")
  stderr_log <- file(file.path(logfile_path, "stderr.txt"), open = "wt")
  sink(
    stdout_log,
    type = "output",
    append = TRUE,
    # Send output to logs and to console
    split = TRUE
  )
  sink(
    stdout_log,
    type = "message",
    append = TRUE
  )
  cli::cli_alert_info("Starting run at {Sys.time()}")
  cli::cli_alert_info("Using job id {.field {config[['job_id']]}}")
  cli::cli_alert_info("Using task id {.field {config[['task_id']]}}")

  cases_df <- read_data(
    data_path = config[["data"]][["path"]],
    disease = config[["disease"]],
    state_abb = config[["geo_value"]],
    report_date = config[["report_date"]],
    max_reference_date = config[["max_reference_date"]],
    min_reference_date = config[["min_reference_date"]]
  )

  if (!rlang::is_null(config[["exclusions"]][["path"]])) {
    exclusions_df <- read_exclusions(config[["exclusions"]][["path"]])
    cases_df <- apply_exclusions(cases_df, exclusions_df)
  }

  params <- read_disease_parameters(
    generation_interval_path = config[["parameters"]]
    [["generation_interval"]]
    [["path"]],
    delay_interval_path = config[["parameters"]]
    [["delay_interval"]]
    [["path"]],
    right_truncation_path = config[["parameters"]]
    [["right_truncation"]]
    [["path"]],
    disease = config[["disease"]],
    as_of_date = config[["as_of_date"]],
    group = config[["geo_value"]],
    report_date = config[["report_date"]]
  )

  fit <- fit_model(
    data = cases_df,
    parameters = params,
    seed = config[["seed"]],
    horizon = config[["horizon"]],
    priors = config[["priors"]],
    sampler_opts = config[["sampler_opts"]]
  )

  diagnostics <- extract_diagnostics(
    fit = fit,
    data = cases_df,
    job_id = config[["job_id"]],
    task_id = config[["task_id"]],
    disease = config[["disease"]],
    geo_value = config[["geo_value"]],
    model = config[["model"]]
  )
  samples <- process_samples(
    fit = fit,
    geo_value = config[["geo_value"]],
    model = config[["model"]],
    disease = config[["disease"]]
  )
  summaries <- process_quantiles(
    fit = fit,
    geo_value = config[["geo_value"]],
    model = config[["model"]],
    disease = config[["disease"]],
    quantiles = unlist(config[["quantile_width"]])
  )

  write_model_outputs(
    fit = fit,
    samples = samples,
    summaries = summaries,
    output_dir = output_dir,
    job_id = config[["job_id"]],
    task_id = config[["task_id"]],
    metadata = list()
  )


  # End logging. One for stdout and one for stderr.
  sink(file = NULL)
  sink(file = NULL)
}
