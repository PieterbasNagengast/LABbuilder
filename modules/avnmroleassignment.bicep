param principalID string
@allowed([
  'ServicePrincipal'
  'Group'
  'User'
  'ForeignGroup'
])
param principalType string = 'ServicePrincipal'
param roleID string = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor: b24988ac-6180-42a0-ab88-20f7382dd24c
param avnmName string

resource avnmExisting 'Microsoft.Network/networkManagers@2022-11-01' existing = {
  name: avnmName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: avnmExisting
  name: guid(resourceGroup().id, principalID)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleID)
    principalId: principalID
    principalType: principalType
  }
}

output id string = roleAssignment.id
