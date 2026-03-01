terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "databricks" {
  host                        = azurerm_databricks_workspace.workspace.workspace_url
  azure_workspace_resource_id = azurerm_databricks_workspace.workspace.id
}

resource "azurerm_resource_group" "rg" {
  name     = "rg_ag_databrick"
  location = "Central India"
}

resource "azurerm_databricks_workspace" "workspace" {
  name                = "databricks_ws_ag"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "premium"
}

resource "azurerm_storage_account" "sa" {
  name                     = "agstacc"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "container" {
  name                  = "ag-ct"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_share" "fs" {
  name                 = "ag-fs"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 50
}

resource "azurerm_databricks_access_connector" "ext_access_connector" {
  name                = "ext-access-connector"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "ext_storage_role" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ext_access_connector.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_databricks_access_connector.ext_access_connector.identity[0].principal_id
}

resource "azurerm_role_assignment" "storage_queue_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_databricks_access_connector.ext_access_connector.identity[0].principal_id
}

resource "azurerm_role_assignment" "eventgrid_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "EventGrid EventSubscription Contributor"
  principal_id         = azurerm_databricks_access_connector.ext_access_connector.identity[0].principal_id
}

resource "azurerm_storage_container" "metastore_container" {
  name                  = "metastore-root"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "databricks_metastore" "metastore" {
  name = "primary-metastore"
  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_container.metastore_container.name,
    azurerm_storage_account.sa.name)
  force_destroy = true
}

resource "databricks_metastore_data_access" "metastore_data_access" {
  metastore_id = databricks_metastore.metastore.id
  name         = "mi_dac"
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.ext_access_connector.id
  }
  is_default = true
  depends_on = [
    azurerm_role_assignment.ext_storage_role
  ]
}
