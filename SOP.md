## Epinow2 Rt Pipeline Local Run
This document is meant to guide someone in running the weekly Rt estimation pipeline from within the VAP (Virtual Analytic Platform). The main command for running the weekly pipeline (found in the Makefile) is `make run-prod`. Running this will create and utilize a suite of configuration files (.json) specified from within the associated blob storage account and will produce outputs in the `rt-epinow2-output` Azure blob storage account.

### Pre-requisites
1. VAP environment & Account
	- git (`sudo apt-get install git`)
	- docker CLI
	- gh CLI (`sudo apt-get install gh`)

2. cfa-epinow2-pipeline repository in VAP
	- Navigate to where you would like to clone the repository code
	- Clone the repository (`git clone https://www.github.com/cdcgov/cfa-epinow2-pipeline` OR `gh auth login`
and then `gh repo clone cdcgov/cfa-epinow2-pipeline`)

3. Authentication to Azure
To authenticate to the requisite Azure resources provide a `.env` file containing the secrets necessary for authentication.
	- Request access to necessary Azure credential file (.env) from any of the admins listed in the README.md
	- decrypt the file (`gpg --decrypt .env`)
	- Place the decrypted file in your `cfa-epinow2-pipeline` directory

### Test Pre-requisites are Setup
#### Test Configuration Generation
1. `make config`
Running this command runs code located in the CDCgov/cfa-config-generator repository. This command creates a suite of configuration file and saves it into the appropriate azure blob storage account.
If you receive an error that you do not have the necessary permissions to run this command please reach out Agastya Mondal (ab59@cdc.gov) for assistance.

#### Test make run command
1. The following command will test your setup for using the `CFAEpiNow2Pipeline` package. This command will run the pipeline for a single state and disease locally (using the computing power of your VAP account). This will take approximately 2 minutes.
 `make run CONFIG=test/test.json`
2. The following command will test your connection to Azure Batch resources. This command will run the pipeline for a single state (NY) and run using Azure Batch resources. To track the status of the nodes and pool, open Azure Batch Explorer.
 `make test-batch`

### Rt Estimation Pipeline (Production)
If you have succesfully setup the pre-requisites and are able to run `make config` and `make run CONGIF=test/test.json` you are ready to run the entire pipeline in production `make run-prod`. 
This command will run `make config`, then followed by a docker build, and then will the `job.py` script from in Batch; you only need to run `make run-prod` all of the work is done for you inside the Makefile! In doing so you are connecting to Azure Batch and setup 102 unique tasks that Azure Batch will run. This command is intended to close after initializing the jobs in Azure Batch. Please open Azure Batch Explorer to view the progress of these tasks.

#### Exclusions
If you would like to re-run the entire pipeline with exclusions to the configurations you are able to do so. There are two main types of exclusions that users commonly will need to consider (task exclusions, and data exclusions).
##### Task Exclusions
Task exclusions are state and disease pairs (ex. 'NY:COVID-19)' that users can specify when running so that tasks for specified state disease pairs are not generated unnecessarily. Users can specify more than one state and disease pair, so long as they are separate by a ',' (ex. 'NY:COVID-19,WA:Influenza'). To do so, a user will need to first, generate the configuration files and specify the state:disease pair to exclude (see example below) and second, run the pipeline for these configurations. 
1. `TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S"); JOB_ID=Rt-estimation-$(echo $TIMESTAMP)` 
2. `gh workflow run -R cdcgov/cfa-config-generator run-workload.yaml -f job_id=$(echo $JOB_ID) -f task_exclusions='NY:COVID-19'` 
3. `make run-batch JOB=$(echo $JOB_ID)`

##### Data Exclusions
The process for handling data exclusions is currently being finalized adn this section will be finalized in April 2025. For the current procedure please reach out to Patrick Corbett (pyv3@cdc.gov). 

### Appendix
#### Podman
The default container management software is setup to utilize docker. For users that are currently using podman, please adjust the variable `CNTR_MGR` within the makefile prior to running any commands. Further, it will be necessary to authenticate to azure resources through podman (`podman login`).
