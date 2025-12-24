terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
  
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

# Variables
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

variable "resource_group_name" {
  default = "azure-deploy-rg"
}

variable "location" {
  default = "centralindia"
}

variable "sql_server_name" {
  default = "azure-deploy-sql"
}

variable "sql_database_name" {
  default = "azure-deploy-db"
}

variable "sql_admin_login" {
  default = "sqladmin"
}

variable "sql_admin_password" {}

variable "app_service_plan_name" {
  default = "azure-deploy-plan"
}

variable "web_app_name" {
  default = "azure-deploy-webapp"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.main.id
  sku_name  = "Basic"
}

# Firewall Rule - Allow Azure Services
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Windows"
  sku_name            = "B1"
}

# Web App
resource "azurerm_windows_web_app" "main" {
  name                = var.web_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      dotnet_version = "v8.0"
    }
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};User ID=${var.sql_admin_login};Password=${var.sql_admin_password};Encrypt=true;Connection Timeout=30;"
  }
}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "web_app_url" {
  value = "https://${azurerm_windows_web_app.main.default_hostname}"
}

output "web_app_name" {
  value = azurerm_windows_web_app.main.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "connection_string" {
  value     = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};User ID=${var.sql_admin_login};Password=${var.sql_admin_password};Encrypt=true;Connection Timeout=30;"
  sensitive = true
}
