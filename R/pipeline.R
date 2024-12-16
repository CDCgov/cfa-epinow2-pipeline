#' Run an Rt Estimation Model Pipeline
#'
#' This function runs a complete pipeline for fitting an Rt estimation model,
#' using the `EpiNow2` model, based on a configuration file. The pipeline
#' processes the model, logs its progress, and handles errors by logging
#' warnings and setting the pipeline status. Output and logs are written to
#' the specified directories. Additionally, support for uploading logs and
#' outputs to a blob storage container is planned.
#'
#' @param config_path A string specifying the file path to the JSON
#' configuration file.
#' @param blob_storage_container Optional. The name of the blob storage
#' container to which logs and outputs will be uploaded. If NULL, no upload
#' will occur. (Planned feature, not currently implemented)
#' @param output_dir A string specifying the directory where output, logs, and
#' other pipeline artifacts will be saved. Defaults to the root directory ("/").
#'
#' @details
#' The function reads the configuration from a JSON file and uses this to set
#' up the job and task identifiers. It creates an output directory structure
#' based on these IDs and starts logging the process in a file. The main
#' pipeline process is handled by `execute_model_logic()`, with errors
#' caught and logged as warnings. The function will log the success or
#' failure of the run.
#'
#' Logs are written to a file in the output directory, and console output is
#' also mirrored in this log file. Error handling is in place to capture any
#' issues during the pipeline execution and ensure they are logged
#' appropriately.
#'
#' During the execution of the pipeline, the following output files are
#' expected to be generated:
#'
#' - **Model Output**: An RDS file of the fitted model is saved in the
#' task-specific directory (`model.rds`).
#' - **Samples**: Parquet files containing the model's sample outputs are saved
#' in a `samples` subdirectory, named using the `task_id` (e.g.,
#' `task_id.parquet`).
#' - **Summaries**: Parquet files summarizing the model's results are saved in
#' a `summaries` subdirectory, also named using the `task_id` (e.g.,
#' `task_id.parquet`).
#' - **Logs**: A `logs.txt` file is generated in the task directory, capturing
#' both console and error messages.
#'
#' The output directory structure will follow this format:
#' ```
#' <output_dir>/
#' └── <job_id>/
#'     ├── samples/
#'     │   └── <task_id>.parquet
#'     ├── summaries/
#'     │   └── <task_id>.parquet
#'     └── tasks/
#'         └── <task_id>/
#'             ├── model.rds
#'             └── logs.txt
#' ```
#'
#' @return The function returns a boolean, TRUE For pipeline success and FALSE
#'  otherwise. It writes the files:
#' directory will contain the following files:
#' - Model RDS file (`model.rds`)
#' - Sample output in Parquet format (`<task_id>.parquet` in the `samples/`
#' directory)
#' - Summary output in Parquet format (`<task_id>.parquet` in the `summaries/`
#' directory)
#' - Log file (`logs.txt`) in the task directory
#'
#' @rdname pipeline
#' @family pipeline
#' @export
orchestrate_pipeline <- function(config_path,
                                 blob_storage_container = NULL,
                                 output_dir = "/") {
  config <- rlang::try_fetch(
    read_json_into_config(config_path, c("exclusions")),
    error = function(con) {
      cli::cli_warn("Bad config file",
        parent = con,
        class = "Bad_config"
      )
      FALSE
    }
  )
  if (typeof(config) == "logical") {
    return(invisible(FALSE))
  }

  write_output_dir_structure(
    output_dir = output_dir,
    job_id = config@job_id,
    task_id = config@task_id
  )

  # Set up logs
  logfile_path <- file.path(
    output_dir,
    config@job_id,
    "tasks",
    config@task_id
  )
  logfile_connection <- file(file.path(logfile_path, "logs.txt"), open = "wt")
  sink(
    logfile_connection,
    type = "output",
    append = TRUE,
    # Send output to logs and to console
    split = TRUE
  )
  sink(
    logfile_connection,
    type = "message",
    append = TRUE
  )
  on.exit(sink(file = NULL))
  cli::cli_alert_info("Starting run at {Sys.time()}")
  cli::cli_alert_info("Using job id {.field {config@job_id}}")
  cli::cli_alert_info("Using task id {.field {config@task_id}}")

  # Errors within `execute_model_logic()` are downgraded to warnings so
  # they can be logged and stored in Blob. If there is an error,
  # `pipeline_success` is set to false, which will be stored in the
  # metadata in the next PR.
  pipeline_success <- rlang::try_fetch(
    execute_model_logic(config, output_dir, blob_storage_container),
    error = function(con) {
      cli::cli_warn("Pipeline run failed",
        parent = con,
        class = "Run_failed"
      )
      FALSE
    }
  )

  # TODO: Move metadata to outer wrapper
  cli::cli_alert_info("Finishing run at {Sys.time()}")
  invisible(pipeline_success)
}

#' Run the Model Fitting Process
#'
#' @param config A Config object containing configuration settings for the
#' pipeline, including paths to data, exclusions, disease parameters, model
#' settings, and other necessary inputs.
#'
#' @details
#' This function performs the core model fitting process within the Rt
#' estimation pipeline, including reading data, applying exclusions, fitting
#' the model, and writing outputs such as model samples, summaries, and logs.
#'
#' @return Returns `TRUE` on success. Errors are caught by the outer pipeline
#' logic and logged accordingly.
#'
#' @rdname pipeline
#' @family pipeline
#' @export
execute_model_logic <- function(config, output_dir, blob_storage_container) {
  cases_df <- read_data(
    data_path = config@data@path,
    disease = config@disease,
    state_abb = config@geo_value,
    report_date = config@report_date,
    max_reference_date = config@max_reference_date,
    min_reference_date = config@min_reference_date
  )

  # rlang::is_empty() checks for empty and NULL values
  if (!rlang::is_empty(config@exclusions@path)) {
    exclusions_df <- read_exclusions(config@exclusions@path)
    cases_df <- apply_exclusions(cases_df, exclusions_df)
  } else {
    cli::cli_alert("No exclusions file provided. Skipping exclusions")
  }

  params <- read_disease_parameters(
    generation_interval_path = config@parameters@generation_interval@path,
    delay_interval_path = config@parameters@delay_interval@path,
    right_truncation_path = config@parameters@right_truncation@path,
    disease = config@disease,
    as_of_date = config@parameters@as_of_date,
    group = config@geo_value,
    report_date = config@report_date
  )

  fit <- fit_model(
    data = cases_df,
    parameters = params,
    seed = config@seed,
    horizon = config@horizon,
    priors = config@priors,
    sampler_opts = config@sampler_opts
  )
  diagnostics <- extract_diagnostics(
    fit = fit,
    data = cases_df,
    job_id = config@job_id,
    task_id = config@task_id,
    disease = config@disease,
    geo_value = config@geo_value,
    model = config@model
  )
  samples <- process_samples(
    fit = fit,
    geo_value = config@geo_value,
    model = config@model,
    disease = config@disease
  )
  summaries <- process_quantiles(
    fit = fit,
    geo_value = config@geo_value,
    model = config@model,
    disease = config@disease,
    quantiles = unlist(config@quantile_width)
  )

  # All the top level metadata fields
  metadata <- list(
    job_id = config@job_id,
    task_id = config@task_id,
    data_path = empty_str_if_non_existant(config@data@path),
    model = config@model,
    disease = config@disease,
    geo_value = config@geo_value,
    report_date = config@report_date,
    production_date = config@production_date,
    max_reference_date = config@max_reference_date,
    min_reference_date = config@min_reference_date,
    exclusions = empty_str_if_non_existant(config@exclusions@path),
    blob_storage_container = empty_str_if_non_existant(blob_storage_container),
    run_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )

  write_model_outputs(
    fit = fit,
    samples = samples,
    summaries = summaries,
    output_dir = output_dir,
    job_id = config@job_id,
    task_id = config@task_id,
    metadata = metadata
  )

  return(TRUE)
}

#' Fit an EpiNow2 model
#'
#' @param data, in the format returned by [CFAEpiNow2Pipeline::read_data()]
#' @param parameters As returned from
#'   [CFAEpiNow2Pipeline::read_disease_parameters()]
#' @param seed The random seed, used for both initialization by EpiNow2 in R and
#'   sampling in Stan
#' @param horizon The number of days, as an integer, to forecast
#' @param priors A list of lists. The first level should contain the key `rt`
#'   with elements `mean` and `sd` and the key `gp` with element `alpha_sd`.
#' @param sampler_opts A list. The Stan sampler options to be passed through
#'   EpiNow2. It has required keys: `cores`, `chains`, `iter_warmup`,
#'   `iter_sampling`, `max_treedepth`, and `adapt_delta`.
#'
#' @return A fitted model object of class `epinow` or, if model fitting fails,
#'   an NA is returned with a warning
#' @family pipeline
#' @export
fit_model <- function(
    data,
    parameters,
    seed,
    horizon,
    priors,
    sampler_opts) {
  # Priors ------------------------------------------------------------------
  rt <- EpiNow2::rt_opts(
    list(
      mean = priors[["rt"]][["mean"]],
      sd = priors[["rt"]][["sd"]]
    )
  )
  gp <- EpiNow2::gp_opts(
    alpha_sd = priors[["gp"]][["alpha_sd"]]
  )
  
  # Distributions -----------------------------------------------------------
  generation_time <- format_generation_interval(
    parameters[["generation_interval"]]
  )
  delays <- format_delay_interval(
    parameters[["delay_interval"]]
  )
  truncation <- format_right_truncation(
    parameters[["right_truncation"]],
    data
  )
  stan <- format_stan_opts(
    sampler_opts, seed
  )
  df <- data.frame(
    confirm = data[["confirm"]],
    date = as.Date(data[["reference_date"]])
  )
  rlang::try_fetch(
    withr::with_seed(seed, {
      EpiNow2::epinow(
        df,
        generation_time = generation_time,
        delays = delays,
        truncation = truncation,
        horizon = horizon,
        rt = rt,
        gp = gp,
        stan = stan,
        verbose = TRUE,
        # Dump logs to console to be caught by pipeline's logging instead of
        # EpiNow2's default through futile.logger
        logs = EpiNow2::setup_logging(
          threshold = "INFO",
          file = NULL,
          mirror_to_console = TRUE,
          name = "EpiNow2"
        ),
        filter_leading_zeros = FALSE,
      )
    }),
    error = function(cnd) {
      cli::cli_abort(
        "Call to EpiNow2::epinow() failed with an error",
        parent = cnd,
        class = "failing_fit"
      )
    }
  )
}

format_stan_opts <- function(sampler_opts, seed) {
  expected_stan_args <- c(
    "cores",
    "chains",
    "iter_warmup",
    "iter_sampling",
    "adapt_delta",
    "max_treedepth"
  )
  missing_keys <- !(expected_stan_args %in% names(sampler_opts))
  missing_elements <- rlang::is_null(sampler_opts[expected_stan_args])
  if (any(missing_keys) || any(missing_elements)) {
    cli::cli_abort(c(
      "Missing expected keys/values in {.val sampler_opts}",
      "Missing keys: {.val {expected_stan_args[missing_keys]}}",
      "Missing values: {.val {expected_stan_args[missing_elements]}}"
    ))
  }
  
  # Stan sampler ------------------------------------------------------------
  EpiNow2::stan_opts(
    cores = sampler_opts[["cores"]],
    chains = sampler_opts[["chains"]],
    # NOTE: seed gets used twice -- as the seed passed here to the Stan sampler
    # and as the R PRNG seed for EpiNow2 initialization
    seed = seed,
    warmup = sampler_opts[["iter_warmup"]],
    samples = sampler_opts[["iter_sampling"]],
    control = list(
      adapt_delta = sampler_opts[["adapt_delta"]],
      max_treedepth = sampler_opts[["max_treedepth"]]
    )
  )
}
