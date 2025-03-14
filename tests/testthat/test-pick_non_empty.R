test_that("Error on different values", {
  # Create a config object from test config
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config <- read_json_into_config(
    config_path, c("exclusions", "output_container")
  )
  # Give the output container a value
  config@output_container <- "test1"

  # The function arg is different
  output_container <- "test2"

  # Act
  expect_error(
    pick_non_empty(output_container, config),
    "Output container in config file"
  )
})

test_that("Fine if both have the same value", {
  # Create a config object from test config
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config <- read_json_into_config(
    config_path, c("exclusions", "output_container")
  )
  # Give the output container a value
  config@output_container <- "test1"

  # The function arg is the same
  output_container <- "test1"

  # Act
  expect_equal(
    pick_non_empty(output_container, config),
    config
  )
})

test_that("No change if both empty", {
  # Create a config object from test config
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config <- read_json_into_config(
    config_path, c("exclusions", "output_container")
  )
  # Give the output container a value
  config@output_container <- NULL

  # The function arg is empty
  output_container <- NULL

  # Act
  expect_equal(
    pick_non_empty(output_container, config),
    config
  )
})

test_that("Filled with non-empty function arg, empty config val", {
  # Create a config object from test config
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config <- read_json_into_config(
    config_path, c("exclusions", "output_container")
  )
  # Give the output container a value
  config@output_container <- NULL

  # The function arg is non-empty
  output_container <- "test1"

  # Act
  expect_equal(
    pick_non_empty(output_container, config)@output_container,
    output_container
  )
})

test_that("Filled with non-empty config val, empty function arg", {
  # Create a config object from test config
  config_path <- test_path("data", "sample_config_no_exclusion.json")
  config <- read_json_into_config(
    config_path, c("exclusions", "output_container")
  )
  # Give the output container a value
  config@output_container <- "test1"

  # The function arg is empty
  output_container <- NULL

  # Act
  expect_equal(
    pick_non_empty(output_container, config)@output_container,
    config@output_container
  )
})
