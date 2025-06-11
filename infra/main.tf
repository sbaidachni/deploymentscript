resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_virtual_network" "main" {
  name                = "main-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "main" {
  name                 = "main-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "aci-delegation"
    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account_network_rules" "example" {
  storage_account_id = azurerm_storage_account.example.id

  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  virtual_network_subnet_ids = [azurerm_subnet.main.id]
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id  = azurerm_storage_account.example.id
  container_access_type = "private"
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_user_assigned_identity" "script_identity" {
  name                = "deployment-script-identity"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_storage_account.example.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

resource "azurerm_role_assignment" "file_data_privileged_contributor" {
  scope                = azurerm_storage_account.example.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

data "azurerm_client_config" "current" {}

# Container Registry Tasks Contributor
resource "azurerm_role_assignment" "acr_contributor" {
  scope                = azurerm_container_registry.acr.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/fb382eab-e894-4461-af04-94435c366c3f"
  principal_id         = azurerm_user_assigned_identity.script_identity.principal_id
}

resource "azapi_resource" "run_python_from_github" {
  type = "Microsoft.Resources/deploymentScripts@2023-08-01"
  name                = "run-python-from-github"
  location            = azurerm_resource_group.example.location
  parent_id           = azurerm_resource_group.example.id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.script_identity.id]
  }

  body = {
    kind = "AzureCLI"
    properties = {
      azCliVersion = "2.45.0"
      retentionInterval  = "P1D"
      cleanupPreference = "OnSuccess"
      timeout            = "PT15M"
      storageAccountSettings = {
        storageAccountName = azurerm_storage_account.example.name
      }
      containerSettings = {
        subnetIds = [
          {
            id = "${azurerm_subnet.main.id}"
          }
        ]
      }
      scriptContent = <<EOF
        echo "Cloning private GitHub repo..."
        git clone --branch sbaidachni/testacr https://github.com/sbaidachni/deploymentscript.git repo
        cd repo
        cd data
        pip install -r requirements.txt
        python -m upload_data --storage_name $STORAGE_ACCOUNT_NAME --container_name data
        cd ../.buildcontainer
        az acr login -n $ACR_NAME --expose-token
        echo "Hello"
        az acr build -r $ACR_NAME -t sample/myimage .
        cd ../src/search
        pip install -r requirements.txt
      EOF
      environmentVariables = [
        {
          name = "STORAGE_ACCOUNT_NAME"
          value = "${azurerm_storage_account.example.name}"
        },
        {
          name = "ACR_NAME"
          value = "${azurerm_container_registry.acr.name}"
        }
      ]  
    }
  }
}
