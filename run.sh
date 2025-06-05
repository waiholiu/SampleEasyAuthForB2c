az group create --name todelappwithauth2 --location australiaeast
az deployment group create \
  --resource-group todelappwithauth2 \
  --template-file test.bicep \