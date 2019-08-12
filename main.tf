terraform {
  required_version = ">= 0.12.6"
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
  regex_git_commit = "/^.+-[a-f0-9]{7}$/"

  #Default to the name of the module
  name_prefix = "${
    var.name != null
      ? var.name
      #Fix issue when fetched from a git commit or tf registry, get the parent path for default name
      : replace(basename(path.module),local.regex_git_commit,"") == ""
        ? basename(dirname(path.module))
        : basename(path.module)
  }"

  #If the workspace is not named "default", add it as a suffix
  name_suffix = "${
    var.name_suffix != null
      ? var.name_suffix
      : terraform.workspace != "default"
        ? "-${terraform.workspace}"
        : ""
  }"

  alphanumeric_only_regex = "/[\\W\\ \\_]/"

  #Determine if this is a single-region resource and if the skip regional suffix preference is set
  single_region_app = length(var.location) == 1 && var.skip_region_suffix

  #Generate a short location name for each region, unless this is a single region and skip_region_suffix was set
  azure_short_location_regex = "/\\b(\\w)((\\w*)?$|\\w+ )/" #Abbreviate the Azure Location
  azure_short_location       = local.single_region_app ? [""] : [
    for location in var.location: 
    lower(
      replace( #Remove spaces because I can't figure out how to make this work in the first regex
        replace(
          location,
          local.azure_short_location_regex,
          "$1"
        ),
        "/ /",
        ""
      )
    )
  ]

  #Use the first location as the global location for multilocation resources
  global_location = var.location[0]
  global_name     = "${local.name_prefix}${local.name_suffix}"


  # Generate names for each location.
  default_name = [
    for azure_short_location in local.azure_short_location: 
    join("",
      [
        local.name_prefix,
        local.name_suffix,
        local.single_region_app ? "" : "-",
        azure_short_location
      ]
    )
  ]

  #Generate storage account names for each location, which have strict requirements
  storage_account_short_name = [
    for azure_short_location in local.azure_short_location: 
      lower(
        join("",
          [
            substr(replace(local.name_prefix,local.alphanumeric_only_regex,""),0,15),
            substr(replace(local.name_suffix,local.alphanumeric_only_regex,""),0,1),
            substr(azure_short_location,0,3),
            #Add a pseudorandom suffix to avoid potential name collisions
            substr("${sha1(azure_short_location)}",0,4)
          ]
        )
      )
  ]

  #If the default storage account name after formatting is more than 24 characters, use the short name
  storage_account_name = [
    for default_name in local.default_name: "${
      length(lower(replace(default_name,local.alphanumeric_only_regex,""))) <= 24
      ? lower(replace(default_name,local.alphanumeric_only_regex,""))
      : local.storage_account_short_name[index(local.default_name,default_name)]
    }"
  ]

  #Count used later if more than one location was specified
  location_count = length(var.location)
  
  #Global Tags
  global_tags = merge(
    {
      TERRAFORM   = "TRUE"
      TFWORKSPACE = terraform.workspace
    },var.tags
  )
}

resource "azurerm_resource_group" "global" {
  name     = local.global_name
  location = local.global_location
  tags     = local.global_tags
}

resource "azurerm_resource_group" "this" {
  count    = local.single_region_app ? 0 : local.location_count
  name     = local.default_name[count.index]
  location = var.location[count.index]
  tags     = local.global_tags
}

#Application Insights for Telementry
resource "azurerm_application_insights" "this" {
  name                = local.global_name
  location            = azurerm_resource_group.global.location
  resource_group_name = azurerm_resource_group.global.name
  application_type    = "Web"
  tags                = local.global_tags
}

#Function App Infrastructure
resource "azurerm_storage_account" "this" {
  count                    = local.location_count
  name                     = local.storage_account_name[count.index]
  resource_group_name      = local.single_region_app ? azurerm_resource_group.global.name : azurerm_resource_group.this[count.index].name
  location                 = local.single_region_app ? azurerm_resource_group.global.location : azurerm_resource_group.this[count.index].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.global_tags
}

resource "azurerm_app_service_plan" "this" {
  count               = local.location_count
  name                = local.default_name[count.index]
  resource_group_name = local.single_region_app ? azurerm_resource_group.global.name : azurerm_resource_group.this[count.index].name
  location            = local.single_region_app ? azurerm_resource_group.global.location : azurerm_resource_group.this[count.index].location
  kind                = "FunctionApp"
  sku_name {
    tier = "Dynamic"
    size = "Y1"
  }
  tags = local.global_tags
}

resource "azurerm_function_app" "this" {
  count                     = local.location_count
  name                      = local.default_name[count.index]
  resource_group_name       = local.single_region_app ? azurerm_resource_group.global.name : azurerm_resource_group.this[count.index].name
  location                  = local.single_region_app ? azurerm_resource_group.global.location : azurerm_resource_group.this[count.index].location
  app_service_plan_id       = azurerm_app_service_plan.this[count.index].id
  storage_connection_string = azurerm_storage_account.this[count.index].primary_connection_string
  version                   = "~2"
  enable_builtin_logging    = false
  app_settings              = merge(var.app_settings,
    {
    "FUNCTIONS_WORKER_RUNTIME"       = var.azurerm_function_app_runtime
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.this.instrumentation_key
    }
  )
  identity {
    type = "SystemAssigned"
  }
  lifecycle {
    ignore_changes = ["app_settings"]
  }
  tags = local.global_tags
}