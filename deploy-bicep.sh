#!/bin/bash

# Bicep Deployment Script for React App Azure Resources

set -e

# Configuration
RESOURCE_GROUP="my-react-app-rg"
LOCATION="eastus"
BICEP_FILE="setup-azure-resources.bicep"
PARAMETERS_FILE="setup-azure-resources.parameters.json"
DEPLOYMENT_NAME="my-react-app-deployment-$(date +%Y%m%d-%H%M%S)"

echo "Starting Bicep deployment for React app Azure resources..."
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    echo "Please log in to Azure..."
    az login
fi

# Check if Bicep is installed
if ! command -v bicep &> /dev/null; then
    echo "Installing Bicep..."
    az bicep install
fi

# Create resource group if it doesn't exist
echo "Creating resource group if it doesn't exist..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Validate the Bicep template
echo "Validating Bicep template..."
az deployment group validate \
    --resource-group $RESOURCE_GROUP \
    --template-file $BICEP_FILE \
    --parameters @$PARAMETERS_FILE

if [ $? -eq 0 ]; then
    echo "✓ Bicep template validation successful"
else
    echo "✗ Bicep template validation failed"
    exit 1
fi

# Deploy the Bicep template
echo "Deploying Bicep template..."
az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file $BICEP_FILE \
    --parameters @$PARAMETERS_FILE \
    --name $DEPLOYMENT_NAME \
    --verbose

if [ $? -eq 0 ]; then
    echo "✓ Bicep deployment successful"
else
    echo "✗ Bicep deployment failed"
    exit 1
fi

# Get deployment outputs
echo ""
echo "Getting deployment outputs..."
OUTPUTS=$(az deployment group show \
    --resource-group $RESOURCE_GROUP \
    --name $DEPLOYMENT_NAME \
    --query properties.outputs \
    --output json)

# Extract and display important outputs
ACR_LOGIN_SERVER=$(echo $OUTPUTS | jq -r '.acrLoginServer.value')
ACR_NAME=$(echo $OUTPUTS | jq -r '.acrName.value')
KEY_VAULT_NAME=$(echo $OUTPUTS | jq -r '.keyVaultName.value')
APP_INSIGHTS_KEY=$(echo $OUTPUTS | jq -r '.appInsightsKey.value')
APP_INSIGHTS_NAME=$(echo $OUTPUTS | jq -r '.appInsightsName.value')
STORAGE_ACCOUNT_NAME=$(echo $OUTPUTS | jq -r '.storageAccountName.value')

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""
echo "Azure Container Registry:"
echo "  Name: $ACR_NAME"
echo "  Login Server: $ACR_LOGIN_SERVER"
echo ""
echo "Key Vault:"
echo "  Name: $KEY_VAULT_NAME"
echo "  Secrets: API-URL, DATABASE-URL, JWT-SECRET, APP-INSIGHTS-KEY"
echo ""
echo "Application Insights:"
echo "  Name: $APP_INSIGHTS_NAME"
echo "  Instrumentation Key: $APP_INSIGHTS_KEY"
echo ""
echo "Storage Account:"
echo "  Name: $STORAGE_ACCOUNT_NAME"
echo ""
echo "=== Next Steps ==="
echo "1. Update azure-pipelines.yml with the above values"
echo "2. Create environments in Azure DevOps: development, staging, production"
echo "3. Set up service connections in Azure DevOps"
echo "4. Configure approval gates for staging and production environments"
echo ""
echo "Service connections to create in Azure DevOps:"
echo "- Azure Resource Manager"
echo "- Azure Container Registry"
echo "- SonarCloud (if using SonarCloud)"
echo ""
echo "To get ACR credentials:"
echo "az acr credential show --name $ACR_NAME"
