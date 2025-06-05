



// resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
//   name: keyVaultName
//   location: location
//   properties: {
//     sku: {
//       family: 'A'
//       name: 'standard'
//     }
//     tenantId: subscription().tenantId
//     accessPolicies: [
//       {
//         tenantId: subscription().tenantId
//         objectId: webApp.identity.principalId
//         permissions: {
//           secrets: [
//             'get'
//             'list'
//           ]
//         }
//       }
//     ]
//     enableSoftDelete: true
//     enablePurgeProtection: false
//     networkAcls: {
//       bypass: 'None'
//       defaultAction: 'Deny'
//       virtualNetworkRules: [
//         {
//           id: vnet.properties.subnets[0].id
//         }
//       ]
//     }
//   }
// }

// resource webApp 'Microsoft.Web/sites@2023-01-01' = {
//   name: appServiceName
//   location: location
//   kind: 'app,linux'
//   identity: {
//     type: 'SystemAssigned'
//   }
//   properties: {
//     serverFarmId: appServicePlan.id
//     siteConfig: {
//       linuxFxVersion: 'DOTNETCORE|6.0'
//     }
//     httpsOnly: true
//   }
// }
