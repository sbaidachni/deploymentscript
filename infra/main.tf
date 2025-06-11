resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = true
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}

resource "azurerm_search_service" "ai_search" {
  name                = var.ai_search_name
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "basic"
  partition_count     = 1
  replica_count       = 1

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "ai_search_blob_data_contributor" {
  scope                = azurerm_storage_account.example.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
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
      storageAccountSettings = {
        storageAccountName = azurerm_storage_account.example.name
      }
      azCliVersion = "2.45.0"
      retentionInterval  = "P1D"
      cleanupPreference = "OnSuccess"
      timeout            = "PT15M"
      scriptContent = <<EOF
        echo "Cloning private GitHub repo..."
        git clone https://github.com/sbaidachni/deploymentscript.git repo
        cd repo
        cd data
        pip install -r requirements.txt
        python -m upload_data --storage_name $STORAGE_ACCOUNT_NAME --container_name data
        cd ../src/search
        pip install -r requirements.txt
      EOF
      environmentVariables = [
        {
          name = "STORAGE_ACCOUNT_NAME"
          value = "${azurerm_storage_account.example.name}"
        }
      ]  
    }
  }
}
