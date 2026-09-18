@description('Azure region for OJAS Search resources.')
param location string = resourceGroup().location

@description('Set true only when you intentionally want to provision the paid Azure AI Search service.')
param deploySearchService bool = false

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

@description('Optional Microsoft Entra principal used by the deployment pipeline for Search object management.')
param deploymentPrincipalId string = ''

resource searchService 'Microsoft.Search/searchServices@2025-05-01' = if (deploySearchService) {
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
    disableLocalAuth: true
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

output endpoint string = deploySearchService
  ? searchService.properties.endpoint
  : ''

output principalId string = deploySearchService
  ? searchService.identity.principalId
  : ''

resource searchApiReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySearchService && !empty(searchApiPrincipalId)) {
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

resource searchDeploymentServiceContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySearchService && !empty(deploymentPrincipalId)) {
  name: guid(searchService.id, deploymentPrincipalId, 'ojas-search-deployment-contributor')
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7cae816b-3f29-4b8c-8d5d-6f55b6d8af87'
    )
    principalId: deploymentPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource searchWorkerContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploySearchService && !empty(searchWorkerPrincipalId)) {
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
