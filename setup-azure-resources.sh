#!/bin/bash

# Azure Resource Setup Script
# This script sets up all required Azure resources for the CI/CD pipeline

set -e

# Configuration
RESOURCE_GROUP="my-react-app-rg"
LOCATION="eastus"
KEY_VAULT_NAME="my-react-app-kv"
ACR_NAME="myreactappacr"
APP_INSIGHTS_NAME="my-react-app-insights"

echo "Setting up Azure resources for React app CI/CD pipeline..."

# Create Resource Group
echo "Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
echo "Creating Azure Container Registry..."
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

# Get ACR credentials
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer --output tsv)
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)

# Create Key Vault
echo "Creating Key Vault..."
az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku standard

# Create Application Insights
echo "Creating Application Insights..."
az monitor app-insights component create \
  --app $APP_INSIGHTS_NAME \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --kind web

# Get Application Insights instrumentation key
APP_INSIGHTS_KEY=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query instrumentationKey \
  --output tsv)

# Add secrets to Key Vault
echo "Adding secrets to Key Vault..."

# API URL
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "API-URL" \
  --value "https://your-api-endpoint.com"

# Database URL
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "DATABASE-URL" \
  --value "postgresql://username:password@host:port/database"

# JWT Secret
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "JWT-SECRET" \
  --value "your-jwt-secret-here"

# Application Insights Key
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "APP-INSIGHTS-KEY" \
  --value $APP_INSIGHTS_KEY

# Create Service Principal for Azure DevOps
echo "Creating service principal for Azure DevOps..."
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "my-react-app-sp" \
  --role contributor \
  --scopes /subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RESOURCE_GROUP \
  --sdk-auth)

# Extract service principal details
SP_APP_ID=$(echo $SP_OUTPUT | jq -r '.clientId')
SP_PASSWORD=$(echo $SP_OUTPUT | jq -r '.clientSecret')
SP_TENANT=$(echo $SP_OUTPUT | jq -r '.tenantId')

# Grant Key Vault access to service principal
echo "Granting Key Vault access to service principal..."
az keyvault set-policy \
  --name $KEY_VAULT_NAME \
  --spn $SP_APP_ID \
  --secret-permissions get list

# Output configuration
echo ""
echo "=== Azure Resources Setup Complete ==="
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""
echo "Azure Container Registry:"
echo "  Name: $ACR_NAME"
echo "  Login Server: $ACR_LOGIN_SERVER"
echo "  Username: $ACR_USERNAME"
echo "  Password: $ACR_PASSWORD"
echo ""
echo "Key Vault:"
echo "  Name: $KEY_VAULT_NAME"
echo "  Secrets: API-URL, DATABASE-URL, JWT-SECRET, APP-INSIGHTS-KEY"
echo ""
echo "Application Insights:"
echo "  Name: $APP_INSIGHTS_NAME"
echo "  Instrumentation Key: $APP_INSIGHTS_KEY"
echo ""
echo "Service Principal (for Azure DevOps):"
echo "  Application ID: $SP_APP_ID"
echo "  Tenant ID: $SP_TENANT"
echo "  Client Secret: $SP_PASSWORD"
echo ""
echo "=== Next Steps ==="
echo "1. Update azure-pipelines.yml with the above values"
echo "2. Create environments in Azure DevOps: development, staging, production"
echo "3. Set up service connections in Azure DevOps"
echo "4. Configure approval gates for staging and production environments"
echo ""
echo "Service connections to create in Azure DevOps:"
echo "- Azure Resource Manager (using service principal above)"
echo "- Azure Container Registry (using ACR credentials above)"
echo "- SonarCloud (if using SonarCloud)" 