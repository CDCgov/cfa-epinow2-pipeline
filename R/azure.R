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
#' @family azure
#' @export
download_from_azure_blob <- function(blob_names, local_dest, container_name) {
  # Attempt to connect to the storage container
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

  # Attempt to save each blob into local storage
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

  rlang::try_fetch(
    {
      dirs <- dirname(local_file_path)

      if (!dir.exists(dirs)) {
        cli::cli_alert("Creating directory {.path {dirs}}")
        dir.create(dirs, recursive = TRUE)
      }

      AzureStor::download_blob(
        container = container,
        src = blob_storage_path,
        dest = local_file_path,
        overwrite = TRUE
      )
    },
    error = function(cnd) {
      cli::cli_abort(c(
        "Failed to download {.path {blob_storage_path}}",
        ">" = "Does the blob exist in the container?"
      ))
    }
  )

  cli::cli_alert_success(
    "Blob {.path {blob_storage_path}} downloaded successfully"
  )

  invisible(local_file_path)
}

#' Load Azure Blob container using credentials in environment variables
#'
#' This **impure** function depends on the environment variables:
#' * az_tenant_id
#' * az_subscription_id
#' * az_resource_group
#' * az_storage_account
#'
#' It will error out if any of the above is not set.
#' @param container_name The Azure Blob Storage container associated with the
#'   credentials
#' @return A Blob endpoint
#' @family azure
#' @export
fetch_blob_container <- function(container_name) {
  cli::cli_alert_info(
    "Attempting to connect to container {.var {container_name}}"
  )
  cli::cli_alert_info("Loading Azure credentials from env vars")
  # nolint start: object_name_linter
  az_tenant_id <- fetch_credential_from_env_var("az_tenant_id")
  az_client_id <- fetch_credential_from_env_var("az_client_id")
  az_service_principal <- fetch_credential_from_env_var("az_service_principal")
  # nolint end: object_name_linter
  cli::cli_alert_success("Credentials loaded successfully")


  cli::cli_alert_info("Authenticating with loaded credentials")
  rlang::try_fetch(
    {
      token <- AzureRMR::get_azure_token(
        resource = "https://storage.azure.com",
        tenant = az_tenant_id,
        app = az_client_id,
        password = az_service_principal
      )
      endpoint <- storage_endpoint(
        "https://cfaazurebatchprd.blob.core.windows.net",
        token = token
      )

      container <- AzureStor::storage_container(endpoint, container_name)
    },
    error = function(cnd) {
      cli::cli_abort(
        "Failure authenticating connection to {.var {container_name}}",
        parent = cnd
      )
    }
  )

  cli::cli_alert_success("Authenticated connection to {.var {container_name}}")

  return(container)
}

#' Fetch Azure token

#' Fetch Azure credential from environment variable
#'
#' And throw an informative error if credential is not found
#'
#' @param env_var A character, the credential to fetch
#'
#' @return The associated value
#' @family azure
#' @export
fetch_credential_from_env_var <- function(env_var) {
  credential <- Sys.getenv(env_var)

  if (credential == "") {
    cli::cli_abort(
      c(
        "Error loading Azure credentials from environment variables",
        "!" = "Environment variable {.envvar {env_var}} not specified or empty"
      ),
      class = "CFA_Rt"
    )
  }

  return(credential)
}
