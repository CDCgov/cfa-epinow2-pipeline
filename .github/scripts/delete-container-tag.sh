#!/usr/bin/env bash
#
# Delete container tags from Azure CR

if [ "${#}" -ne 5 ]; then
  echo "Usage: $0 <account name> <resource group> <registry> <image> <tag>"
  exit 1
fi

ACCOUNT_NAME="$1"
RESOURCE_GROUP="$2"
REGISTRY="$3"
IMAGE="$4"
TAG="$5"

echo "Logging into Batch account"
az batch account login \
  --name "${ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP}"

##########################
# Delete container tags

# Remove the image from the registry
az acr repository delete \
    --yes \
    --name "${REGISTRY}" \
    --image "${IMAGE}:${TAG}"

az acr repository delete \
    --yes \
    --name "${REGISTRY}" \
    --image "${IMAGE}:dependencies-${TAG}"
