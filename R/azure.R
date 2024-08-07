#' Download specified blobs from Blob Storage and save them in a local dir
#'
#' Note that I think it might be wise to instead specify a blob prefix, list the
#' blobs, and download all the listed blobs. This would let us have some more
#' flexibility with downloading whole remote directories (like delta tables)
#'
#' @param blob_names A vector of blobs to donwload from `container_name`
#' @param local_dest The path to the local directory to save the files in
#' @param container_name The Azure Blob Storage container with `blob_names`
#'
#' @return NULL on success
#' @export
download_from_azure_blob <- function(blob_names, local_dest, container_name) {
  blob_container <- rlang::try_fetch(
    fetch_blob_container(container_name),
    error = function(con) {
      cli::cli_abort(
        c(
          "Unable to authenticate connection to Blob endpoint",
          "!" = "Check correct credentials are present as env variables",
          "!" = "Check container {.var {container_name}} is correct"
        ),
        parent = con
      )
    }
  )

  for (blob in blob_names) {
    local_file_path <- file.path(local_dest, blob)
    rlang::try_fetch(
      download_file_from_container(
        blob,
        blob_container,
        local_file_path
      ),
      error = function(con) {
        cli::cli_abort(
          c(
            "Error downloading blob {.path {blob}}",
            "Using container {.path {container_name}}",
            "Writing to local file path {.path local_file_path}"
          ),
          parent = con
        )
      }
    )
  }
  cli::cli_alert_success("Blobs {.path {blob_names}} downloaded successfully")
  invisible(NULL)
}

download_file_from_container <- function(
    blob_storage_path,
    container,
    local_file_path) {
  cli::cli_alert_info(
    "Downloading blob {.path {blob_storage_path}} to {.path {local_file_path}}"
  )

  AzureStor::download_blob(
    container = container,
    src = blob_storage_path,
    dest = local_file_path,
    overwrite = TRUE
  )

  cli::cli_alert_success(
    "Blob {.path {blob_storage_path}} downloaded successfully"
  )

  invisible(local_file_path)
}

#' Load Azure Blob endpoint using credentials in environment variables
#'
#' This **impure** function depends on the environment variables:
#' * TENANT_ID
#' * SUBSCRIPTION
#' * RESOURCE_GROUP
#' * STORAGE_ACCOUNT
#'
#' It will error out if any of the above is not set.
#' @param container_name The Azure Blob Storage container associated with the
#'   credentials
#' @return A Blob endpoint
#' @export
fetch_blob_container <- function(container_name) {
  cli::cli_alert_info(
    "Attempting to connect to container {.var {container_name}}"
  )
  cli::cli_alert_info("Loading Azure credentials from env vars")
  # nolint start: object_name_linter
  TENANT_ID <- fetch_credential_from_env_var("TENANT_ID")
  SUBSCRIPTION <- fetch_credential_from_env_var("SUBSCRIPTION")
  RESOURCE_GROUP <- fetch_credential_from_env_var("RESOURCE_GROUP")
  STORAGE_ACCOUNT <- fetch_credential_from_env_var("STORAGE_ACCOUNT")
  # nolint end: object_name_linter
  cli::cli_alert_success("Credentials loaded successfully")


  cli::cli_alert_info("Authenticating with loaded credentials")
  az <- AzureRMR::get_azure_login(TENANT_ID)
  subscription <- az$get_subscription(SUBSCRIPTION)
  resource_group <- subscription$get_resource_group(RESOURCE_GROUP)
  storage_account <- resource_group$get_storage_account(STORAGE_ACCOUNT)

  # Getting the access key
  keys <- storage_account$list_keys()
  access_key <- keys[["key1"]]

  endpoint <- AzureStor::blob_endpoint(
    storage_account$properties$primaryEndpoints$blob,
    key = access_key
  )

  container <- AzureStor::storage_container(endpoint, container_name)
  cli::cli_alert_success("Authenticated connection to {.var {container_name}}")

  return(container)
}

#' Fetch Azure credential from environment variable
#'
#' And throw an informative error if credential is not found
#'
#' @param env_var A character, the credential to fetch
#'
#' @return The associated value
#' @export
fetch_credential_from_env_var <- function(env_var) {
  credential <- Sys.getenv(env_var)

  if (credential == "") {
    cli::cli_abort(
      c(
        "Error loading Azure credentials from environment variables",
        "!" = "Environment variable {.envvar {env_var}} not specified or empty"
      ),
      class = "CFA_Rt",
      parent = con
    )
  }

  return(credential)
}
