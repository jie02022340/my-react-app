#!/bin/bash

# Azure Resource Teardown Script
# This script removes all Azure resources created by setup-azure-resources.sh

set -e

# Configuration (should match setup-azure-resources.sh)
RESOURCE_GROUP="my-react-app-rg"
LOCATION="eastus"
KEY_VAULT_NAME="my-react-app-kv"
ACR_NAME="myreactappacr"
APP_INSIGHTS_NAME="my-react-app-insights"
SERVICE_PRINCIPAL_NAME="my-react-app-sp"

echo "Starting Azure resources teardown..."
echo "This will permanently delete all resources in resource group: $RESOURCE_GROUP"
echo ""

# Confirm deletion
read -p "Are you sure you want to delete all resources? This action cannot be undone. (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Proceeding with resource deletion..."

# Check if resource group exists
if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "Resource group '$RESOURCE_GROUP' does not exist. Nothing to delete."
    exit 0
fi

# Get resource group location for verification
RG_LOCATION=$(az group show --name $RESOURCE_GROUP --query location --output tsv 2>/dev/null || echo "")
if [ -n "$RG_LOCATION" ]; then
    echo "Found resource group '$RESOURCE_GROUP' in location: $RG_LOCATION"
else
    echo "Error: Could not retrieve resource group information."
    exit 1
fi

# List all resources in the resource group
echo ""
echo "Resources to be deleted:"
az resource list --resource-group $RESOURCE_GROUP --output table

echo ""
read -p "Do you want to proceed with deletion of these resources? (yes/no): " confirm_delete
if [ "$confirm_delete" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Starting resource deletion..."

# Delete Application Insights
echo "Deleting Application Insights..."
if az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP &>/dev/null; then
    az monitor app-insights component delete --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --yes
    echo "✓ Application Insights deleted"
else
    echo "- Application Insights '$APP_INSIGHTS_NAME' not found"
fi

# Delete Azure Container Registry and all its contents
echo "Deleting Azure Container Registry..."
if az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "  Found ACR: $ACR_NAME"
    
    # Delete all repositories in the registry
    echo "  Deleting all repositories..."
    REPOSITORIES=$(az acr repository list --name $ACR_NAME --output tsv 2>/dev/null || echo "")
    if [ -n "$REPOSITORIES" ]; then
        for repo in $REPOSITORIES; do
            echo "    Deleting repository: $repo"
            # Delete all tags in the repository
            TAGS=$(az acr repository show-tags --name $ACR_NAME --repository $repo --output tsv 2>/dev/null || echo "")
            if [ -n "$TAGS" ]; then
                for tag in $TAGS; do
                    echo "      Deleting tag: $repo:$tag"
                    az acr repository delete --name $ACR_NAME --image "$repo:$tag" --yes
                done
            fi
            # Delete the repository itself
            az acr repository delete --name $ACR_NAME --image $repo --yes
        done
        echo "    ✓ All repositories deleted"
    else
        echo "    - No repositories found"
    fi
    
    # Delete all tasks in the registry
    echo "  Deleting all tasks..."
    TASKS=$(az acr task list --registry $ACR_NAME --output tsv 2>/dev/null || echo "")
    if [ -n "$TASKS" ]; then
        for task in $TASKS; do
            echo "    Deleting task: $task"
            az acr task delete --name $task --registry $ACR_NAME --yes
        done
        echo "    ✓ All tasks deleted"
    else
        echo "    - No tasks found"
    fi
    
    # Delete all task runs
    echo "  Deleting all task runs..."
    TASK_RUNS=$(az acr taskrun list --registry $ACR_NAME --output tsv 2>/dev/null || echo "")
    if [ -n "$TASK_RUNS" ]; then
        for taskrun in $TASK_RUNS; do
            echo "    Deleting task run: $taskrun"
            az acr taskrun delete --name $taskrun --registry $ACR_NAME --yes
        done
        echo "    ✓ All task runs deleted"
    else
        echo "    - No task runs found"
    fi
    
    # Delete all webhooks
    echo "  Deleting all webhooks..."
    WEBHOOKS=$(az acr webhook list --registry $ACR_NAME --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$WEBHOOKS" ]; then
        for webhook in $WEBHOOKS; do
            echo "    Deleting webhook: $webhook"
            az acr webhook delete --name $webhook --registry $ACR_NAME --yes
        done
        echo "    ✓ All webhooks deleted"
    else
        echo "    - No webhooks found"
    fi
    
    # Delete all tokens
    echo "  Deleting all tokens..."
    TOKENS=$(az acr token list --registry $ACR_NAME --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$TOKENS" ]; then
        for token in $TOKENS; do
            echo "    Deleting token: $token"
            az acr token delete --name $token --registry $ACR_NAME --yes
        done
        echo "    ✓ All tokens deleted"
    else
        echo "    - No tokens found"
    fi
    
    # Delete all scope maps
    echo "  Deleting all scope maps..."
    SCOPE_MAPS=$(az acr scope-map list --registry $ACR_NAME --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$SCOPE_MAPS" ]; then
        for scope_map in $SCOPE_MAPS; do
            echo "    Deleting scope map: $scope_map"
            az acr scope-map delete --name $scope_map --registry $ACR_NAME --yes
        done
        echo "    ✓ All scope maps deleted"
    else
        echo "    - No scope maps found"
    fi
    
    # Delete all credential sets
    echo "  Deleting all credential sets..."
    CREDENTIAL_SETS=$(az acr credential-set list --registry $ACR_NAME --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$CREDENTIAL_SETS" ]; then
        for cred_set in $CREDENTIAL_SETS; do
            echo "    Deleting credential set: $cred_set"
            az acr credential-set delete --name $cred_set --registry $ACR_NAME --yes
        done
        echo "    ✓ All credential sets deleted"
    else
        echo "    - No credential sets found"
    fi
    
    # Delete all connected registries
    echo "  Deleting all connected registries..."
    CONNECTED_REGISTRIES=$(az acr connected-registry list --registry $ACR_NAME --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$CONNECTED_REGISTRIES" ]; then
        for connected_reg in $CONNECTED_REGISTRIES; do
            echo "    Deleting connected registry: $connected_reg"
            az acr connected-registry delete --name $connected_reg --registry $ACR_NAME --yes
        done
        echo "    ✓ All connected registries deleted"
    else
        echo "    - No connected registries found"
    fi
    
    # Delete all agent pools
    echo "  Deleting all agent pools..."
    AGENT_POOLS=$(az acr agentpool list --registry $ACR_NAME --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$AGENT_POOLS" ]; then
        for agent_pool in $AGENT_POOLS; do
            echo "    Deleting agent pool: $agent_pool"
            az acr agentpool delete --name $agent_pool --registry $ACR_NAME --yes
        done
        echo "    ✓ All agent pools deleted"
    else
        echo "    - No agent pools found"
    fi
    
    # Finally delete the registry itself
    echo "  Deleting the container registry..."
    az acr delete --name $ACR_NAME --resource-group $RESOURCE_GROUP --yes
    echo "✓ Azure Container Registry and all contents deleted"
else
    echo "- Azure Container Registry '$ACR_NAME' not found"
fi

# Delete Key Vault
echo "Deleting Key Vault..."
if az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP &>/dev/null; then
    az keyvault delete --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP
    echo "✓ Key Vault deleted"
else
    echo "- Key Vault '$KEY_VAULT_NAME' not found"
fi

# Delete any remaining container instances
echo "Deleting any remaining container instances..."
CONTAINER_INSTANCES=$(az container list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$CONTAINER_INSTANCES" ]; then
    for container in $CONTAINER_INSTANCES; do
        echo "  Deleting container instance: $container"
        az container delete --name $container --resource-group $RESOURCE_GROUP --yes
    done
    echo "✓ Container instances deleted"
else
    echo "- No container instances found"
fi

# Delete any remaining storage accounts
echo "Deleting any remaining storage accounts..."
STORAGE_ACCOUNTS=$(az storage account list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$STORAGE_ACCOUNTS" ]; then
    for storage in $STORAGE_ACCOUNTS; do
        echo "  Deleting storage account: $storage"
        az storage account delete --name $storage --resource-group $RESOURCE_GROUP --yes
    done
    echo "✓ Storage accounts deleted"
else
    echo "- No storage accounts found"
fi

# Delete any remaining network resources
echo "Deleting any remaining network resources..."
NETWORK_INTERFACES=$(az network nic list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$NETWORK_INTERFACES" ]; then
    for nic in $NETWORK_INTERFACES; do
        echo "  Deleting network interface: $nic"
        az network nic delete --name $nic --resource-group $RESOURCE_GROUP
    done
    echo "✓ Network interfaces deleted"
else
    echo "- No network interfaces found"
fi

# Delete any remaining public IPs
echo "Deleting any remaining public IPs..."
PUBLIC_IPS=$(az network public-ip list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$PUBLIC_IPS" ]; then
    for ip in $PUBLIC_IPS; do
        echo "  Deleting public IP: $ip"
        az network public-ip delete --name $ip --resource-group $RESOURCE_GROUP
    done
    echo "✓ Public IPs deleted"
else
    echo "- No public IPs found"
fi

# Delete any remaining virtual networks
echo "Deleting any remaining virtual networks..."
VNETS=$(az network vnet list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$VNETS" ]; then
    for vnet in $VNETS; do
        echo "  Deleting virtual network: $vnet"
        az network vnet delete --name $vnet --resource-group $RESOURCE_GROUP
    done
    echo "✓ Virtual networks deleted"
else
    echo "- No virtual networks found"
fi

# Delete any remaining security groups
echo "Deleting any remaining security groups..."
NSGS=$(az network nsg list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$NSGS" ]; then
    for nsg in $NSGS; do
        echo "  Deleting network security group: $nsg"
        az network nsg delete --name $nsg --resource-group $RESOURCE_GROUP
    done
    echo "✓ Network security groups deleted"
else
    echo "- No network security groups found"
fi

# Delete any remaining managed identities
echo "Deleting any remaining managed identities..."
MANAGED_IDENTITIES=$(az identity list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$MANAGED_IDENTITIES" ]; then
    for identity in $MANAGED_IDENTITIES; do
        echo "  Deleting managed identity: $identity"
        az identity delete --name $identity --resource-group $RESOURCE_GROUP
    done
    echo "✓ Managed identities deleted"
else
    echo "- No managed identities found"
fi

# Delete any remaining log analytics workspaces
echo "Deleting any remaining log analytics workspaces..."
WORKSPACES=$(az monitor log-analytics workspace list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$WORKSPACES" ]; then
    for workspace in $WORKSPACES; do
        echo "  Deleting log analytics workspace: $workspace"
        az monitor log-analytics workspace delete --workspace-name $workspace --resource-group $RESOURCE_GROUP --force
    done
    echo "✓ Log analytics workspaces deleted"
else
    echo "- No log analytics workspaces found"
fi

# Delete any remaining action groups
echo "Deleting any remaining action groups..."
ACTION_GROUPS=$(az monitor action-group list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$ACTION_GROUPS" ]; then
    for action_group in $ACTION_GROUPS; do
        echo "  Deleting action group: $action_group"
        az monitor action-group delete --name $action_group --resource-group $RESOURCE_GROUP
    done
    echo "✓ Action groups deleted"
else
    echo "- No action groups found"
fi

# Delete any remaining alert rules
echo "Deleting any remaining alert rules..."
ALERT_RULES=$(az monitor metrics alert list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$ALERT_RULES" ]; then
    for alert_rule in $ALERT_RULES; do
        echo "  Deleting alert rule: $alert_rule"
        az monitor metrics alert delete --name $alert_rule --resource-group $RESOURCE_GROUP
    done
    echo "✓ Alert rules deleted"
else
    echo "- No alert rules found"
fi

# Delete any remaining diagnostic settings
echo "Deleting any remaining diagnostic settings..."
DIAGNOSTIC_SETTINGS=$(az monitor diagnostic-settings list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$DIAGNOSTIC_SETTINGS" ]; then
    for diagnostic_setting in $DIAGNOSTIC_SETTINGS; do
        echo "  Deleting diagnostic setting: $diagnostic_setting"
        az monitor diagnostic-settings delete --name $diagnostic_setting --resource-group $RESOURCE_GROUP
    done
    echo "✓ Diagnostic settings deleted"
else
    echo "- No diagnostic settings found"
fi

# Delete any remaining role assignments
echo "Deleting any remaining role assignments..."
ROLE_ASSIGNMENTS=$(az role assignment list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$ROLE_ASSIGNMENTS" ]; then
    for role_assignment in $ROLE_ASSIGNMENTS; do
        echo "  Deleting role assignment: $role_assignment"
        az role assignment delete --name $role_assignment --resource-group $RESOURCE_GROUP
    done
    echo "✓ Role assignments deleted"
else
    echo "- No role assignments found"
fi

# Delete any remaining locks
echo "Deleting any remaining locks..."
LOCKS=$(az lock list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$LOCKS" ]; then
    for lock in $LOCKS; do
        echo "  Deleting lock: $lock"
        az lock delete --name $lock --resource-group $RESOURCE_GROUP
    done
    echo "✓ Locks deleted"
else
    echo "- No locks found"
fi

# Delete any remaining policies
echo "Deleting any remaining policies..."
POLICIES=$(az policy assignment list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$POLICIES" ]; then
    for policy in $POLICIES; do
        echo "  Deleting policy assignment: $policy"
        az policy assignment delete --name $policy --resource-group $RESOURCE_GROUP
    done
    echo "✓ Policy assignments deleted"
else
    echo "- No policy assignments found"
fi

# Delete any remaining deployments
echo "Deleting any remaining deployments..."
DEPLOYMENTS=$(az deployment group list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$DEPLOYMENTS" ]; then
    for deployment in $DEPLOYMENTS; do
        echo "  Deleting deployment: $deployment"
        az deployment group delete --name $deployment --resource-group $RESOURCE_GROUP
    done
    echo "✓ Deployments deleted"
else
    echo "- No deployments found"
fi

# Delete any remaining resources (catch-all)
echo "Deleting any remaining resources..."
REMAINING_RESOURCES=$(az resource list --resource-group $RESOURCE_GROUP --query "[].name" --output tsv 2>/dev/null || echo "")
if [ -n "$REMAINING_RESOURCES" ]; then
    echo "  Found remaining resources: $REMAINING_RESOURCES"
    for resource in $REMAINING_RESOURCES; do
        echo "  Deleting resource: $resource"
        RESOURCE_TYPE=$(az resource show --name $resource --resource-group $RESOURCE_GROUP --query type --output tsv 2>/dev/null || echo "")
        if [ -n "$RESOURCE_TYPE" ]; then
            az resource delete --name $resource --resource-group $RESOURCE_GROUP --resource-type $RESOURCE_TYPE
        else
            echo "    Warning: Could not determine resource type for $resource"
        fi
    done
    echo "✓ Remaining resources deleted"
else
    echo "- No remaining resources found"
fi

# Finally, delete the resource group
echo ""
echo "Deleting resource group: $RESOURCE_GROUP"
az group delete --name $RESOURCE_GROUP --yes --no-wait
echo "✓ Resource group deletion initiated"

# Clean up service principal
echo ""
echo "Cleaning up service principal..."
SERVICE_PRINCIPAL_ID=$(az ad sp list --display-name $SERVICE_PRINCIPAL_NAME --query "[0].appId" --output tsv 2>/dev/null || echo "")
if [ -n "$SERVICE_PRINCIPAL_ID" ] && [ "$SERVICE_PRINCIPAL_ID" != "null" ]; then
    echo "  Deleting service principal: $SERVICE_PRINCIPAL_NAME"
    az ad sp delete --id $SERVICE_PRINCIPAL_ID
    echo "✓ Service principal deleted"
else
    echo "- Service principal '$SERVICE_PRINCIPAL_NAME' not found"
fi

echo ""
echo "=== Azure Resources Teardown Complete ==="
echo ""
echo "All resources have been deleted or marked for deletion."
echo "Resource group deletion is running in the background."
echo ""
echo "Note: Some resources may take a few minutes to be completely removed."
echo "You can check the status with: az group show --name $RESOURCE_GROUP"
