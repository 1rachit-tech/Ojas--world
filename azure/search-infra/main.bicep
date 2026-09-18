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

@description('Optional Microsoft Entra service principal object ID for the Search API. Empty means no role assignment is created.')
param searchApiPrincipalId string = ''

@description('Optional Microsoft Entra service principal object ID for the indexing worker. Empty means no role assignment is created.')
param searchWorkerPrincipalId string = ''

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

resource searchApiReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(searchApiPrincipalId)) {
  name: guid(searchService.id, searchApiPrincipalId, 'ojas-search-reader')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '1407120a-92aa-4202-b7e9-c0e197c71c8f'
    )
    principalId: searchApiPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource searchWorkerContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(searchWorkerPrincipalId)) {
  name: guid(searchService.id, searchWorkerPrincipalId, 'ojas-search-contributor')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    )
    principalId: searchWorkerPrincipalId
    principalType: 'ServicePrincipal'
  }
}
