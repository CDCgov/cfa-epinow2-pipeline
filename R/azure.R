#' Download if specified
#'
#' @param blob_path The name of the blob to download
#' @param blob_storage_container The name of the container to download from
#' @param dir The directory to which to write the downloaded file
#' @return The path of the file
#' @family azure
#' @export
download_if_specified <- function(
  blob_path,
  blob_storage_container,
  dir
) {
  # Guard against null input erroring out file.exists()
  if (rlang::is_null(blob_path)) {
    local_path <- NULL
  } else {
    file_exists <- file.exists(file.path(dir, blob_path))
    if (!rlang::is_null(blob_storage_container) && !file_exists) {
      container <- fetch_blob_container(blob_storage_container)
      local_path <- download_file_from_container(
        blob_storage_path = blob_path,
        local_file_path = file.path(dir, blob_path),
        storage_container = container
      )
    } else {
      local_path <- file.path(dir, blob_path)
    }
  }
  local_path
}

#' Download specified blobs from Blob Storage and save them in a local dir
#'
#' @param blob_storage_path A character of a blob in `storage_container`
#' @param local_file_path The local path to save the blob
#' @param storage_container The blob storage container with `blob_storage_path`
#
#' @return Invisibly, `local_file_path`
#' @family azure
#' @export
download_file_from_container <- function(
  blob_storage_path,
  local_file_path,
  storage_container
) {
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

#' Authenticate with Azure Blob Storage using managed identity
#'
#' @return An authenticated storage endpoint for the Azure Blob Storage account.
#' @autoglobal
#' @export
authenticate_blob <- function() {
  account_url <- "https://cfaazurebatchprd.blob.core.windows.net/"
  # AzureAuth::get_managed_token does not work in Container Apps: https://github.com/Azure/AzureAuth/issues/75
  # token <- AzureAuth::get_managed_token(resource = "https://storage.azure.com/")
  aad_host <- Sys.getenv(
    "IDENTITY_ENDPOINT",
    "http://169.254.169.254/metadata/identity/oauth2/token"
  )

  # Check if using a user-assigned identity
  client_id <- Sys.getenv("AZURE_CLIENT_ID", unset = NA)

  query_params <- list(
    resource = "https://storage.azure.com/",
    "api-version" = "2019-08-01"
  )

  # Only add client_id if present
  if (!is.na(client_id) && nchar(client_id) > 0) {
    query_params$client_id <- client_id
  }

  response <- httr::GET(
    url = aad_host,
    query = query_params,
    httr::add_headers(
      Metadata = "true",
      "X-IDENTITY-HEADER" = Sys.getenv("IDENTITY_HEADER")
    )
  )

  if (httr::status_code(response) == 200) {
    token <- httr::content(
      response,
      as = "parsed",
      type = "application/json"
    )$access_token
  } else {
    stop("Failed to retrieve token: ", httr::content(response, as = "text"))
  }
  return(AzureStor::storage_endpoint(account_url, token = token))
}

#' Load Azure Blob container using credentials in environment variables
#'
#' This function depends on the following Azure credentials stored in
#' environment variables:
#'
#' * `az_tenant_id`: an Azure Active Directory (AAD) tenant ID
#' * `az_subscription_id`: an Azure subscription ID
#' * `az_resource_group`: The name of the Azure resource group
#' * `az_storage_account`: The name of the Azure storage account
#'
#' As a result it is an impure function, and should be used bearing that
#' warning in mind. Each variable is obtained using
#' [fetch_credential_from_env_var()] (which will return an error if the
#' credential is not specified or empty).
#'
#' @param container_name The Azure Blob Storage container associated with the
#'   credentials
#' @return A Blob endpoint
#' @family azure
#' @export
fetch_blob_container <- function(container_name) {
  cli::cli_alert_info(
    "Attempting to connect to container {.var {container_name}}"
  )
  rlang::try_fetch(
    {
      container <- AzureStor::blob_container(
        authenticate_blob(),
        container_name
      )
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
