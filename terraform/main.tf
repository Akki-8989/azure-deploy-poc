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
  resource_prefix    = replace(lower(var.app_name), ".", "-")
  create_sql_server  = var.sql_admin_password != ""
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${local.resource_prefix}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Windows"
  sku_name            = "F1"

  depends_on = [azurerm_resource_group.main]
}

# Windows Web App
resource "azurerm_windows_web_app" "main" {
  name                = "${local.resource_prefix}-webapp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
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

  depends_on = [
    azurerm_resource_group.main,
    azurerm_service_plan.main
  ]
}

# SQL Server (conditional)
resource "azurerm_mssql_server" "main" {
  count                        = local.create_sql_server ? 1 : 0
  name                         = "${local.resource_prefix}-sqlserver"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password

  depends_on = [azurerm_resource_group.main]
}

# SQL Database (conditional)
resource "azurerm_mssql_database" "main" {
  count     = local.create_sql_server ? 1 : 0
  name      = "${local.resource_prefix}-db"
  server_id = azurerm_mssql_server.main[0].id
  sku_name  = "Basic"

  depends_on = [
    azurerm_resource_group.main,
    azurerm_mssql_server.main
  ]
}

# SQL Server Firewall Rule - Allow Azure Services (conditional)
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  count            = local.create_sql_server ? 1 : 0
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"

  depends_on = [azurerm_mssql_server.main]
}

# Outputs
output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "webapp_name" {
  value = azurerm_windows_web_app.main.name
}

output "webapp_url" {
  value = "https://${azurerm_windows_web_app.main.default_hostname}"
}

# Remove SQL outputs completely to avoid sensitive value issues
# The connection info can be constructed from the naming convention:
# Server: {app_name}-sqlserver.database.windows.net
# Database: {app_name}-db
