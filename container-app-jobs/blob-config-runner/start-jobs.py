import os, uuid
import configparser

from azure.identity import DefaultAzureCredential, EnvironmentCredential
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient
from azure.mgmt.appcontainers import ContainerAppsAPIClient
from azure.mgmt.appcontainers.models import JobExecutionTemplate, JobExecutionContainer, EnvironmentVar, ContainerResources

# dictionary keys for keeping track of selection status for each config file
NAME = 'name'
SELECTED = 'selected'

# Prints the status of each config file in a formatted table
# Each row will look something like: '1  [X]  config_file_1.json' 
def print_configs(config_files):
    print('Index  Selected  Name')
    print('=====  ========  ====')

    i = 1
    for entry in config_files:
        print(f"{i}      [{'X' if entry[SELECTED] else ' '}]        {entry[NAME]}")
        i = i+1

# Toggles the selected status for an individual item, specified by the index.
# Note that this list starts at 1, so we have to offset by -1 here.
def toggle_config(config_files, index):
    if index < 1 or index <= len(config_files):
        config_files[index-1][SELECTED] = not config_files[index-1][SELECTED]
    else:
        print('Invalid index selected, please refer to list.')

# Set all items to selected or not, based on the second parameter.
# Enables select/deselect all option.
def set_all(config_files, selected):
    for entry in config_files:
        entry[SELECTED] = selected

# Collect all the selected items and return the config files names as a list, for processing
def get_selected(config_files):
    selected = []
    for entry in config_files:
        if(entry[SELECTED]):
            selected.append(entry[NAME])

    return selected

# Load the config file
config = configparser.ConfigParser()
config.read('config.ini')

# Create default credentials to give to the Azure SDK client. Used by both blob storage and container app jobs.
credential = DefaultAzureCredential()

# Create a blob service client object
blob_service_client = BlobServiceClient(config.get('azure', 'account_url'), credential=credential)
# Create a container client using the client for the container
container_client = blob_service_client.get_container_client(container=config.get('azure', 'container_name'))
# List the blobs in this container
blob_list = container_client.list_blobs(name_starts_with=config.get('azure', 'prefix'))

# Iterate over the items returned from blob storage and build a dictionary to keep track of their selection status
config_files = []
for blob in blob_list:
    if blob.name.endswith('-config.json'):      # expected file naming to identify config files
        config_files.append({NAME: blob.name, SELECTED: False})         # set each to not selected by default

# Output some instructions
print('Select config files to start jobs on. Select items by entering each index individually or as a comma separated list.')
print('Additionally, enter \'A\' to select all, \'N\' to deselect all, or \'Q\' to quit.')
print('When selections are complete, press Enter with no input to proceed.')

# Print the dictionary
print_configs(config_files)

# Prompt the user for input in a loop, allowing them to select which config files they want to process
val = '0'   # default value
while val.upper() != '':        # loop until they enter nothing, which signifies continuing to the process step
    val = input('Enter selection (or press enter to proceed): ')        # get user input

    try:
        index = int(val)        # attempt to convert the value to an integer
        toggle_config(config_files, index)      # if successful, toggle that item
    except ValueError:          # if int conversion failed, its not a number
        if val.upper() == 'Q':
            quit()      # quit the script
        if val.upper() == 'A':
            set_all(config_files, True)     # select all
        elif val.upper() == 'N':
            set_all(config_files, False)    # deselect all
    
    if val != '':   # dont print the last time
        # Print the dictionary
        print_configs(config_files)

# Collect the selected items and move on to processing step
selected = get_selected(config_files)
print(f'Processing {len(selected)} files: {selected}.')
val = input('Confirm to proceed (Y)? ')     # confirm the list with the user

if val.upper() == 'Y':
    # Create some Azure SDK objects that are reused for each config file template
    
    # Setup environment variable objects
    env_vars = []
    env_vars.append(EnvironmentVar(
                    name=config.get('env_vars', 'tenant_id_label'),
                    value=config.get('azure', 'tenant_id_value')))
    env_vars.append(EnvironmentVar(
                    name=config.get('env_vars', 'client_id_label'),
                    value=config.get('azure', 'client_id_value')))
    env_vars.append(EnvironmentVar(
                    name=config.get('env_vars', 'sp_label'),
                    secret_ref=config.get('env_vars', 'sp_ref')))

    # Setup container resources object
    container_resources = ContainerResources(
        cpu=config.get('caj', 'cpu'), 
        memory=config.get('caj', 'memory'))

    # Common Azure SDK object setup complete

    for config_file in selected:        # process each item
        print('==================================================')
        print(f'Processing {config_file}...')

        # Setup container object
        container = JobExecutionContainer(
            args=[config_file],
            command=[config.get('caj', 'command')],
            env=env_vars,
            image=config.get('caj', 'image'), 
            name=config.get('caj', 'name'),
            resources=container_resources)

        # Setup job template to pass to Azure SDK
        template = JobExecutionTemplate(containers=[container])

        # Create the Azure SDK container apps client
        client = ContainerAppsAPIClient(
            credential=credential, 
            subscription_id=config.get('azure', 'subscription_id'))

        # Execute the container app job for the generated template
        response = client.jobs.begin_start(
            resource_group_name=config.get('caj', 'resource_group'), 
            job_name=config.get('caj', 'name'), 
            template=template).result()

        # Output the details on the new job and proceed to the next config file
        print(f'Job created: {response}')