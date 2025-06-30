test_that("Data read for one state works on happy path", {
  data_path <- test_path("data/test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  expected <- DBI::dbGetQuery(
    con,
    "
                         SELECT
                           report_date,
                           reference_date,
                           disease,
                           geo_value AS geo_value,
                           value AS confirm
                         FROM read_parquet(?)
                         WHERE reference_date <= '2023-01-22'",
    params = list(data_path)
  )
  DBI::dbDisconnect(con)

  actual <- read_data(
    data_path,
    disease = "test",
    geo_value = "test",
    report_date = "2023-10-28",
    min_reference_date = as.Date("2023-01-02"),
    max_reference_date = "2023-01-22"
  )

  expect_equal(actual, expected)
})

test_that("Data read for US overall works on happy path", {
  data_path <- test_path("data/us_overall_test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  expected <- DBI::dbGetQuery(
    con,
    "
                         SELECT
                           report_date,
                           reference_date,
                           disease,
                           geo_value AS geo_value,
                           value AS confirm
                         FROM read_parquet(?)
                         WHERE reference_date <= '2023-01-22'",
    params = list(data_path)
  )
  DBI::dbDisconnect(con)

  actual <- read_data(
    data_path,
    disease = "test",
    geo_value = "US",
    report_date = "2023-10-28",
    min_reference_date = "2023-01-02",
    max_reference_date = "2023-01-22"
  )

  expect_equal(actual, expected)
})

test_that("Reading a file that doesn't exist fails", {
  data_path <- "not_a_real_file"
  expect_error(
    read_data(
      data_path,
      disease = "test",
      geo_value = "not_a_real_state",
      report_date = "2023-10-28",
      min_reference_date = "2023-01-02",
      max_reference_date = "2023-01-22"
    ),
    class = "file_not_found"
  )
})

test_that("A query with no matching return fails", {
  data_path <- test_path("data/us_overall_test_data.parquet")
  expect_error(
    read_data(
      data_path,
      disease = "test",
      geo_value = "not_a_real_state",
      report_date = "2023-10-28",
      min_reference_date = "2023-01-02",
      max_reference_date = "2023-01-22"
    ),
    class = "empty_return"
  )
})

test_that("An invalid query throws a wrapped error", {
  # point the query at a non-parquet file
  data_path <- test_path("test-read_data.R")
  expect_error(
    read_data(
      data_path,
      disease = "test",
      geo_value = "not_a_real_state",
      report_date = "2023-10-28",
      min_reference_date = "2023-01-02",
      max_reference_date = "2023-01-22"
    ),
    class = "wrapped_schema_read_error"
  )
})

test_that("Incomplete return throws warning", {
  data_path <- test_path("data/test_data.parquet")

  # Two missing dates
  expect_snapshot_warning(
    read_data(
      data_path,
      disease = "test",
      geo_value = "test",
      report_date = "2023-10-28",
      min_reference_date = "2022-12-31",
      max_reference_date = "2023-01-22"
    ),
    class = "incomplete_return"
  )
})

test_that("Replace COVID-19/Omicron with COVID-19, one state", {
  data_path <- test_path("data/CA_test.parquet")

  actual <- read_data(
    data_path,
    disease = "COVID-19",
    geo_value = "CA",
    report_date = "2024-11-26",
    min_reference_date = as.Date("2024-06-01"),
    max_reference_date = "2024-11-25"
  )

  # Expect that there should be no "COVID-19/Omicron" in the data,
  # only "COVID-19"
  expect_false("COVID-19/Omicron" %in% actual$disease)
  expect_true(all(actual$disease == "COVID-19"))
})


test_that("Replace COVID-19/Omicron with COVID-19, US", {
  data_path <- test_path("data/CA_test.parquet")

  actual <- read_data(
    data_path,
    disease = "COVID-19",
    geo_value = "US",
    report_date = "2024-11-26",
    min_reference_date = as.Date("2024-06-01"),
    max_reference_date = "2024-11-25"
  )

  # Expect that there should be no "COVID-19/Omicron" in the data,
  # only "COVID-19"
  expect_false("COVID-19/Omicron" %in% actual$disease)
  expect_true(all(actual$disease == "COVID-19"))
})

test_that("API v2 with COVID-19, one state", {
  data_path <- test_path("data/CA_apiv2_test.parquet")

  actual <- read_data(
    data_path,
    disease = "COVID-19",
    geo_value = "CA",
    report_date = "2024-11-26",
    min_reference_date = as.Date("2024-06-01"),
    max_reference_date = "2024-11-25",
    facility_active_proportion = 1.0
  )

  # Expect that there should be no "COVID-19/Omicron" in the data,
  # only "COVID-19"
  expect_false("COVID-19/Omicron" %in% actual$disease)
  expect_true(all(actual$disease == "COVID-19"))
})


test_that("API v2 with COVID-19, US", {
  data_path <- test_path("data/CA_apiv2_test.parquet")

  actual <- read_data(
    data_path,
    disease = "COVID-19",
    geo_value = "US",
    report_date = "2024-11-26",
    min_reference_date = as.Date("2024-06-01"),
    max_reference_date = "2024-11-25",
    facility_active_proportion = 1.0
  )

  # Expect that there should be no "COVID-19/Omicron" in the data,
  # only "COVID-19"
  expect_false("COVID-19/Omicron" %in% actual$disease)
  expect_true(all(actual$disease == "COVID-19"))
})

test_that("facility_active_proportion affects counts", {
  data_path <- test_path("data/CA_apiv2_test.parquet")

  # Read data with facility_active_proportion = 1.0
  # (stricter - only facilities active all days)
  data_strict <- read_data(
    data_path,
    disease = "COVID-19",
    geo_value = "CA",
    report_date = "2024-11-26",
    min_reference_date = as.Date("2024-06-01"),
    max_reference_date = "2024-11-25",
    facility_active_proportion = 1.0
  )

  # Read data with facility_active_proportion = 0.5
  # (less strict - facilities active >=50% of days)
  data_lenient <- read_data(
    data_path,
    disease = "COVID-19",
    geo_value = "CA",
    report_date = "2024-11-26",
    min_reference_date = as.Date("2024-06-01"),
    max_reference_date = "2024-11-25",
    facility_active_proportion = 0.5
  )

  # Both should have the same structure
  expect_equal(names(data_strict), names(data_lenient))
  expect_equal(nrow(data_strict), nrow(data_lenient))

  expect_true(
    all(data_lenient$confirm >= data_strict$confirm),
    info = "Lenient data should have equal or more counts than strict data"
  )
})
