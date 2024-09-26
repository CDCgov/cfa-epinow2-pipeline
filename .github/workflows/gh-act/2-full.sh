#!/bin/bash

# Requires that you have first run 'gh extension install nektos/gh-act'
# as well as having installed the docker engine and added your user to the docker group

# This runs the github actions workflow locally

gh act -P cfa-cdcgov=catthehacker/ubuntu:full-20.04 -W '.github/workflows/2-Run-Epinow2-Pipeline.yaml'
