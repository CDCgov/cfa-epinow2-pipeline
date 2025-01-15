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
#' @param metadata List. Additional metadata to be included in the output. The
#' paths to the samples, summaries, and model output will be added to the
#' metadata list.
#'
#' @return Invisible NULL. The function is called for its side effects.
#' @family write_output
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
      # Add paths to metadata.
      metadata <- utils::modifyList(
        metadata,
        list(
          samples_path = samples_path,
          summaries_path = summaries_path,
          model_path = model_path
        )
      )
      jsonlite::write_json(
        metadata, metadata_path,
        pretty = TRUE, auto_unbox = TRUE
      )
      cli::cli_alert_success("Wrote metadata to {.path {metadata_path}}")
    },
    error = function(cnd) {
      # Downgrade erroring out to a warning so we can catch and log
      cli::cli_abort(
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
#' @family write_output
#' @export
write_output_dir_structure <- function(output_dir, job_id, task_id) {
  # Define the directory structure
  dirs <- c(
    output_dir,
    file.path(output_dir, job_id),
    file.path(output_dir, job_id, "tasks"),
    file.path(output_dir, job_id, "samples"),
    file.path(output_dir, job_id, "summaries"),
    file.path(output_dir, job_id, "tasks", task_id)
  )

  # Create directories
  lapply(dirs, dir.create, showWarnings = FALSE)

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
  # Some of the `*_reports` parameters are indexed from time 1, ..., T and some
  # go to time T + forecast horizon. `imputed_reports` goes out to T + forecast
  # horizon so we can do a downstream join and that will save only up to the max
  # timepoint for that parameter.
  obs_fact_table <- fact_table[
    fact_table[["parameter"]] == "imputed_reports",
  ]
  reports_fact_table <- data.table::copy(obs_fact_table)

  # The EpiNow2 summary table has the variable `imputed_reports`
  # for nowcast-corrected cases, but not `obs_reports` for right-
  # truncated cases to compare to the observed data. We want both.
  #
  # The dates for `obs_reports` are the same as for `imputed_reports`
  # (their differences are the nowcast correction + error structure).
  # From Sam: imputed reports have error and are corrected for right-truncation
  # (a posterior pred of the final observed value). Obs reports is the
  # expected value actually observed in real time but without obs error.
  # Get the dates for `obs_reports` by pulling out the `imputed_reports`
  # dates and update the associated variable name in-place. Bind it back
  # to the original fact table to have all desired variable-date combinations.
  data.table::set(obs_fact_table, j = "parameter", value = factor(
    obs_fact_table[["parameter"]],
    levels = c("imputed_reports"),
    labels = c("obs_reports")
  ))
  data.table::set(reports_fact_table, j = "parameter", value = factor(
    reports_fact_table[["parameter"]],
    levels = c("imputed_reports"),
    labels = c("reports")
  ))


  # Combine original fact_table with new 'obs_reports' rows
  fact_table <- rbind(fact_table,
    obs_fact_table,
    reports_fact_table,
    fill = TRUE
  )
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
  imputed_reports <- obs_reports <- R <- r <- time <- reports <- NULL # nolint
  stan_draws <- tidybayes::gather_draws(
    stanfit,
    reports[time],
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
#' @family write_output
#' @noRd
post_process_and_merge <- function(
    fit,
    draws,
    fact_table,
    geo_value,
    model,
    disease) {
  # Step 0: isolate "as_of" cases from fit objec. Create constants
  fit_obs <- fit$estimates$observations |> data.table::as.data.table()
  names(fit_obs)[names(fit_obs) == "confirm"] <- ".value"
  data.table::set(fit_obs, j = ".variable", value = "fit_obs")

  # Step 1: Left join the date-time-parameter map onto the Stan draws
  merged_dt <- merge(
    draws,
    fact_table,
    by = c("time", ".variable"),
    all.x = TRUE,
    all.y = FALSE
  )

  # Step 1.5 Merge as_of_cases with merged_dt to get time variable
  fit_obs_time <- unique(
    merge(
      fit_obs,
      merged_dt[, c("date", "time"), with = FALSE],
      by = c("date"),
      all.x = FALSE,
      all.y = TRUE
    )
  )
  # Step 1.75 rbind as_of_cases with merged_dt and sort
  merged_dt <- rbind(merged_dt, fit_obs_time, fill = TRUE)
  sort_cols <- c("time", ".variable")
  merged_dt <- data.table::setorderv(merged_dt, sort_cols)

  # Step 2: Standardize parameter names
  data.table::set(merged_dt, j = ".variable", value = factor(
    merged_dt[[".variable"]],
    levels = c(
      "fit_obs",
      "reports",
      "imputed_reports",
      "obs_reports",
      "R",
      "r"
    ),
    labels = c(
      "fit_obs_cases",
      "expected_nowcast_cases",
      "pp_nowcast_cases",
      "expected_obs_cases",
      "Rt",
      "growth_rate"
    )
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
#' @param quantiles A vector of quantiles to pass to [tidybayes::median_qi()]
#'
#' @return A data.table of posterior draws or quantiles, merged and processed.
#'
#' @family write_output
#' @name sample_processing_functions
NULL

#' @rdname sample_processing_functions
#' @export
process_samples <- function(fit, geo_value, model, disease) {
  draws_list <- extract_draws_from_fit(fit)
  raw_processed_output <- post_process_and_merge(
    fit,
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
process_quantiles <- function(
    fit,
    geo_value,
    model,
    disease,
    quantiles) {
  # Step 1: Extract the draws
  draws_list <- extract_draws_from_fit(fit)

  # Step 2: Summarize the draws
  .variable <- time <- NULL # nolint
  summarized_draws <- draws_list$stan_draws |>
    dplyr::group_by(.variable, time) |>
    tidybayes::median_qi(
      .width = quantiles,
    ) |>
    data.table::as.data.table()

  # Step 3: Post-process summarized draws
  post_process_and_merge(
    fit,
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
