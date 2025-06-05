param vnetName string
param vnetResourceGroup string
param privateEndpointName string
param domainName string
 
 
resource existingVnet 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}
 
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' existing = {
  name: privateEndpointName //${sqlServerName}-pe'
}
 
 
// set up the sql Private DNS Zones
// Private DNS zone azurewebsite.net
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  // name: 'privatelink.database.windows.net'
  name: 'privatelink.${domainName}'
  location: 'global'
  properties: {}
}
 
// add in records on the private dnz zone from the sql private endpoint
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: '${privateEndpoint.name}-dns-zone-group'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.${domainName}'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}
 
 
// // Link the SQL Private DNS zone to the VNet
resource privateDnsZoneSqlVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: '${privateDnsZone.name}-${existingVnet.name}-link'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: existingVnet.id
    }
    registrationEnabled: false
  }
}
