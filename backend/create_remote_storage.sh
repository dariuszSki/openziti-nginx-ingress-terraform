#!/bin/bash

RESOURCE_GROUP_NAME=tfstate
STORAGE_ACCOUNT_NAME=tfstate$RANDOM
CONTAINER_NAME=tfstate

# Login to Azure
az login --service-principal --username $CLIENT_ID --password $CLIENT_SECRET --tenant $TENANT_ID 

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus --subscription $SUB_ID

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob --subscription $SUB_ID

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --subscription $SUB_ID

# Retrieve the storage key
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --subscription $SUB_ID --query '[0].value' -o tsv)
export ARM_ACCESS_KEY=$ACCOUNT_KEY

