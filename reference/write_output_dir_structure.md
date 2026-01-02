# Create output directory structure for a given job and task.

This function generates the necessary directory structure for storing
output files related to a job and its tasks, including directories for
raw samples and summarized quantiles.

## Usage

``` r
write_output_dir_structure(output_dir, job_id, task_id)
```

## Arguments

- output_dir:

  A string specifying the directory where output, logs, and other
  pipeline artifacts will be saved. Defaults to the root directory
  ("/").

- job_id:

  A string specifying the job.

- task_id:

  A string specifying the task.

## Value

The path to the base output directory (invisible).

## See also

Other write_output:
[`sample_processing_functions`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/sample_processing_functions.md),
[`write_model_outputs()`](https://cdcgov.github.io/cfa-epinow2-pipeline/reference/write_model_outputs.md)
