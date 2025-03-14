# CFAEpiNow2Pipeline v0.2.0

## Features
* Add output container as a new field in the config file.
* Building with ubuntu-latest and using Container App runner for all else
* Adding exclusions documentation and Makefile support
* Add the blob storage container, if provided
* Adding make command to test Azure batch
* Updating subnet ID and pool VM to 22.04 from 20.04
* Write model diagnostics to an output file, correcting an oversight
* Refactored GH Actions container build to cfa-actions 2-step build
* Creating SOP.md to document weekly run procedures
* Allows unique job_ids for runs.
* Makefile supports either docker or podman as arguments to setup & manage containers
* Streamlined configurable container execution provided by included start.sh script
* Container App Job execution tools added including job-template.yaml file for single task and Python script for bulk tasks
* Minor changes in removing unused container tags from Azure CR.

# CFAEpiNow2Pipeline v0.1.0

This initial release establishes minimal feature parity with the internal EpiNow2 Rt modeling pipeline. It adds wrappers to integrate with internal data schemas and ingest pre-estimated model parameters (i.e., generation intervals, right-truncation). It defines an output schema and adds comprehensive logging. The repository also has functionality to set up and deploy to Azure Batch.

## Features

* GitHub Actions to build Docker images on PR and merge to main, deploy Azure Batch environments off the built images, and tear down the environment (including images) on PR close.
* Comprehensive documentation of pipeline code and validation of input data, parameters, and model run configs
* Set up comprehensive logging of model runs and handle pipeline failures to preserve logs where possible
* Automatically download and upload inputs and outputs from Azure Blob Storage
