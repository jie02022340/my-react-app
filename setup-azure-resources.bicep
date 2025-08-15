@description('The name of the resource group')
param resourceGroupName string = 'my-react-app-rg'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The name of the Azure Container Registry')
param acrName string = 'myreactappacr'

@description('The name of the Key Vault')
param keyVaultName string = 'my-react-app-kv'

@description('The name of the Application Insights')
param appInsightsName string = 'my-react-app-insights'

@description('The name of the service principal')
param servicePrincipalName string = 'my-react-app-sp'

@description('Environment name (dev, staging, prod)')
param environment string = 'dev'

@description('Tags to apply to all resources')
param tags object = {
  environment: environment
  project: 'my-react-app'
  managedBy: 'bicep'
}

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
  tags: tags
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  tags: tags
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${appInsightsName}-workspace'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

// Service Principal (using deployment script)
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'create-service-principal'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '7.0'
    retentionInterval: 'P1D'
    scriptContent: '''
      # Create service principal
      $sp = az ad sp create-for-rbac --name "${servicePrincipalName}" --role contributor --scopes /subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroupName} --sdk-auth
      
      # Output the service principal details
      Write-Output "Service Principal created successfully"
      Write-Output $sp
      
      # Store in Key Vault
      $spObject = $sp | ConvertFrom-Json
      az keyvault secret set --vault-name "${keyVaultName}" --name "ServicePrincipal-AppId" --value $spObject.clientId
      az keyvault secret set --vault-name "${keyVaultName}" --name "ServicePrincipal-Password" --value $spObject.clientSecret
      az keyvault secret set --vault-name "${keyVaultName}" --name "ServicePrincipal-TenantId" --value $spObject.tenantId
    '''
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: '1'
  }
  tags: tags
}

// Key Vault Secrets
resource apiUrlSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'API-URL'
  properties: {
    value: 'https://your-api-endpoint.com'
    contentType: 'text/plain'
  }
}

resource databaseUrlSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'DATABASE-URL'
  properties: {
    value: 'postgresql://username:password@host:port/database'
    contentType: 'text/plain'
  }
}

resource jwtSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'JWT-SECRET'
  properties: {
    value: 'your-jwt-secret-here'
    contentType: 'text/plain'
  }
}

resource appInsightsKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'APP-INSIGHTS-KEY'
  properties: {
    value: appInsights.properties.InstrumentationKey
    contentType: 'text/plain'
  }
}

// Role assignments for service principal
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, 'AcrPush')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-74d2-4704-8204-4c21d56be8c1') // AcrPush
    principalId: deploymentScript.properties.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: deploymentScript.properties.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Network Security Group for container instances
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'my-react-app-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 1001
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
  tags: tags
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'my-react-app-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
  tags: tags
}

// Storage Account for build artifacts
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'myreactappstorage${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  tags: tags
}

// Container for build artifacts
resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: storageAccount::blob
  name: 'build-artifacts'
  properties: {
    publicAccess: 'None'
  }
}

// Action Group for monitoring alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'my-react-app-action-group'
  location: 'Global'
  properties: {
    groupShortName: 'ReactApp'
    enabled: true
    emailReceivers: [
      {
        name: 'admin'
        emailAddress: 'admin@yourcompany.com'
        useCommonAlertSchema: true
      }
    ]
  }
  tags: tags
}

// Alert rule for high CPU usage
resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'high-cpu-alert'
  location: 'Global'
  properties: {
    description: 'Alert when CPU usage is high'
    severity: 2
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'exceptions/count'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  tags: tags
}

// Outputs
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output keyVaultName string = keyVault.name
output appInsightsKey string = appInsights.properties.InstrumentationKey
output appInsightsName string = appInsights.name
output storageAccountName string = storageAccount.name
output vnetName string = vnet.name
output nsgName string = nsg.name
output resourceGroupName string = resourceGroupName
output location string = location

// Output service principal details (from deployment script)
output servicePrincipalDetails object = {
  appId: deploymentScript.properties.outputs.appId
  password: deploymentScript.properties.outputs.password
  tenantId: deploymentScript.properties.outputs.tenantId
}
