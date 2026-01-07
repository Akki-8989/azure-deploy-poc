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
  subscription_id = var.subscription_id
}

# Variables
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "app_name" {
  type        = string
  description = "Application name for resource naming"
}

variable "create_sql_server" {
  type        = bool
  default     = false
  description = "Whether to create SQL Server and Database"
}

variable "sql_admin_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SQL Server admin password (required if create_sql_server is true)"
}

variable "location" {
  type    = string
  default = "Central India"
}

# Local variables for naming
locals {
  resource_name = lower(replace(var.app_name, ".", "-"))
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${local.resource_name}-rg"
  location = var.location
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${local.resource_name}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Windows"
  sku_name            = "F1"
}

# Web App
resource "azurerm_windows_web_app" "main" {
  name                = "${local.resource_name}-webapp"
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
}

# SQL Server (Conditional)
resource "azurerm_mssql_server" "main" {
  count                        = var.create_sql_server ? 1 : 0
  name                         = "${local.resource_name}-sqlserver"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password
}

# SQL Database (Conditional)
resource "azurerm_mssql_database" "main" {
  count     = var.create_sql_server ? 1 : 0
  name      = "${local.resource_name}-db"
  server_id = azurerm_mssql_server.main[0].id
  sku_name  = "Basic"
}

# SQL Firewall Rule - Allow Azure Services (Conditional)
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  count            = var.create_sql_server ? 1 : 0
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Outputs
output "webapp_name" {
  value = azurerm_windows_web_app.main.name
}

output "webapp_url" {
  value = "https://${azurerm_windows_web_app.main.default_hostname}"
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "sql_created" {
  value = var.create_sql_server
}

output "sql_server_fqdn" {
  description = "SQL Server fully qualified domain name"
  value       = var.create_sql_server ? azurerm_mssql_server.main[0].fully_qualified_domain_name : ""
}

output "sql_database_name" {
  description = "SQL Database name"
  value       = var.create_sql_server ? azurerm_mssql_database.main[0].name : ""
}
