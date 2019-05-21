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
  #Default to the name of the module
  name_prefix = "${
    var.name != null
      ? var.name
      : path.module != "."
        ? basename(path.module)
        : basename(path.cwd)
  }"

  #If the workspace is not named "default", add it as a suffix
  name_suffix = "${
    var.name_suffix != null
      ? var.name_suffix
      : terraform.workspace != "default"
        ? "-${terraform.workspace}"
        : ""
  }"

  #Pluggable Resource Group
  resource_group = "${
    var.resource_group != null
    ? var.resource_group
    : azurerm_resource_group.this[0]
  }"

  #Abbreviate Azure Regions (replace everything but the first character of each word)
  azure_short_region_regex = "/\\b(\\w)((\\w*)?$|\\w+ )/"

  #Use the first location for multilocation resources
  globalLocation = var.location[0]
}

resource "azurerm_resource_group" "global" {
  name     = "${local.name_prefix}${local.name_suffix}"
  location = local.globalLocation
}
resource "azurerm_resource_group" "this" {
  count    = var.resource_group != null ? 0 : length(var.location)
  name     = "${local.name_prefix}-${replace(var.location[count.index],local.azure_short_region_regex,"$1")}${local.name_suffix}"
  location = var.location[count.index]
}

#Application Insights for Telementry
resource "azurerm_application_insights" "this" {
  name                = "${local.name_prefix}${local.name_suffix}"
  location            = azurerm_resource_group.global.location
  resource_group_name = azurerm_resource_group.global.name
  application_type    = "Web"
}

#Function App Infrastructure
resource "azurerm_storage_account" "this" {
  count                    = var.resource_group != null ? 0 : length(var.location)
  #Storage Accounts have strict naming requirements (3-24 alphanumeric characters, all lowercase), hence the convoluted naming syntax
  name                     = "${
                                replace (
                                  lower(
                                    "${
                                      local.name_prefix
                                      }-${
                                        replace(
                                          var.location[count.index],
                                          local.azure_short_region_regex,
                                          "$1"
                                        )
                                      }${
                                      local.name_suffix
                                    }"
                                  ),
                                  "/[^\\w0-9]/",
                                  ""
                                )
                              }"
  resource_group_name      = azurerm_resource_group.this[count.index].name
  location                 = var.location[count.index]
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "this" {
  count               = var.resource_group != null ? 0 : length(var.location)
  name                = "${local.name_prefix}-${replace(var.location[count.index],local.azure_short_region_regex,"$1")}${local.name_suffix}"
  resource_group_name = azurerm_resource_group.this[count.index].name
  location            = var.location[count.index]
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "this" {
  count                     = var.resource_group != null ? 0 : length(var.location)
  name                      = "${local.name_prefix}-${replace(var.location[count.index],local.azure_short_region_regex,"$1")}${local.name_suffix}"
  resource_group_name       = azurerm_resource_group.this[count.index].name
  location                  = var.location[count.index]
  app_service_plan_id       = azurerm_app_service_plan.this[0].id
  storage_connection_string = azurerm_storage_account.this[0].primary_connection_string
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