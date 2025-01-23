#!/usr/bin/env bash
#
# Delete Batch Pools and associated jobs

if [ "${#}" -ne 3 ]; then
  echo "Usage: $0 <account_name> <resource_group> <pool_id>"
  exit 1
fi

ACCOUNT_NAME="$1"
RESOURCE_GROUP="$2"
POOL_ID="$3"

echo "Logging into Batch account"
az batch account login \
  --name "${ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}"

##########################
# Fetch & delete jobs

echo "Fetching jobs in pool ${POOL_ID}"

JOB_IDS=$(az batch job list --query "[?poolInfo.poolId=='$POOL_ID'].id" --output tsv)

if [ -z "${JOB_IDS}" ]; then
  echo "No jobs found in pool: ${POOL_ID}"
else
  # Iterate line-by-line over the tsv list
  echo "${JOB_IDS}" | while IFS= read -r JOB_ID; do
    echo "Deleting job ${JOB_ID}"
    az batch job delete --job-id "${JOB_ID}" --yes
  done
fi

##########################
# Delete pool

az batch pool delete --pool-id "${POOL_ID}" --yes 2>/dev/null || {
  echo "Pool ${POOL_ID} does not exist or has already been deleted"
}
