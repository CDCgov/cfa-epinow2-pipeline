#' Download if specified
download_if_specified <- function(
    blob_path,
    blob_storage_container,
    output_dir) {
  if (!rlang::is_null(blob_storage_container)) {
    container <- fetch_blob_container(blob_storage_container)
    local_path <- download_file_from_container(
      blob_storage_path = blob_path,
      local_file_path = file.path(output_dir, blob_path),
      storage_container = container
    )
  } else {
    local_path <- file.path(output_dir, blob_path)
  }
  local_path
}

#' Download specified blobs from Blob Storage and save them in a local dir
#'
#' @param blob_names A vector of blobs to donwload from `container_name`
#' @param local_dest The path to the local directory to save the files in
#' @param container_name The Azure Blob Storage container with `blob_names`
#'
#' @return Invisibly, `local_file_path`
#' @family azure
#' @export
download_file_from_container <- function(
    blob_storage_path,
    local_file_path,
    storage_container) {
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
        container = storage_container,
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
      # First, get a general-purpose token using SP flow
      # Analogous to:
      # az login --service-principal \
      #    --username $az_client_id \
      #    --password $az_service_principal \
      #    --tenant $az_tenant_id
      # NOTE: the SP is also sometimes called the `client_secret`
      token <- AzureRMR::get_azure_token(
        resource = "https://storage.azure.com",
        tenant = az_tenant_id,
        app = az_client_id,
        password = az_service_principal
      )
      # Then fetch a storage endpoint using the token. Follows flow from
      # https://github.com/Azure/AzureStor.
      # Note that we're using the ABS endpoint (the first example line)
      # but following the AAD token flow from the AAD alternative at
      # end of the box. If we didn't replace the endpoint and used the
      # example flow then it allows authentication to blob but throws
      # a 409 when trying to download.
      endpoint <- AzureStor::storage_endpoint(
        "https://cfaazurebatchprd.blob.core.windows.net",
        token = token
      )

      # Finally, set up instantiation of storage container generic
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
