test_that("Exclusions class can be constructed and properties set", {
  excl <- Exclusions(path = "foo.csv", blob_storage_container = "bar")
  expect_s3_class(excl, "Exclusions")
  expect_equal(S7::prop(excl, "path"), "foo.csv")
  expect_equal(S7::prop(excl, "blob_storage_container"), "bar")
})

test_that("Interval and subclasses can be constructed", {
  intv <- Interval(path = "int.csv", blob_storage_container = NULL)
  expect_s3_class(intv, "Interval")
  gen <- GenerationInterval(path = "gen.csv", blob_storage_container = "cont")
  expect_s3_class(gen, "GenerationInterval")
  del <- DelayInterval(path = "del.csv", blob_storage_container = NULL)
  expect_s3_class(del, "DelayInterval")
  rt <- RightTruncation(path = "rt.csv", blob_storage_container = NULL)
  expect_s3_class(rt, "RightTruncation")
})

test_that("Parameters class can be constructed", {
  gen <- GenerationInterval(path = "g.csv", blob_storage_container = NULL)
  del <- DelayInterval(path = "d.csv", blob_storage_container = NULL)
  rt <- RightTruncation(path = "r.csv", blob_storage_container = NULL)
  params <- Parameters(
    as_of_date = "2024-01-01",
    generation_interval = gen,
    delay_interval = del,
    right_truncation = rt
  )
  expect_s3_class(params, "Parameters")
  expect_equal(S7::prop(params, "as_of_date"), "2024-01-01")
  expect_s3_class(S7::prop(params, "generation_interval"), "GenerationInterval")
})

test_that("Data class can be constructed", {
  d <- Data(
    path = "foo.parquet",
    blob_storage_container = NULL,
    report_date = "2024-01-01",
    reference_date = "2024-01-01"
  )
  expect_s3_class(d, "Data")
  expect_equal(S7::prop(d, "path"), "foo.parquet")
})

test_that("Config class can be constructed with nested objects", {
  d <- Data(
    path = "foo.parquet",
    blob_storage_container = NULL,
    report_date = "2024-01-01",
    reference_date = "2024-01-01"
  )
  gen <- GenerationInterval(path = "g.csv", blob_storage_container = NULL)
  del <- DelayInterval(path = "d.csv", blob_storage_container = NULL)
  rt <- RightTruncation(path = "r.csv", blob_storage_container = NULL)
  params <- Parameters(
    as_of_date = "2024-01-01",
    generation_interval = gen,
    delay_interval = del,
    right_truncation = rt
  )
  excl <- Exclusions(path = "ex.csv", blob_storage_container = NULL)
  cfg <- Config(
    job_id = "job1",
    task_id = "task1",
    min_reference_date = "2024-01-01",
    max_reference_date = "2024-01-31",
    report_date = "2024-01-31",
    production_date = "2024-01-31",
    disease = "COVID-19",
    geo_value = "US",
    geo_type = "state",
    seed = 42L,
    horizon = 2L,
    model = "EpiNow2",
    config_version = "1.0",
    quantile_width = c(0.5, 0.95),
    data = d,
    priors = list(rt = list(mean = 1, sd = 0.5), gp = list(alpha_sd = 1)),
    parameters = params,
    sampler_opts = list(
      cores = 1,
      chains = 2,
      iter_warmup = 100,
      iter_sampling = 100,
      max_treedepth = 10,
      adapt_delta = 0.8
    ),
    exclusions = excl,
    output_container = NULL
  )
  expect_s3_class(cfg, "Config")
  expect_equal(S7::prop(cfg, "job_id"), "job1")
  expect_s3_class(S7::prop(cfg, "data"), "Data")
})

test_that("read_json_into_config reads and constructs Config object", {
  # Create a minimal config as a list
  gen <- list(path = "g.csv", blob_storage_container = NULL)
  del <- list(path = "d.csv", blob_storage_container = NULL)
  rt <- list(path = "r.csv", blob_storage_container = NULL)
  params <- list(
    as_of_date = "2024-01-01",
    generation_interval = gen,
    delay_interval = del,
    right_truncation = rt
  )
  excl <- list(path = "ex.csv", blob_storage_container = NULL)
  d <- list(
    path = "foo.parquet",
    blob_storage_container = NULL,
    report_date = "2024-01-01",
    reference_date = "2024-01-01"
  )
  cfg_list <- list(
    job_id = "job1",
    task_id = "task1",
    min_reference_date = "2024-01-01",
    max_reference_date = "2024-01-31",
    report_date = "2024-01-31",
    production_date = "2024-01-31",
    disease = "COVID-19",
    geo_value = "US",
    geo_type = "state",
    seed = 42L,
    horizon = 2L,
    model = "EpiNow2",
    config_version = "1.0",
    quantile_width = c(0.5, 0.95),
    data = d,
    priors = list(rt = list(mean = 1, sd = 0.5), gp = list(alpha_sd = 1)),
    parameters = params,
    sampler_opts = list(
      cores = 1,
      chains = 2,
      iter_warmup = 100,
      iter_sampling = 100,
      max_treedepth = 10,
      adapt_delta = 0.8
    ),
    exclusions = excl,
    output_container = NULL
  )
  tf <- tempfile(fileext = ".json")
  jsonlite::write_json(cfg_list, tf, auto_unbox = TRUE)
  cfg <- read_json_into_config(tf, optional_fields = c("output_container"))
  expect_s3_class(cfg, "Config")
  expect_equal(S7::prop(cfg, "job_id"), "job1")
  expect_s3_class(S7::prop(cfg, "data"), "Data")
  expect_s3_class(S7::prop(cfg, "parameters"), "Parameters")
  expect_s3_class(S7::prop(cfg, "exclusions"), "Exclusions")
  unlink(tf)
})
