#' Write model outputs to specified directories
#'
#' Processes the model fit, extracts samples and quantiles,
#' and writes them to the appropriate directories.
#'
#' @param fit An EpiNow2 fit object with posterior estimates.
#' @param output_dir String. The base output directory path.
#' @param samples A data.table as returned by [process_samples()]
#' @param summaries A data.table as returned by [process_quantiles()]
#' @param job_id String. The identifier for the job.
#' @param task_id String. The identifier for the task.
#' @param metadata List. Additional metadata to be included in the output.
#'
#' @return Invisible NULL. The function is called for its side effects.
#' @export
write_model_outputs <- function(
    fit,
    samples,
    summaries,
    output_dir,
    job_id,
    task_id,
    metadata = list()) {
  rlang::try_fetch(
    {
      # Create directory structure
      write_output_dir_structure(output_dir, job_id, task_id)

      # Write raw samples
      samples_path <- file.path(
        output_dir,
        job_id,
        "samples",
        paste0(task_id, ".parquet")
      )
      write_parquet(samples, samples_path)
      cli::cli_alert_success("Wrote samples to {.path {samples_path}}")

      # Process and write summarized quantiles
      summaries_path <- file.path(
        output_dir,
        job_id,
        "summaries",
        paste0(task_id, ".parquet")
      )
      write_parquet(summaries, summaries_path)
      cli::cli_alert_success("Wrote summaries to {.path {summaries_path}}")


      # Write EpiNow2 model
      model_path <- file.path(
        output_dir,
        job_id,
        "tasks",
        task_id,
        "model.rds"
      )
      saveRDS(fit, model_path)
      cli::cli_alert_success("Wrote model to {.path {model_path}}")


      # Write model run metadata
      metadata_path <- file.path(
        output_dir,
        job_id,
        "tasks",
        task_id,
        "metadata.json"
      )
      jsonlite::write_json(metadata, metadata_path, pretty = TRUE)
      cli::cli_alert_success("Wrote metadata to {.path {metadata_path}}")
    },
    error = function(cnd) {
      # Downgrade erroring out to a warning so we can catch and log
      cli::cli_warn(
        "Failure writing outputs",
        parent = cnd,
        class = "no_outputs"
      )
    }
  )

  invisible(NULL)
}

#' Create output directory structure for a given job and task.
#'
#' This function generates the necessary directory structure for storing output
#' files related to a job and its tasks, including directories for raw samples
#' and summarized quantiles.
#'
#' @param output_dir String. The base output directory path.
#' @param job_id String. The identifier for the job.
#' @param task_id String. The identifier for the task.
#'
#' @return The path to the base output directory (invisible).
#' @export
write_output_dir_structure <- function(output_dir, job_id, task_id) {
  # Top level
  dir.create(output_dir,
    showWarnings = FALSE
  )
  # Second level
  dir.create(file.path(output_dir, job_id),
    showWarnings = FALSE
  )
  # Third level
  dir.create(file.path(output_dir, job_id, "tasks"),
    showWarnings = FALSE
  )
  dir.create(file.path(output_dir, job_id, "samples"),
    showWarnings = FALSE
  )
  dir.create(file.path(output_dir, job_id, "summaries"),
    showWarnings = FALSE
  )

  # Fourth level
  dir.create(file.path(output_dir, job_id, "tasks", task_id),
    showWarnings = FALSE
  )

  invisible(output_dir)
}

#' Extract posterior draws from a Stan fit object.
#'
#' This function extracts posterior draws for specific parameters from a Stan
#' fit object and prepares a fact table containing unique date-time-parameter
#' combinations for further merging.
#'
#' @param fit A Stan fit object with posterior estimates.
#'
#' @return A list containing two elements: `stan_draws` (the extracted draws in
#' long format) and `fact_table` (a table of unique date-time-parameter
#' combinations).
#' @noRd
extract_draws_from_fit <- function(fit) {
  # Step 1: Extract unique date-time-parameter combinations
  fact_table <- fit[["estimates"]][["samples"]][,
    c("date", "time", "parameter"),
    with = FALSE
  ]
  fact_table <- stats::na.omit(unique(fact_table))

  # Step 1.1: Add corresponding 'obs_cases' rows for 'latent_cases' dates
  obs_fact_table <- fact_table[
    fact_table[["parameter"]] == "imputed_reports",
  ]
  # The EpiNow2 summary table has the variable `imputed_reports`
  # for nowcast-corrected cases, but not `obs_reports` for right-
  # truncated cases to compare to the observed data. We want both.
  #
  # The dates for `obs_reports` are the same as for `imputed_reports`
  # (their differences are the nowcast correction + error structure).
  # Get the dates for `obs_reports` by pulling out the `imputed_reports`
  # dates and update the associated variable name in-place. Bind it back
  # to the original fact table to have all desired variable-date combinations.
  data.table::set(obs_fact_table, j = "parameter", value = factor(
    obs_fact_table[["parameter"]],
    levels = c("imputed_reports"),
    labels = c("obs_reports")
  ))

  # Combine original fact_table with new 'obs_reports' rows
  fact_table <- rbind(fact_table, obs_fact_table, fill = TRUE)
  data.table::setnames(
    fact_table,
    old = c("parameter"),
    new = c(".variable")
  )

  # Step 2: Extract desired parameters from the Stan object as posterior draws
  stanfit <- fit[["estimates"]][["fit"]]
  # Hacky workaround to avoid R CMD check NOTE on "no visible global binding"
  # for variables in a dataframe evaluated via NSE. To use tidybayes, we need to
  # use NSE, so giving these a global binding. The standard dplyr hacks
  # (str2lang, .data prefix) didn't work here because it's not dplyr and we're
  # not accessing a dataframe.
  imputed_reports <- obs_reports <- R <- r <- time <- NULL # nolint
  stan_draws <- tidybayes::gather_draws(
    stanfit,
    imputed_reports[time],
    obs_reports[time],
    R[time],
    r[time],
  ) |>
    data.table::as.data.table()

  return(list(stan_draws = stan_draws, fact_table = fact_table))
}

#' Post-process and merge posterior draws with a fact table.
#'
#' This function merges posterior draws with a fact table containing
#' date-time-parameter combinations. It also standardizes parameter names and
#' renames key columns.
#'
#' @param draws A data.table of posterior draws (either raw or summarized).
#' @param fact_table A data.table of unique date-time-parameter combinations.
#'
#' @return A data.table with merged posterior draws and standardized parameter
#' names.
#' @noRd
post_process_and_merge <- function(
    draws,
    fact_table,
    geo_value,
    model,
    disease) {
  # Step 1: Left join the date-time-parameter map onto the Stan draws
  merged_dt <- merge(
    draws,
    fact_table,
    by = c("time", ".variable"),
    all.x = TRUE,
    all.y = FALSE
  )

  # Step 2: Standardize parameter names
  data.table::set(merged_dt, j = ".variable", value = factor(
    merged_dt[[".variable"]],
    levels = c("imputed_reports", "obs_reports", "R", "r"),
    labels = c("latent_cases", "obs_cases", "Rt", "growth_rate")
  ))

  # Step 3: Rename columns as necessary
  data.table::setnames(
    merged_dt,
    old = c(
      ".draw", ".chain", ".variable", ".value", ".lower", ".upper", ".width",
      ".point", ".interval", "date", ".iteration"
    ),
    new = c(
      "_draw", "_chain", "_variable", "value", "_lower", "_upper", "_width",
      "_point", "_interval", "reference_date", "_iteration"
    ),
    # If using summaries, skip draws-specific names
    skip_absent = TRUE
  )

  # Metadata for downstream querying without path parsing or joins
  data.table::set(merged_dt, j = "geo_value", value = factor(geo_value))
  data.table::set(merged_dt, j = "model", value = factor(model))
  data.table::set(merged_dt, j = "disease", value = factor(disease))

  return(merged_dt)
}

#' Process posterior samples from a Stan fit object (raw draws).
#'
#' Extracts raw posterior samples from a Stan fit object and post-processes
#' them, including merging with a fact table and standardizing the parameter
#' names. If calling `process_quantiles()` the 50% and 95% intervals are
#' returned in `{tidybayes}` format.
#'
#' @param fit An EpiNow2 fit object with posterior estimates.
#' @param disease,geo_value,model Metadata for downstream processing.
#'
#' @return A data.table of posterior draws or quantiles, merged and processed.
#'
#' @name sample_processing_functions
NULL

#' @rdname sample_processing_functions
#' @export
process_samples <- function(fit, geo_value, model, disease) {
  draws_list <- extract_draws_from_fit(fit)
  raw_processed_output <- post_process_and_merge(
    draws_list$stan_draws,
    draws_list$fact_table,
    geo_value,
    model,
    disease
  )
  return(raw_processed_output)
}

#' @rdname sample_processing_functions
#' @export
process_quantiles <- function(fit, geo_value, model, disease) {
  # Step 1: Extract the draws
  draws_list <- extract_draws_from_fit(fit)

  # Step 2: Summarize the draws
  .variable <- time <- NULL # nolint
  summarized_draws <- draws_list$stan_draws |>
    dplyr::group_by(.variable, time) |>
    tidybayes::median_qi(
      .width = c(0.5, 0.95),
    ) |>
    data.table::as.data.table()

  # Step 3: Post-process summarized draws
  post_process_and_merge(
    summarized_draws,
    draws_list$fact_table,
    geo_value,
    model,
    disease
  )
}

write_parquet <- function(data, path) {
  # This is bad practice but `dbBind()` doesn't allow us to parameterize COPY
  # ... TO.  The danger of doing it this way seems quite low risk because it's
  # ephemeral from a temporary in-memory DB. There's no actual database to
  # guard against a SQL injection attack and all the data are already available
  # here.
  query <- paste0(
    "COPY (SELECT * FROM df) TO '",
    path,
    "' (FORMAT PARQUET, CODEC 'zstd')"
  )
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(expr = DBI::dbDisconnect(con))

  rlang::try_fetch(
    {
      duckdb::duckdb_register(con, "df", data)
      DBI::dbExecute(
        con,
        statement = query
      )
    },
    error = function(con) {
      cli::cli_abort(
        c(
          "Error writing data to {.path {path}}",
          "Original error: {con}"
        ),
        class = "wrapped_invalid_query"
      )
    }
  )

  invisible(path)
}
