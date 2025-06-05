@description('Name of the App Service')
param appServiceName string = 'b2c-auth-webapp'

@description('App Service Plan name')
param appServicePlanName string = 'b2c-auth-plan'

@description('Location')
param location string = resourceGroup().location

@description('Azure AD B2C Client ID')
param b2cClientId string = '5dd13c83-c0ad-4443-a894-6d79d83c4a68'


@description('OpenID Connect metadata endpoint (Azure AD B2C)')
param b2cOpenIdConfigUrl string = 'https://dohactestb2c.b2clogin.com/dohactestb2c.onmicrosoft.com/B2C_1_SSBA_SANDBOX2/v2.0/.well-known/openid-configuration'

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
    name: 'kvvwaf002'
    // Non-required parameters
    enablePurgeProtection: false
    enableRbacAuthorization: true
    // networkAcls: {
    //   bypass: 'AzureServices'
    //   defaultAction: 'Deny'
    // }
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
    ]
  }
}



