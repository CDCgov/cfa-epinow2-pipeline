# Write model outputs to specified directories

Processes the model fit, extracts samples and quantiles, and writes them
to the appropriate directories.

## Usage

``` r
write_model_outputs(
  fit,
  samples,
  summaries,
  output_dir,
  job_id,
  task_id,
  metadata = list(),
  diagnostics
)
```

## Arguments

- fit:

  An `EpiNow2` fit object with posterior estimates.

- samples:

  A data.table as returned by
  [`process_samples()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sample_processing_functions.md)

- summaries:

  A data.table as returned by
  [`process_quantiles()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sample_processing_functions.md)

- output_dir:

  A string specifying the directory where output, logs, and other
  pipeline artifacts will be saved. Defaults to the root directory
  ("/").

- job_id:

  A string specifying the job.

- task_id:

  A string specifying the task.

- metadata:

  List. Additional metadata to be included in the output. The paths to
  the samples, summaries, and model output will be added to the metadata
  list.

- diagnostics:

  A data.table as returned by
  [`extract_diagnostics()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/extract_diagnostics.md)

## Value

Invisible NULL. The function is called for its side effects.

## See also

Other write_output:
[`sample_processing_functions`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sample_processing_functions.md),
[`write_output_dir_structure()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/write_output_dir_structure.md)
