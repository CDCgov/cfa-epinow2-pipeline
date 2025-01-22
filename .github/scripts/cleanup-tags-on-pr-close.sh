#!/usr/bin/env bash
#
# Delete container tags from Azure CR

if [ "${#}" -ne 3 ]; then
  echo "Usage: $0 <registry> <image> <tag>"
  exit 1
fi

REGISTRY="$1"
IMAGE="$2"
TAG="$3"

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
