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

variable "app_name" {
  type        = string
  description = "Application name (used for resource naming)"
}

variable "location" {
  type    = string
  default = "Central India"
}

variable "sql_admin_password" {
  type        = string
  description = "SQL Server admin password (optional - if not provided, SQL Server won't be created)"
  default     = ""
  sensitive   = true
}

locals {
  resource_prefix = replace(
    replace(lower(var.app_name), "_", "-"),
    ".",
    "-"
  )
  create_sql_server  = var.sql_admin_password != ""
  resource_group_name = "${local.resource_prefix}-rg"
}

# Check if resource group already exists
data "azurerm_resource_group" "existing" {
  count = 1
  name  = local.resource_group_name
}

# Resource Group - only create if it doesn't exist
resource "azurerm_resource_group" "main" {
  count    = length(data.azurerm_resource_group.existing) == 0 ? 1 : 0
  name     = local.resource_group_name
  location = var.location
}

locals {
  # Use existing resource group if found, otherwise use the newly created one
  rg_name     = try(data.azurerm_resource_group.existing[0].name, azurerm_resource_group.main[0].name)
  rg_location = try(data.azurerm_resource_group.existing[0].location, azurerm_resource_group.main[0].location)
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${local.resource_prefix}-plan"
  location            = local.rg_location
  resource_group_name = local.rg_name
  os_type             = "Windows"
  sku_name            = "F1"
}

# Windows Web App
resource "azurerm_windows_web_app" "main" {
  name                = "${local.resource_prefix}-webapp"
  location            = local.rg_location
  resource_group_name = local.rg_name
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = false
    application_stack {
      dotnet_version = "v8.0"
    }
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Production"
  }
}

# SQL Server (conditional)
resource "azurerm_mssql_server" "main" {
  count                        = local.create_sql_server ? 1 : 0
  name                         = "${local.resource_prefix}-sqlserver"
  resource_group_name          = local.rg_name
  location                     = local.rg_location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password
}

# SQL Database (conditional)
resource "azurerm_mssql_database" "main" {
  count     = local.create_sql_server ? 1 : 0
  name      = "${local.resource_prefix}-db"
  server_id = azurerm_mssql_server.main[0].id
  sku_name  = "Basic"
}

# SQL Server Firewall Rule - Allow Azure Services (conditional)
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  count            = local.create_sql_server ? 1 : 0
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Outputs
output "resource_group" {
  value = local.rg_name
}

output "webapp_name" {
  value = azurerm_windows_web_app.main.name
}

output "webapp_url" {
  value = "https://${azurerm_windows_web_app.main.default_hostname}"
}
