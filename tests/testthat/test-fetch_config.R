test_that("Test config loads", {
  config_path <- test_path("data/sample_config.json")

  expected <- jsonlite::read_json(config_path)
  actual <- fetch_config(
    config_path = config_path,
    local_dest = NULL,
    blob_storage_container = NULL
  )

  expect_equal(actual, expected)
})

test_that("Bad config errors", {
  config_path <- test_path("data/bad_sample_config.json")

  expect_error(
    {
      fetch_config(
        config_path = config_path,
        local_dest = NULL,
        blob_storage_container = NULL
      )
    },
    class = "CFA_Rt"
  )
})

test_that("Test config validates", {
  config_path <- test_path("data/sample_config.json")

  expect_true(
    validate_config(
      config_path
    )
  )
})


test_that("Bad config errors", {
  config_path <- test_path("data/bad_sample_config.json")

  expect_error(validate_config(config_path))
})
