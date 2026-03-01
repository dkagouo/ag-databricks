terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
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
