#!/bin/bash

# This is a wrapper script around the CFAEpiNow2Pipeline::orchestrate_pipeline command that checks
# environment variables and executes the command. This provides a simple mechanism that can be specified
# as a container startup command, allowing the same build to be executed with different configurations 
# and inputs.

# Config file always differs and needs to be specified as a parameter. Azure tenant id, client id,
# and service principal are required as environment variables. If any are not present, print a message
# and exit.
if [[ -z "$1" ]]; then
    echo "No config file specified - please provide as argument to this script."
elif [[ -z "${az_tenant_id}" ]]; then
    echo "No Azure Tenant ID specified - please set az_tenant_id environment variable."
elif [[ -z "${az_client_id}" ]]; then       
    echo "No Azure Client ID specified - please set az_client_id environment variable."
elif [[ -z "${az_service_principal}" ]]; then
    echo "No Azure Service Principal specified - please set az_service_principal environment variable."
else
    # check for other environment variables, using defaults if not set
    CFG_CNTR="${CFG_CNTR:-rt-epinow2-config}"
    INPUT_DIR="${INPUT_DIR:-/mnt/input}"
    OUTPUT_DIR="${OUTPUT_DIR:-/mnt}"
    OUTPUT_CNTR="${OUTPUT_CNTR:-zs-test-pipeline-update}"

    # build the string
    EXEC_STR="CFAEpiNow2Pipeline::orchestrate_pipeline('$1', config_container='$CFG_CNTR', input_dir='$INPUT_DIR', output_dir='$OUTPUT_DIR', output_container='$OUTPUT_CNTR')"

    # print it, also visible and filterable in Azure logs
    echo "Executing pipeline: $EXEC_STR"

    # execute
    Rscript -e "$EXEC_STR"
fi
