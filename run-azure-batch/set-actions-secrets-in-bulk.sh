#!/bin/bash
# Zach, George:
# Run this locally only! Make sure not to overwrite secrets without checking first.
# You'll need to be logged into az login with your ext account or VM identity.
# You'll also need to have the gh cli installed and you must be logged in

# Pull the file from storage (download manually or az storage blob download locally): 
# https://cfadatalakeprd.blob.core.windows.net/cfapredict/NNH/NHSN/Rt/cfa-epinow2-pipeline.env

# Login
echo -e "Logging into to Azure..."
az login --identity # use --use-device-code if your VM managed identity isn't yet configured

echo -e ""

# path to blob
path_to_secrets_blob="cfapredict/NNH/NHSN/Rt/cfa-epinow2-pipeline.env"

sleep 1

echo -e "Downloading env file $path_to_secrets_blob..."

sleep 1

# Download the env file
az storage blob download \
    --auth-mode login \
    --blob-url "https://cfadatalakeprd.blob.core.windows.net/$path_to_secrets_blob" \
    --file .env

echo -e ""

# Examine your secrets by hand
# (Open in a text editor. try not to open it programmatically, such as with cat, less, or more, etc.)

echo -e "Setting repo secrets from .env"

sleep 1
# Then, load them into the repository - gh cli required!
gh secret set -f .env

echo -e ""
echo -e "Secret set complete"