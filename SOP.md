## Epinow2 Rt Pipeline Local Run
This document is meant to guide someone in running the weekly Rt estimation pipeline from within the VAP (Virtual Analytic Platform). The main command for running the weekly pipeline (found in the Makefile) is `make run-batch`. Running this will utilize a configuration file (.json) specified from within the associated blob storage account and will produce outputs in the `rt-epinow2-output` Azure blob storage account.

### Pre-requisites
1. VAP environment & Account
	- git (`sudo apt-get install git`)
	- docker CLI
	- gh CLI (`sudo apt-get install gh`)

2. cfa-epinow2-pipeline repository in VAP
	- Navigate to where you would like to clone the repository code
	- Clone the repository (`git clone https://www.github.com/cdcgov/cfa-epinow2-pipeline`)

3. Authentication to Azure
To authenticate to the requisite Azure resources provide a `.env` file containing the secrets necessary for authentication.
	- Request access to necessary Azure credential file (.env) from any of the admins listed in the README.md
	- decrypt the file (`gpg --decrypt .env`)
	- source it into your environemnt (`source .env`)

### Test Pre-requisites are Setup
#### Test Configuration Generation
1. `make config`
Running this command runs code located in the CDCgov/cfa-config-generator repository. This command creates a configuration file and saves it into the appropriate azure blob storage account.
If you receive an error that you do not have the necessary permissions to run this command please reach out Agastya Mondal (ab59@cdc.gov) for assistance

#### Test make run command
1. The following command will test your setup for using the `CFAEpiNow2Pipeline` package as well as your connection to the azure resources
 `make run CONFIG=test/test.json`

This command will run the pipeline for a single state and disease locally (using the computing power of your VAP account). This will take approximately 2 minutes.

### Rt Estimation Pipeline (Production)
If you have succesfully setup the pre-requisites and are able to run `make config` and `make run CONGIF=test/test.json` you are ready to run the entire pipeline in production `make run-batch`. This command will connect to Azure Batch and setup approximately 100 unique tasks that Azure Batch will run. This command is intended to close after initializing the jobs in Azure Batch. Please open Azure Batch Explorer to view the progress of these tasks.
