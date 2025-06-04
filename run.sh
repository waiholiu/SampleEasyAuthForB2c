az group create --name todelappwithauth --location australiaeast
az deployment group create \
  --resource-group todelappwithauth \
  --template-file test.bicep \
  --parameters b2cClientSecret=''