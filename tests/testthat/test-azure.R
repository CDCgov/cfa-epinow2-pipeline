# NOTE: these tests don't test the happy path because they don't interact with
# Azure resources and mocking a full Azure Blob interface is hard. Instead, they
# test that expected errors are thrown and that if Azure access is mocked, the
# core download function runs all the way through. The function
# `download_file_from_container` isn't tested because it's a simple wrapper
# around `AzureStor::download_blob()` and `testthat::with_mocked_bindings()`
# advises mocking wrappers for tests rather than injecting the mock into the
# external lib.
test_that("Downloading file smoke test", {
  file_path <- "not_a_real_file.ext"
  download_status <- testthat::with_mocked_bindings(
    {
      withr::with_tempdir({
        download_from_azure_blob(
          blob_names = c(file_path),
          local_dest = ".",
          container_name = "test_container"
        )
      })
    },
    fetch_blob_container = function(...) "test-container",
    download_file_from_container = function(...) file_path
  )

  expect_null(download_status)
})

test_that("Download fail throws informative error", {
  # Errors on fetching credentials
  expect_error(
    download_from_azure_blob(
      blob_names = c("test.json"),
      local_dest = "./",
      container_name = "test_container"
    )
  )

  # Credentials mocked, errors on downloading file
  testthat::with_mocked_bindings(
    {
      withr::with_tempdir({
        expect_error(
          download_from_azure_blob(
            blob_names = c("not_a_real_file.ext"),
            local_dest = ".",
            container_name = "test_container"
          )
        )
      })
    },
    fetch_blob_container = function(...) "test-container"
  )
})