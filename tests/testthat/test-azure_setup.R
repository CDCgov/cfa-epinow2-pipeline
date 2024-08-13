## Test required_credentials() -------------------------------------------------
test_that("az_required_credentials() returns known good values", {
  expect_identical(
    az_required_credentials(),
      c("az_client_id", "az_tenant_id", "az_subscription",
      "az_resource_group", "az_storage_account", "az_token")
  )
})

good_cred_list <- list(
  "az_client_id" = "aaaa",
  "az_tenant_id" = "bananna",
  "az_subscription" = "10",
  "az_resource_group" = "blahblah",
  "az_storage_account" = "some-account",
  "az_token" = "xxx-xx"
)

## Test az_set_env_credentials() -----------------------------------------------
test_that("Credentials set as env vars from list", {

  ## Check that env vars are empty before acting
  expect_error(az_get_env_credentials())

  ## Test passing a list to set env vars
  az_set_env_credentials(cred_list = good_cred_list)
  expect_silent(az_get_env_credentials())
  Sys.unsetenv(az_required_credentials()) # cleanup
})

test_that("Credentials set as env vars from variable", {
  ## Test passing individual vars
  az_set_env_credentials(
    az_client_id = good_cred_list$az_client_id,
    az_tenant_id = good_cred_list$az_tenant_id,
    az_subscription_id = good_cred_list$az_subscription_id,
    az_resource_group = good_cred_list$az_resource_group,
    az_storage_account = good_cred_list$az_storage_account,
    az_token = good_cred_list$az_token
    )
  expect_silent(az_get_env_credentials()) # No error if env vars were set
  Sys.unsetenv(az_required_credentials()) # cleanup
  })

test_that("Invalid inputs fail", {

  # Non-character
  expect_error(az_set_env_credentials(az_client_id = 10))
  # length > 1
  expect_error(az_set_env_credentials(az_token = c("a", "cat")))
  # No input
  expect_error(az_set_env_credentials())
  # Invalid name
  expect_error(az_set_env_credentials(cred_list = list("potato" = "xx")))
  # Repeated name in list and inputs
  expect_error(az_set_env_credentials(
    az_client_id = "xx", 
    cred_list = good_cred_list)
    )

})


## Test fetch_env_credential() -------------------------------------------------
test_that("Credential fetched successfully from env var", {
  withr::with_envvar(c("KEY" = "VALUE"), {
    expect_equal(fetch_env_credential("KEY"), "VALUE")
  })
})

test_that("Missing credential fails", {
  withr::with_envvar(c("MISSING_KEY" = ""), {
    expect_error(fetch_env_credential("MISSING_KEY"))
  })
  expect_error(fetch_env_credential("NOT_A_REAL_KEY"))
})

## Test_az_get_env_credentials

## Test az_validate_credlist() -------------------------------------------------
test_that("List of non-empty strings with expected names passes", {
  expect_silent(
    az_validate_credlist(good_cred_list)
  )
})

test_that("Non-character element raises error", {
  bad_list <- list(
    "az_client_id" = "aaaa",
    "az_tenant_id" = "bananna",
    "az_subscription" = 10,
    "az_resource_group" = "blahblah",
    "az_storage_account" = "some-account",
    "az_token" = "xxx-xx"
  )
    expect_error(az_validate_credlist(bad_list))
})

test_that("Empty element raises error", {
  bad_list <- list(
    "az_client_id" = "aaaa", 
    "az_tenant_id" = "bananna", 
    "az_subscription" = "", 
    "az_resource_group" = "blahblah", 
    "az_storage_account" = "some-account", 
    "az_token" = "xxx-xx"
  )
    expect_error(az_validate_credlist(bad_list))
})

test_that("All list elements are length one", {
  bad_list <- list(
    "az_client_id" = "aaaa", 
    "az_tenant_id" = c("bananna", "apple"), 
    "az_subscription" = c("10", 10, TRUE), 
    "az_resource_group" = "blahblah", 
    "az_storage_account" = "some-account", 
    "az_token" = "xxx-xx"  
  )
    expect_error(az_validate_credlist(bad_list))
})

