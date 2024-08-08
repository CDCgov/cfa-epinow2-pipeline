#' Fetch the config from an external resource
#'
#' This step is the first part of the modeling pipeline. It looks to Azure Blob
#' and downloads the Rt model run's config to the local config (if
#' `blob_storage_container` is specified), reads the config in from the
#' filesystem, and validates that it matches expectations. If any of these steps
#' fails, the pipeline fails with an informative error message. Note, however,
#' that a failure in this initial step suggests that something fundamental is
#' misspecified and the logs will likely not be preserved in a Blob Container if
#' running in Azure.
#'
#' The validation relies on `inst/data/config_schema.json` for validation. This
#' file is in `json-schema` notation and generated programatically via
#' https://www.jsonschema.net/.
#'
#' @param config_path The path to the config file, either in the local
#'   filesystem or with an Azure Blob Storage container. If
#'   `blob_storage_container` is specified, the the path is assumed to be within
#'   the specified container otherwise it is assumed to be in the local
#'   filesystem.
#' @param local_dest The local directory to write the config to when downloading
#'   it from `blob_storage_container`. This argument is ignored unless
#'   `blob_storage_container` is specified.
#' @param blob_storage_container The storage container holding the config at
#'   `config_path`
#' @param config_schema_path The path to the file holding the schema for the
#'   config json for the validator to use.
#'
#' @return A list of lists, the config for the run.
#' @export
fetch_config <- function(
    config_path,
    local_dest,
    blob_storage_container,
    config_schema_path = system.file("extdata/config_schema.json",
      package = "CFAEpiNow2Pipeline"
    )) {
  if (!rlang::is_null(blob_storage_container)) {
    download_from_azure_blob(
      config_path,
      local_dest,
      container_name = blob_storage_container
    )
  } else {
    cli::cli_alert(
      "No blob storage container provided. Reading from local path."
    )
  }

  cli::cli_alert_info("Loading config from {.path {config_path}}")
  validate_config(config_path, config_schema_path)

  config <- rlang::try_fetch(
    jsonlite::read_json(config_path),
    error = function(con) {
      cli::cli_abort(
        "Error loading config from {.path {config_path}}",
        parent = con,
        class = "CFA_Rt"
      )
    }
  )

  return(config)
}

#' Compare loaded json against expectation in `inst/data/config-schema.json`
#'
#' @inheritParams fetch_config
#' @return NULL, invisibly
#' @export
validate_config <- function(
    config_path,
    config_schema_path = system.file("extdata/config_schema.json",
      package = "CFAEpiNow2Pipeline"
    )) {
  is_config_valid <- rlang::try_fetch(
    jsonvalidate::json_validate(
      json = config_path,
      schema = config_schema_path,
      engine = "ajv",
      verbose = TRUE,
      greedy = TRUE,
      error = TRUE
    ),
    error = function(con) {
      cli::cli_abort(
        c(
          "Error while validating config",
          "!" = "Config path: {.path {config_path}}",
          "!" = "Schema path: {.path {config_schema_path}}"
        ),
        parent = con,
        class = "CFA_Rt"
      )
    }
  )

  invisible(is_config_valid)
}
