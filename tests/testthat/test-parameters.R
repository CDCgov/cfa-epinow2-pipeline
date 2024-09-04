test_that("Can read all params on happy path", {
  expected <- c(0.8, 0.2)
  start_date <- as.Date("2023-01-01")
  disease <- "COVID-19"

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      parameter = "generation_interval",
      path = "generation_interval.parquet",
      disease = disease,
      state = NA,
      start_date = start_date,
      end_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "delay",
      path = "delay_interval.parquet",
      disease = disease,
      state = NA,
      start_date = start_date,
      end_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "right_truncation",
      path = "right_truncation.parquet",
      disease = disease,
      state = "test",
      start_date = start_date,
      end_date = NA
    )


    actual <- read_disease_parameters(
      generation_interval_path = "generation_interval.parquet",
      delay_interval_path = "delay_interval.parquet",
      right_truncation_path = "right_truncation.parquet",
      disease = "COVID-19",
      as_of_date = start_date + 1,
      group = "test"
    )
  })


  expect_equal(
    actual,
    list(
      generation_interval = expected,
      delay_interval = expected,
      right_truncation = expected
    )
  )
})

test_that("Can skip params on happy path", {
  expected <- c(0.8, 0.2)
  start_date <- as.Date("2023-01-01")
  disease <- "COVID-19"

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      parameter = "generation_interval",
      path = "generation_interval.parquet",
      disease = disease,
      state = NA,
      start_date = start_date,
      end_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "delay",
      path = "delay_interval.parquet",
      disease = disease,
      state = NA,
      start_date = start_date,
      end_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "right_truncation",
      path = "right_truncation.parquet",
      disease = disease,
      state = "test",
      start_date = start_date,
      end_date = NA
    )


    actual <- read_disease_parameters(
      generation_interval_path = "generation_interval.parquet",
      delay_interval_path = NULL,
      right_truncation_path = NULL,
      disease = "COVID-19",
      as_of_date = start_date + 1,
      group = "test"
    )
  })


  expect_equal(
    actual,
    list(
      generation_interval = expected,
      delay_interval = NA,
      right_truncation = NA
    )
  )
})

test_that("Can read right-truncation on happy path", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "right_truncation"
  start_date <- as.Date("2023-01-01")

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = "test",
      disease = disease,
      parameter = parameter,
      start_date = start_date,
      end_date = NA
    )
    actual <- read_interval_pmf(
      path = path,
      parameter = parameter,
      disease = disease,
      as_of_date = start_date + 1,
      group = "test"
    )
  })
  expect_equal(actual, expected)


  # Influenza
  disease <- "Influenza"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = "test",
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )
    actual <- read_interval_pmf(
      path = path,
      parameter = parameter,
      disease = disease,
      as_of_date = start_date + 1,
      group = "test"
    )
  })
  expect_equal(actual, expected)
})

test_that("Invalid PMF errors", {
  expected <- c(0.8, -0.1)
  path <- "test.parquet"
  parameter <- "right_truncation"
  start_date <- as.Date("2023-01-01")

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = "test",
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )
    expect_error(
      read_interval_pmf(
        path = path,
        parameter = parameter,
        disease = disease,
        as_of_date = start_date + 1,
        group = "test"
      ),
      class = "invalid_pmf"
    )
  })
})


test_that("Can read delay on happy path", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = NA,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )
    actual <- read_interval_pmf(
      path = path,
      disease = disease,
      as_of_date = start_date + 1,
      parameter = parameter
    )
  })
  expect_equal(actual, expected)


  # Influenza
  disease <- "Influenza"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = NA,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )
    actual <- read_interval_pmf(
      path = path,
      disease = disease,
      as_of_date = start_date + 1,
      parameter = parameter
    )
  })
  expect_equal(actual, expected)
})


test_that("Not a PMF errors", {
  expected <- "hello"
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = NA,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )
    expect_error(
      read_interval_pmf(
        path = path,
        disease = disease,
        as_of_date = start_date + 1,
        parameter = parameter
      ),
      class = "not_a_pmf"
    )
  })
})

test_that("Invalid disease errors", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")
  disease <- "not_a_valid_disease"

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = "test",
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )

    expect_error(
      read_interval_pmf(
        path = path,
        disease = disease,
        as_of_date = start_date + 1,
        parameter = parameter
      ),
      regexp = "`disease` must be one of"
    )
  })
})

test_that("Invalid parameter errors", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "not_a_valid_parameter"
  start_date <- as.Date("2023-01-01")
  disease <- "COVID-19"

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = "test",
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )

    expect_error(
      read_interval_pmf(
        path = path,
        disease = disease,
        as_of_date = start_date + 1,
        parameter = parameter
      ),
      regexp = "`parameter` must be one of"
    )
  })
})

test_that("Return isn't exactly one errors", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")
  disease <- "COVID-19"

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = "test",
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )

    # Date too early
    expect_error(
      read_interval_pmf(
        path = path,
        disease = disease,
        as_of_date = start_date - 1,
        parameter = parameter
      ),
      class = "not_one_row_returned"
    )
  })
})

test_that("No file exists errors", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")
  disease <- "COVID-19"

  expect_error(
    read_interval_pmf(
      path = "not_a_real_file",
      disease = disease,
      as_of_date = start_date - 1,
      parameter = parameter
    ),
    class = "file_not_found"
  )
})

test_that("Invalid query throws wrapped error", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")
  disease <- "COVID-19"

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      state = NA,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA
    )

    expect_error(
      read_interval_pmf(
        path = path,
        disease = disease,
        as_of_date = "abc123",
        parameter = parameter
      ),
      class = "wrapped_error"
    )
  })
})
