@description('Azure region for OJAS Search resources.')
param location string = resourceGroup().location

@description('Globally unique Azure AI Search service name.')
param searchServiceName string

@description('Azure AI Search SKU. This is a deployment choice and can create Azure charges.')
@allowed([
  'basic'
  'standard'
  'standard2'
  'standard3'
])
param searchSku string = 'basic'

@description('Search replicas. Start at 1 and increase for availability/throughput.')
param replicaCount int = 1

@description('Search partitions. Start at 1 and increase for corpus/throughput.')
param partitionCount int = 1

resource searchService 'Microsoft.Search/searchServices@2025-05-01' = {
  name: searchServiceName
  location: location
  sku: {
    name: searchSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http403'
      }
    }
    disableLocalAuth: false
    hostingMode: 'default'
    networkRuleSet: {
      bypass: 'AzureServices'
      ipRules: []
    }
    partitionCount: partitionCount
    publicNetworkAccess: 'Enabled'
    replicaCount: replicaCount
  }
  tags: {
    app: 'ojas'
    subsystem: 'search'
  }
}

output endpoint string = searchService.properties.endpoint
output principalId string = searchService.identity.principalId
