test_that("Can read all params on happy path", {
  expected <- c(0.8, 0.2)
  start_date <- as.Date("2023-01-01")
  reference_date <- as.Date("2022-12-01")
  disease <- "COVID-19"
  group <- "test_geo"

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      parameter = "generation_interval",
      path = "generation_interval.parquet",
      disease = disease,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "delay",
      path = "delay_interval.parquet",
      disease = disease,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "right_truncation",
      path = "right_truncation.parquet",
      disease = disease,
      start_date = start_date,
      end_date = NA,
      geo_value = group,
      reference_date = reference_date
    )


    actual <- read_disease_parameters(
      generation_interval_path = "generation_interval.parquet",
      delay_interval_path = "delay_interval.parquet",
      right_truncation_path = "right_truncation.parquet",
      disease = "COVID-19",
      as_of_date = start_date + 1,
      group = group,
      report_date = reference_date
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
  reference_date <- as.Date("2022-12-01")

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      parameter = "generation_interval",
      path = "generation_interval.parquet",
      disease = disease,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "delay",
      path = "delay_interval.parquet",
      disease = disease,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = NA
    )
    write_sample_parameters_file(
      value = expected,
      parameter = "right_truncation",
      path = "right_truncation.parquet",
      disease = disease,
      start_date = start_date,
      end_date = NA,
      geo_value = "test_geo",
      reference_date = reference_date
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
  reference_date <- as.Date("2022-12-01")

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = "test",
      reference_date = reference_date
    )
    actual <- read_interval_pmf(
      path = path,
      parameter = parameter,
      disease = disease,
      as_of_date = start_date + 1,
      group = "test",
      report_date = reference_date
    )
  })
  expect_equal(actual, expected)


  # Influenza
  disease <- "Influenza"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = "test",
      reference_date = reference_date
    )
    actual <- read_interval_pmf(
      path = path,
      parameter = parameter,
      disease = disease,
      as_of_date = start_date + 1,
      group = "test",
      report_date = reference_date
    )
  })
  expect_equal(actual, expected)
})

test_that("Can read right-truncation with no geo_value", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "right_truncation"
  start_date <- as.Date("2023-01-01")
  reference_date <- as.Date("2022-12-01")

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
    )
    actual <- read_interval_pmf(
      path = path,
      parameter = parameter,
      disease = disease,
      as_of_date = start_date + 1,
      group = NA,
      report_date = reference_date
    )
  })
  expect_equal(actual, expected)
})

test_that("Invalid PMF errors", {
  expected <- c(0.8, -0.1)
  path <- "test.parquet"
  parameter <- "right_truncation"
  start_date <- as.Date("2023-01-01")
  reference_date <- as.Date("2022-12-01")

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      geo_value = "test",
      end_date = NA,
      reference_date = reference_date
    )
    expect_error(
      read_interval_pmf(
        path = path,
        parameter = parameter,
        disease = disease,
        as_of_date = start_date + 1,
        group = "test",
        report_date = reference_date
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
  reference_date <- NA

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
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
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
    )
    actual <- read_interval_pmf(
      path = path,
      disease = disease,
      as_of_date = start_date + 1,
      parameter = parameter,
      report_date = reference_date
    )
  })
  expect_equal(actual, expected)
})


test_that("Not a PMF errors", {
  expected <- "hello"
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")
  reference_date <- NA

  # COVID-19
  disease <- "COVID-19"
  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
    )
    expect_error(
      read_interval_pmf(
        path = path,
        disease = disease,
        as_of_date = start_date + 1,
        parameter = parameter,
        group = NA
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
  reference_date <- NA

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
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
  reference_date <- NA

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
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
  reference_date <- NA

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
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
  reference_date <- NA

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
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

test_that("NULL `reference_date` prints in output", {
  pmf_df <- data.frame(
    value = I(list(c(0.8, 0.1, 0.1))),
    reference_date = NA
  )
  parameter <- "right_truncation"
  disease <- "test_disease"
  as_of_date <- as.Date("2023-01-01")
  group <- "test_group"
  report_date <- as.Date("2023-01-15")
  path <- "test/path/to/file.ext"

  expect_snapshot(
    pmf <- check_returned_pmf(
      pmf_df = pmf_df,
      parameter = parameter,
      disease = disease,
      as_of_date = as_of_date,
      group = group,
      report_date = report_date,
      path = path
    )
  )
  expect_equal(pmf, pmf_df[["value"]][[1]])
})

test_that("Same-day parameter can be read", {
  expected <- c(0.8, 0.2)
  path <- "test.parquet"
  parameter <- "delay"
  start_date <- as.Date("2023-01-01")
  disease <- "COVID-19"
  reference_date <- NA

  withr::with_tempdir({
    write_sample_parameters_file(
      value = expected,
      path = path,
      disease = disease,
      parameter = parameter,
      param = parameter,
      start_date = start_date,
      end_date = NA,
      geo_value = NA,
      reference_date = reference_date
    )

    actual <- read_interval_pmf(
      path = path,
      disease = disease,
      as_of_date = start_date,
      parameter = parameter
    )

    expect_equal(actual, expected)
  })
})

test_that("GI with nonzero first element throws warning", {
  pmf <- sir_gt_pmf[2:length(sir_gt_pmf)]
  expect_snapshot(
    fixed <- format_generation_interval(pmf)
  )
  expect_equal(
    fixed,
    EpiNow2::generation_time_opts(
      dist = EpiNow2::NonParametric(pmf = sir_gt_pmf)
    )
  )
})
