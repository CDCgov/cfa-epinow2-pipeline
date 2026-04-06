
- **Parquet test fixtures**
  - `CA_test.parquet`: Synthetic test data containing metric 'count_ed_visits' and 'COVID-19/Omicron' as disease (data in format of API v1). `read_data` converts 'COVID-19/Omicron' disease to 'COVID-19'. Does _not_ contain column `any_visits_this_day`.
  - `CA_apiv2_test.parquet`: Synthetic test data containing metric 'count_ed_visits' and 'COVID-19' as disease (data in format of API v2). Contains column `any_visits_this_day`.
  - `test_data.parquet`/`us_overall_test_data.parquet`: Package data. See `?gostic_toy_rt` and `data-raw/convert_gostic_toy_rt_to_test_dataset.R`
  - `test_parameters.parquet`: Package data. See `?sir_gt_pmf` and `data-raw/sir_gt_pmf.R` 

- **JSON test configs**
  - `CA_COVID-19.json`: EpiNow2 task config for a CA/COVID-19 run (dates, model/sampler settings) pointing to `CA_test.parquet`, with no exclusions (`exclusions.path: null`).
  - `bad_config.json`: Intentionally invalid config value to test validation/error handling
  - `sample_config_no_exclusion.json`: Example valid config for no exclusions.
  - `sample_config_with_exclusion.json`: Example config that includes exclusions
  - `v_bad_config.json`: Intentionally incomplete/invalid config (only `job_id` and `task_id`) to test required fields are enforced.

- **CSV exclusions fixtures**
  - `test_exclusions.csv`: Minimal exclusions fixture (columns `reference_date, report_date, state, disease`) with one row for `state=test, disease=test`.
  - `test_big_exclusions.csv`: Larger exclusions fixture (same columns) to test impact of many exclusions
