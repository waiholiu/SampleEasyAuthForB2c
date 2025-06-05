@description('Name of the App Service')
param appServiceName string = 'b2c-auth-webapp'

@description('App Service Plan name')
param appServicePlanName string = 'b2c-auth-plan'

@description('Location')
param location string = resourceGroup().location

@description('Azure AD B2C Client ID')
param b2cClientId string = '0d605263-7925-47cc-93b9-dfbd2f415953'

@description('OpenID Connect metadata endpoint (Azure AD B2C)')
param b2cOpenIdConfigUrl string = 'https://dohactestb2c.b2clogin.com/dohactestb2c.onmicrosoft.com/B2C_1_SSBA_SANDBOX2/v2.0/.well-known/openid-configuration'


var keyVaultName = 'kvvwaf002'

resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: 'vnet'
  location: 'australiaeast'
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'kv-subnet'
        properties: {
          addressPrefix: '10.0.0.0/24'

        }
      }
      {
        name: 'appSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          delegations: [
            {
              name: 'Microsoft.Web/serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}





var hostingPlan = {
  name: appServicePlanName
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: hostingPlan.name
  location: location
  sku: hostingPlan.sku
  kind: hostingPlan.kind
  properties: hostingPlan.properties
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|6.0'
    }
    httpsOnly: true
    virtualNetworkSubnetId: vnet.properties.subnets[1].id
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource authSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  name: 'authsettingsV2'
  parent: webApp
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'b2c'
      
      
    }
    identityProviders: {
      customOpenIdConnectProviders: {
        b2c: {
          enabled: true
          registration: {
            clientId: b2cClientId
            clientCredential: {
              clientSecretSettingName: 'B2C_CLIENT_SECRET'
            }
            openIdConnectConfiguration: {
              wellKnownOpenIdConfiguration: b2cOpenIdConfigUrl
            }
          }
        }
      }
    }
  }
}

resource appSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  name: '${webApp.name}/appsettings'
  properties: {
    'B2C_CLIENT_SECRET': '@Microsoft.KeyVault(SecretUri=https://${vault.outputs.name}.vault.azure.net/secrets/B2CCLIENTSECRET)'
  }
}

module vault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'vaultDeployment'
  params: {
    // Required parameters
    name: keyVaultName
    // Non-required parameters
    enablePurgeProtection: false
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      
    }
    enableVaultForDeployment:false
    enableVaultForTemplateDeployment: false
    enableVaultForDiskEncryption: false
    enableSoftDelete: false
    
    // privateEndpoints: [
    //   {
    //     privateDnsZoneGroup: {
    //       privateDnsZoneGroupConfigs: [
    //         {
    //           privateDnsZoneResourceId: '<privateDnsZoneResourceId>'
    //         }
    //       ]
    //     }
    //     service: 'vault'
    //     subnetResourceId: '<subnetResourceId>'
    //   }
    // ]
    // secrets: [
    //   {
    //     attributes: {
    //       enabled: true
    //       exp: 1702648632
    //       nbf: 10000
    //     }
    //     contentType: 'Something'
    //     name: 'secretName'
    //     value: 'secretValue'
    //   }
    // ]
    softDeleteRetentionInDays: 7
    // tags: {
    //   Environment: 'Non-Prod'
    //   'hidden-title': 'This is visible in the resource name'
    //   Role: 'DeploymentValidation'
    // }
    roleAssignments: [
      {
        principalId: webApp.identity.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
      {
        principalId: 'b3e80875-7e77-48aa-b9dc-249e7dde66e9' // Replace with actual object ID
        principalType: 'User'
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
      }


    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${vault.name}-pe'
  location: 'australiaeast'
  properties: {
    subnet: {
      id: vnet.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-connection'
        properties: {
          privateLinkServiceId: vault.outputs.resourceId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}




module vaultDns './privateDnsZone.bicep' = {
  name: 'vaultDns'
  scope: resourceGroup()
  params: { 
    vnetName: 'vnet'
    vnetResourceGroup: resourceGroup().name
    privateEndpointName: '${vault.name}-pe'
    domainName: 'vaultcore.azure.net'
   }
}
