test_that("Can apply exclusions on happy path", {
  exclusions <- data.frame(
    reference_date = as.Date("2023-01-06"),
    report_date = as.Date("2023-10-28"),
    geo_value = "test",
    disease = "test"
  )
  data_path <- test_path("data", "test_data.parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  data <- DBI::dbGetQuery(
    con,
    "
                         SELECT
                           report_date,
                           reference_date,
                           disease,
                           geo_value,
                           value AS confirm
                         FROM read_parquet(?)",
    params = list(data_path)
  )
  DBI::dbDisconnect(con)

  # Apply exclusion by hand
  expected <- data
  expected[
    expected[["reference_date"]] == "2023-01-06",
  ][["confirm"]] <- NA

  # Act
  actual <- apply_exclusions(
    cases = data,
    exclusions = exclusions
  )

  expect_equal(actual, expected)
})

test_that("Can read exclusions on happy path", {
  expected <- data.frame(
    reference_date = as.Date("2023-01-01"),
    report_date = as.Date("2023-01-02"),
    geo_value = "test",
    disease = "test"
  )

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con))
  duckdb::duckdb_register(con, "exclusions", expected)

  withr::with_tempdir({
    DBI::dbExecute(
      con,
      "
    COPY (
      SELECT
        reference_date,
        report_date,
        geo_value AS state,
        disease
       FROM exclusions
     ) TO 'test.csv'"
    )

    actual <- read_exclusions("test.csv")
  })

  expect_equal(actual, expected)
})

test_that("Empty read errors", {
  expected <- data.frame(
    reference_date = character(),
    report_date = character(),
    state = character(),
    disease = character()
  )

  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con))
  duckdb::duckdb_register(con, "exclusions", expected)

  withr::with_tempdir({
    DBI::dbExecute(con, "COPY (FROM exclusions) TO 'test.csv'")

    expect_error(read_exclusions("test.csv"), class = "empty_return")
  })
})

test_that("Missing file errors", {
  expect_error(
    read_exclusions(path = "not_a_real_path"),
    class = "file_not_found"
  )
})

test_that("Bad query errors", {
  expect_error(
    read_exclusions(path = "test-exclusions.R"),
    class = "wrapped_invalid_query"
  )
})

test_that("Works as expected on large exclusions file", {
  # Read in the large exclusions file
  excl_path <- test_path("data", "test_big_exclusions.csv")
  exclusions <- read_exclusions(excl_path)

  # Load some sample case data
  data_path <- test_path("data", "2025-04-02_test.parquet")
  cases <- read_data(
    data_path,
    disease = "COVID-19",
    geo_value = "OH",
    report_date = "2025-04-02",
    max_reference_date = "2025-04-02",
    min_reference_date = "1970-01-01",
    facility_active_proportion = 1.0
  )

  # Apply the exclusions
  got <- apply_exclusions(cases, exclusions)

  # Check that the exclusions were applied as expected
  expect_equal(
    got$confirm[179:181],
    c(54, NA, NA)
  )
})
