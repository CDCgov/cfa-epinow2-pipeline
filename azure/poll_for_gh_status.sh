#!/bin/bash

set -euo pipefail

echo "Polling for config generation completion"

while true; do
  STATUS="$(gh run list --repo cdcgov/cfa-config-generator --limit 1 --json status | jq -r '.[0].status')"
  CONCLUSION="$(gh run list --repo cdcgov/cfa-config-generator --limit 1 --json conclusion | jq -r '.[0].conclusion')"

  if [[ "$STATUS" == "completed" ]]; then
    if [[ "$CONCLUSION" == "success" ]]; then
      echo "Latest config generation workflow completed"
      exit 0
    else
      echo "Failure: workflow failed with conclusion $(CONCLUSION)"
      exit 1
    fi
  fi

  echo
  echo "Workflow status: $STATUS"
  echo "Waiting 15 seconds and retrying"
  echo
  sleep 15
done
