@description('Azure region for the OJAS Search backend.')
param location string = resourceGroup().location

@description('Explicitly opt in before provisioning paid backend resources.')
param deployBackend bool = false

@description('Globally unique storage account name, 3-24 lowercase alphanumeric.')
param storageAccountName string

@description('Globally unique Function App name.')
param functionAppName string

@description('Service Bus namespace name.')
param serviceBusNamespaceName string

@description('Function App Flex Consumption plan name.')
param functionAppPlanName string

@description('Service Bus queue used for search index events.')
param indexQueueName string = 'ojas-search-index-events'

@description('Service Bus queue used for search analytics events.')
param analyticsQueueName string = 'ojas-search-events'

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = if (deployBackend) {
  name: functionAppName
  location: location
  properties: {
    retentionInDays: 30
    features: 'EnableLogAccessUsingOnlyResourcePermissions'
  }
  tags: {
    app: 'ojas'
    subsystem: 'search'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (deployBackend) {
  name: functionAppName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = if (deployBackend) {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false
  }
}

resource storageBlob 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = if (deployBackend) {
  name: 'default'
  parent: storage
}

resource deploymentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = if (deployBackend) {
  name: 'deployments'
  parent: storageBlob
  properties: {
    publicAccess: 'None'
  }
}

resource functionPlan 'Microsoft.Web/serverfarms@2024-04-01' = if (deployBackend) {
  name: functionAppPlanName
  location: location
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = if (deployBackend) {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: functionPlan.id
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}deployments'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      runtime: {
        name: 'node'
        version: '20'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 50
        instanceMemoryMB: 2048
      }
    }
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'SEARCH_SERVICE_BUS_CONNECTION__fullyQualifiedNamespace'
          value: '${serviceBusNamespaceName}.servicebus.windows.net'
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' = if (deployBackend) {
  name: serviceBusNamespaceName
  location: location
  sku: {
    capacity: 0
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
    zoneRedundant: false
  }
}

resource indexQueue 'Microsoft.ServiceBus/namespaces/queues@2026-01-01' = if (deployBackend) {
  parent: serviceBus
  name: indexQueueName
  properties: {
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: true
    maxDeliveryCount: 10
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    status: 'Active'
  }
}

resource analyticsQueue 'Microsoft.ServiceBus/namespaces/queues@2026-01-01' = if (deployBackend) {
  parent: serviceBus
  name: analyticsQueueName
  properties: {
    enableBatchedOperations: true
    enableExpress: false
    enablePartitioning: true
    maxDeliveryCount: 10
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    status: 'Active'
  }
}

// Storage Blob Data Owner for the Function App identity.
// This keeps the deployment/runtime storage path compatible with identity-based connections.
resource functionStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployBackend) {
  name: guid(storage.id, functionApp.identity.principalId, 'ojas-function-storage')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    )
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Service Bus Data Sender for the Function App identity.
// Add Service Bus Data Receiver as a separate role if the trigger connection is switched to identity-based runtime auth in Azure.
resource functionServiceBusSenderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployBackend) {
  name: guid(serviceBus.id, functionApp.identity.principalId, 'ojas-function-servicebus-sender')
  scope: serviceBus
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    )
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output functionHostName string = deployBackend
  ? functionApp.properties.defaultHostName
  : ''

output serviceBusFqdn string = deployBackend
  ? '${serviceBusNamespaceName}.servicebus.windows.net'
  : ''


resource functionServiceBusReceiverRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployBackend) {
  name: guid(serviceBus.id, functionApp.identity.principalId, 'ojas-function-servicebus-receiver')
  scope: serviceBus
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
    )
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
