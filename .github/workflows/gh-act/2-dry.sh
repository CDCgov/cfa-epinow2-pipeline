#!/bin/bash

# Requires that you have first run 'gh extension install nektos/gh-act'
# as well as having installed the docker engine and added your user to the docker group

# This checks syntax before you push to Github Actions, helping with debug hell
# To run the entire pipeline locally, see 2-full.sh

gh act -P cfa-cdcgov=... -n -W '.github/workflows/2-Run-Epinow2-Pipeline.yaml'
