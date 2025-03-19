## Epinow2 Rt Pipeline Local Run
This document is meant to guide someone in running the weekly Rt estimation pipeline from within the VAP (Virtual Analytic Platform). The main command for running the weekly pipeline (found in the Makefile) is `make run-prod`. Running this will create and utilize a suite of configuration files (.json) specified from within the associated blob storage account and will produce outputs in the `rt-epinow2-output` Azure blob storage account.

### Pre-requisites
1. VAP environment & Account
	- git (`sudo apt-get install git`)
	- docker CLI ([follow this script](https://teams.microsoft.com/l/message/19:064fb29dee654148b647dc8b9bab0782@thread.tacv2/1728396548512?tenantId=9ce70869-60db-44fd-abe8-d2767077fc8f&groupId=4f34eba7-8fcb-4a26-9b34-a434ea777f0c&parentMessageId=1728396548512&teamName=CFA-Predict&channelName=Help&createdTime=1728396548512)). See the [appendix](#appendix) for podman instructions.
	- gh CLI (`sudo apt-get install gh`)

2. cfa-epinow2-pipeline repository in VAP
	- Navigate to where you would like to clone the repository code
	- Clone the repository (`git clone https://www.github.com/cdcgov/cfa-epinow2-pipeline` OR `gh auth login` and then `gh repo clone cdcgov/cfa-epinow2-pipeline`)

3. Authentication to Azure
To authenticate to the requisite Azure resources provide a `.env` file containing the secrets necessary for authentication.
	- Request access to necessary Azure credential file (.env) from any of the admins listed in the README.md
	- decrypt the file (`gpg --decrypt .env`)
	- Place the decrypted file in your `cfa-epinow2-pipeline` directory

### Test Pre-requisites are Setup
#### Test Configuration Generation
1. `make config`
Running this command runs code located in the CDCgov/cfa-config-generator repository. This command creates a suite of configuration files, following the default settings for
a production run, and saves it into `az:/rt-epinow2-config/{job_id}`.
If successful, the job id will print to the command line:

![alt text](image.png)

Verify that you can locate the configuration files in Azure blob storage.

If you receive an error that you do not have the necessary permissions to run this command please reach out Agastya Mondal (ab59@cdc.gov) for assistance.

#### Test make run command
1. The following command will test your setup for using the `CFAEpiNow2Pipeline` package. This command will run the pipeline for a single state and disease locally (using the computing power of your VAP account). This will take approximately 2 minutes.
 `make run CONFIG=test/test.json`
2. The following command will test your connection to Azure Batch resources. This command will run the pipeline for a single state (NY) and run using Azure Batch resources. To track the status of the nodes and pool, open Azure Batch Explorer. The outputs will write
to the `nssp-rt-testing` container, in a directory labeled with the jobid printed
to your command line. Verify that you can locate them in blob storage.
 `make test-batch`

### Rt Estimation Pipeline (Production)
If you have succesfully setup the pre-requisites and are able to run `make config` and `make run CONGIF=test/test.json` you are ready to run the entire pipeline in production `make run-prod`.
This command will run `make config`, then followed by a docker build, and then will the `job.py` script from in Batch; you only need to run `make run-prod` all of the work is done for you inside the Makefile! In doing so you are connecting to Azure Batch and setup 102 unique tasks that Azure Batch will run. This command is intended to close after initializing the jobs in Azure Batch. Please open Azure Batch Explorer to view the progress of these tasks.

#### Exclusions and modifications
After reviewing the initial run, we may choose to make two kinds of changes to
the models. First, we may exclude the results from the released predictions,
if the data or the model do not pass quality checks. Second, we may exclude one
or more data points from a specific state's data, e.g. if there is evidence of a
reporting anomaly on that date.

##### State (task) Exclusions
Excluding a state from the released production files occurs downstream of this modeling
pipeline. Instead, exclude states in the postprocessing step. Even if a model was run, and results were generated, the postprocessor can be configured to skip over the excluded jurisdictions when collecting the modeling results.

To exclude a state from the initial model run (e.g. due to a persistent reporting
outage), generate appropriate configs. Task exclusions are state and disease pairs (ex. 'NY:COVID-19)' that users can specify when running the config generator so that tasks for specified state disease pairs are not generated unnecessarily. Users can specify more than one state and disease pair, so long as they are separate by a ',' (ex. 'NY:COVID-19,WA:Influenza'). To do so, a user will need to first, generate the configuration files and specify the state:disease pair to exclude (see example below) and second, run the pipeline for these configurations. The `JOB=$(echo $JOB_ID)` option in step 3. instructs the model
run to use the config files generated in steps 1. and 2. Without this option,
`make run-batch` will generate new configs using the default settings, and will
run using those.

1. `TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S"); JOB_ID=Rt-estimation-$(echo $TIMESTAMP)`
2. `gh workflow run -R cdcgov/cfa-config-generator run-workload.yaml -f job_id=$(echo $JOB_ID) -f task_exclusions='NY:COVID-19', -f output_container='nssp-rt-v2'`
3. `make run-batch JOB=$(echo $JOB_ID)`

##### Data Exclusions
The process for handling data exclusions is currently being finalized adn this section will be finalized in April 2025. For the current procedure please reach out to Patrick Corbett (pyv3@cdc.gov).

##### Non-production runs
The config file uniquely defines a run. To kick off a non-production run, test,
or experiment, generate an appropriate set of configs.

**DO NOT** Write tests or experimental output to the production container,
`nssp-rt-v2`. Instead, please direct non-production output to `nssp-rt-testing`.
The testing container is the default output container in the config generator.

There are three ways to generate configs:

1. Use the GUI in the config generation repo
Navigate to https://github.com/CDCgov/cfa-config-generator/actions/workflows/run-workload.yaml,
click the "Run workflow" dropdown menu, specify your parameters, and hit "Run workflow".
This will write a set of configs to `az:/rt-epinow2-config/{job_id}`. Then run
`make run-batch JOB=job_id` to run the models using the configs you just generated.

![alt text](image-1.png)

2. Use the comand line
`gh workflow run -R cdcgov/cfa-config-generator run-workload.yaml -f job_id='my_job_id' -f task_exclusions='NY:COVID-19', -f output_container='nssp-rt-testing'`
Use -f flags to specify arugments different from the defaults

3. (We recommend you do NOT) run `make config`.
This will speficy the production container, `nssp-rt-v2`, as the output destination.
We don't want to contaminate the production output with test runs and experiments.
Use this for production runs only.


### Appendix
#### Podman
The default container management software is setup to utilize docker. For users that are currently using podman, please adjust the variable `CNTR_MGR` within the makefile prior to running any commands. Further, it will be necessary to authenticate to azure resources through podman (`podman login`).
