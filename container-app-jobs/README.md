# Container App Job Tools

This directory contains tools related to executing this pipeline in Azure as a Container App Job.

## job-template.yaml

The *job-template-yaml* file can be passed to the Azure CLI to start a Container App Job from the command line. This allows a user to quickly kick off specific jobs from a WSL console.

If not previously installed, refer to the documentation [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt) for installation instructions on the CLI itself. The command in Option 1 is the best way to accomplish this:

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Update the *job-template.yaml* file with the Azure tenant and client ids, as well as the config file to execute the job on. The job can then be started from the CLI with the following command:

```bash
az containerapp job start --name 'cfa-epinow2-test-caj' --resource-group 'EXT-EDAV-CFA-PRD' --yaml job-template.yaml
```

This command will start the job and return metadata including the newly created job's id. Refer to the Azure portal in a browser to track status and results.

## blob-config-runner

The *blob-config-runner* directory contains a Python tool that can start multiple jobs at once. It looks for files within a specified Azure Blob Storage container, presents them to the user for interactive selection, and runs a job on each once confirmed.

This tool requires Python 3, which is already installed within WSL. A virtual environment using *venv* is recommend for execution, which can be installed with *apt*. To initialize the environment and necessary libraries, run the following command from the directory:

```bash
python3 -m venv .venv
.venv/bin/python3 -m pip install -r requirements.txt
```

Enter the *config.ini* file's client, tenant, and subscription id values within the Azure section. Update the container name and prefix as needed for this specific run. The env_vars section should not be updated, as these are used by the script to replace the values.  The tool can now be run as follows:

```bash
.venv/bin/python3 start-jobs.py
```

**Note:** This tool identifies config files by looking for a suffix of *-config.json*. This logic could be updated to instead look for tags or metadata, if files were appropriately identified as such within Azure.
