# "Phase 1" discussed in PR-#194 - Removing docker build from self-hosted runner

## Summary: 
Changes made in [Pull Request #194](https://github.com/CDCgov/cfa-epinow2-pipeline/pull/194) were requested to be merged in [phases](https://github.com/CDCgov/cfa-epinow2-pipeline/pull/194#issuecomment-2688312851)

This PR implements Phase 1 -> Move build off self-hosted runner to ubuntu-latest / use GHCR and 'az acr import'

## Changes Introduced:
- `build-pipeline-image` job uses github managed runner ubuntu-latest instead of cfa-cdcgov vm self-hosted runner.
- `twostep-container-build` action takes ghcr registry variables  
- `acr-import` job is added to copy the image to ACR from ghcr 