terraform {
  required_version = ">= 0.12.0"
}
provider "azurerm" {
  version = "~> 1.28"
}
provider "external" {
  version = "~> 1.1"
}
provider "null" {
  version = "~> 2.1"
}

locals {
  #Default to the folder name if no name is specified
  default_name_prefix = "${
    path.module != "."
      ? basename(path.module) 
      : basename(path.cwd)
  }"
  name_prefix = "${
    var.name != "default"
      ? var.name 
      : local.default_name_prefix
  }"

  #If the workspace is not named "default", add it as a suffix
  name_suffix = "${
    var.name_suffix != null
      ? var.name_suffix
      : terraform.workspace != "default"
        ? "-${terraform.workspace}"
        : ""
  }"

  #If a resource Group was specified, use that for the group name
  resource_group_name = "${
    var.resource_group_name != ""
    ? var.resource_group_name
    : "${local.name_prefix}${local.name_suffix}"
  }"

  resource_group = "${
    var.resource_group != null
    ? var.resource_group
    : azurerm_resource_group.this[0]
  }"

  #if a resource group was specified, don't create the default resource
  #create_resource_group = "${var.resource_group_name != "" ? 0 : 1}"

  #If a storage account resource group override was provided, use that, otherwise use the standard resource group name
  # storage_account_resource_group_name = "${
  #   var.storage_account_resource_group_name != ""
  #   ? var.storage_account_resource_group_name
  #   : local.resource_group_name
  # }"
}

resource "azurerm_resource_group" "this" {
  count    = var.resource_group != null ? 0 : 1
  name     = "${local.name_prefix}${local.name_suffix}"
  location = "westus2"
}

#Application Insights for Telementry
resource "azurerm_application_insights" "this" {
  name                = "${local.name_prefix}${local.name_suffix}"
  location            = var.location
  resource_group_name = local.resource_group.name
  application_type    = "Web"
}


#Function App Infrastructure
resource "azurerm_storage_account" "this" {
  name                     = "${lower(replace("${local.name_prefix}${local.name_suffix}","-",""))}"
  resource_group_name      = local.resource_group.name
  location                 = local.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "this" {
  name                = "${local.name_prefix}${local.name_suffix}"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "this" {
  name                      = "${local.name_prefix}${local.name_suffix}"
  location                  = local.resource_group.location
  resource_group_name       = local.resource_group.name
  app_service_plan_id       = azurerm_app_service_plan.this.id
  storage_connection_string = azurerm_storage_account.this.primary_connection_string
  version                   = "~2"
  enable_builtin_logging    = false
  app_settings              = {
    "FUNCTIONS_WORKER_RUNTIME"        = "powershell"
    "APPINSIGHTS_INSTRUMENTATIONKEY"  = azurerm_application_insights.this.instrumentation_key
  }
  identity {
    type = "SystemAssigned"
  }
}