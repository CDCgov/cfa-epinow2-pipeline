## Functions to connect to azure storage resources
##
## Several steps needs to happen in order to connect to an azure blob
## endpoint.
## This script defines a lightweight wrapper around AzureRMR
## for each step, then chains the steps together. Because each function in the
## heierarchy includes validation, the code will stop and throw an informative
## error if any step in the sequence fails.
##
## The steps are:
## 0.1 Set credentials as env vars
## 0.2 Get credentials as list from env or pass as a list
## 1. Validate credentials
## 2. Create az_login object and validate
## 3. Get subscription id from az_login and validate
## 4. Get resource group from subscription and validate
## 5. Get storage account from resource gorup and validate
## 6. Get access key from storage account and validate
## 7. Get azure endpoint (using access key) and validate
## 8. Get azure container object (using endpoint) and validate
## Only {0, 2, 7, 8} are exported



## 0. Set and get crednetials from env  ----------------------------------

#' @value a character vector containing all required credentials
#'
#' @details used to view required credentials and internally to ensure the set
#' of required credentials is consistent in downstream functions
#' @export
az_required_credentials <- function() {
  c(
    "az_client_id", "az_tenant_id", "az_subscription", "az_resource_group",
    "az_storage_account", "az_token"
  )
}

#' Set Azure credentials and env vars
#'
#' @param az_client_id, az_tenant_id, az_subscriptoin, az_resource_group,
#' az_storage_account, az_token strings containing the relevant Azure credential
#' The function will create an env var with the same name. One or more non-NULL
#' input is required.
#'
#' @details This is a thin wrappper around [Sys.setenv].
#' @export
az_set_env_credentials <- function(
    az_client_id = NULL,
    az_tenant_id = NULL,
    az_subscription = NULL,
    az_resource_group = NULL,
    az_storage_account = NULL,
    az_token = NULL,
    cred_list = NULL) {
  # Check that no input has length > 1
  inputs <- c(
    "az_client_id" = az_client_id,
    "az_tenant_id" = az_tenant_id,
    "az_subscription" = az_subscription,
    "az_resource_group" = az_resource_group,
    "az_storage_account" = az_storage_account,
    "az_token" = az_token
  )

  if (length(inputs) == 0 & length(cred_list) == 0) {
    cli::cli_abort("Must input at least one non-null value")
  }

  length_gt_1 <- sapply(inputs, function(x) {
    !length(x) > 1
  })
  if (any(length_gt_1)) {
    bad_inputs <- names(inputs)[length_gt_1]
    cli::cli_abort("input {bad_inputs} must be length one")
  }

  ## Only non-null values kept when null values are set in a vector
  inputs <- c(
    inputs,
    unlist(cred_list)
  )

  if (any(duplicated(names(inputs)))) {
    dup_name <- names(inputs)[duplicated(names(inputs))]
    cli::cli_abort("Input {.field {dup_name}} is duplicated")
  }

  if (!all(names(inputs) %in% az_required_credentials())) {
    bad_names <- names(inputs)[!names(inputs) %in% az_required_credentials()]
    cli::cli_abort(
      c(
        "!" = "Valid credential names are: {.field {az_required_credentials()}}",
        "i" = "You input these invalid names: {.field {bad_names}}"
      )
    )
  }

  if (!all(is.character(inputs))) {
    cli::cli_abort("Credential values must all be strings")
  }
  if (any(inputs == "")) {
    cli::cli_abort("Credential values must be non-empty. You input `` at least once.")
  }
  ## Set env vars
  for (vv in 1:length(inputs)) {
    cli::cli_alert_info("Setting env var {.envvar {names(inputs[vv])}} = {.envvar {inputs[vv]}}")
  }
  do.call(Sys.setenv, as.list(inputs))
}

#' Internal function: fetch one Azure credential from environment variable
#' and throw an informative error if credential is not found
#'
#' @param env_var A character vector, the credential(s) to fetch
#'
#' @return The value stored as the environment variable "env_var" if it exists
fetch_env_credential <- function(env_var) {
  credentials <- Sys.getenv(env_var)

  if (any(credentials == "")) {
    missing_creds <- credentials[credentials == ""]
    cli::cli_abort(
      c(
        "Error loading Azure credentials from environment variables",
        "!" = "Environment variable {.envvar {names(missing_creds)}} not
        specified or empty",
        "i" = "See {.fn crazuR::az_set_env_credentials} for help setting
        credentials"
      ),
      class = "CFA_Rt"
    )
  }

  return(credential)
}

#' Fetch Azure credentials stored as environmental variables, if they exist
#'
#' @value A list containing all required credentials: "az_tenant_id",
#' "az_subscription", "az_resource_group", "az_storage_account", and "az_token",
#' or an informative error if any are missing
#'
#' @details See []() for help finding and specifying Azure credntials.
#' @export
az_get_env_credentials <- function() {
  fetch_env_credential(az_required_credentials()) |> as.list()
}


## 1. Validate credentials -----------------------------------------------------

#' Checks that a list of credentials contains all expected credentials
#'
#' @param cred_list a named list of credentials. Names must match the set of
#' required credentials returned by [az_required_credentials()]. All values must
#' be non-empty strings.
#'
#' @details Checks that credentials exist, but does not connect to Azure to
#' check that the credentials are valid
#' @export
az_validate_credlist <- function(cred_list) {
  ## Check that is list
  if (!is.list(cred_list)) {
    cli::cli_abort("!" = "Input `cred_list` must be a list.")
  }
  ## Check that list naems include all required credentials
  cred_in_list <- (az_required_credentials() %in% names(cred_list)) |>
    set_names(az_required_credentials())
  missing_creds <- az_required_credentials()[!cred_in_list]
  if (!all(cred_in_list)) {
    cli::cli_abort(
      c(
        "!" = "Credential names must include:{.field {az_required_credentials()}}",
        "i" = "{.field {missing_creds}} are missing from {.field cred_list}"
      )
    )
  }
  element_length <- sapply(cred_list, length)
  bad_inputs <- cred_list[element_length > 1]
  if (!all(element_length == 1)) {
    cli::cli_abort(
      c(
        "!" = "Each credential value must be a single nonempty string.",
        "i" = "You input these values with length > 1:
        {.field {names(bad_inputs)}} with values {.field {bad_inputs}}."
      )
    )
  }
  is_nonempty_character <- lapply(cred_list, function(x) {
    is.character(x) & (x != "")
  }) |> unlist()
  bad_inputs <- cred_list[!is_nonempty_character]
  if (!all(is_nonempty_character)) {
    cli::cli_abort(
      c(
        "!" = "Each credential value must be a single nonempty string.",
        "i" = "You input these bad credentials: {.field {names(bad_inputs)}}
        with values {.field {bad_inputs}}."
      )
    )
  }
}
