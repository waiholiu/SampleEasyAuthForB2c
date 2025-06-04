@description('Name of the App Service')
param appServiceName string = 'b2c-auth-webapp'

@description('App Service Plan name')
param appServicePlanName string = 'b2c-auth-plan'

@description('Location')
param location string = resourceGroup().location

@description('Azure AD B2C Client ID')
param b2cClientId string = '5dd13c83-c0ad-4443-a894-6d79d83c4a68'

@secure()
@description('Azure AD B2C Client Secret (stored securely)')
param b2cClientSecret string

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
      unauthenticatedClientAction: 'Return401'
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
    'B2C_CLIENT_SECRET': b2cClientSecret
  }
}
