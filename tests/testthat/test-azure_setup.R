## Test required_credentials() -------------------------------------------------
test_that("required_credentials() returns known good values", {
    expect_identical(
        required_credentials(),
        c("az_client_id", "az_tenant_id", "az_subscription", 
        "az_resource_group", "az_storage_account", "az_token" )
    )
})


## Test set_env_credentials() --------------------------------------------------
test_that("Credentials set as env vars", {
  # Test that credentials are set as env vars successfully when passing in 
  # individual var names or a list 
})

test_that("Invalid inputs fail", {

})

test_that("Missing Credential returns a warning", {
    
})

## Test validate_credlist() ----------------------------------------------------
test_that("List of non-empty strings with expected names passes", {
    good_list <- list(
        "az_client_id" = "aaaa", 
        "az_tenant_id" = "bananna", 
        "az_subscription" = "10", 
        "az_resource_group" = "blahblah", 
        "az_storage_account" = "some-account", 
        "az_token" = "xxx-xx"
    )
    expect_silent(
        validate_credlist(good_list)
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
    expect_error(validate_credlist(bad_list))
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
    expect_error(validate_credlist(bad_list))
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
    expect_error(validate_credlist(bad_list))
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