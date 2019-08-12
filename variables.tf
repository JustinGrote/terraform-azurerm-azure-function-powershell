variable name {
  description = "The name of your deployment. This will be used as the resource group name and prefix for all related resources. If not specified, it will use the name of the module as you defined it."
  type = string
  default = null
}

variable subscription_id {
  description = "Specify the subscription ID to deploy into. By default this uses your current az subscription"
  type = string
  default = null
}

variable tags {
  description = "Additional tags that you wish to add to all resources"
  type = map(string)
  default = {}
}

### FOR FUTURE USE
# variable "resource_group" {
#   description = "An existing resource group to deploy the azure function in. If not specified, it will autocreate one per region."
#   type = object({
#     id = string
#     name = string
#     location = string
#     tags = map(string)
#   })
#   default = null
# }

variable location {
  description = "Defines a list of azure locations to deploy the resource. If multiple locations are specified, the function is deployed to each location. It is recommended to use paired regions https://docs.microsoft.com/en-us/azure/best-practices-availability-paired-regions and to use the long names of locations so that abbreviations can be created appropriately. Example: [\"us west\",\"us east\"]"
  type = list(string)
}

variable name_suffix {
  description = "An optional suffix for your resources. By default, this is blank if in the default workspace and appends '-workspacename' if in a non-default workspace"
  type = string
  default = null
}

variable skip_region_suffix {
  description = "If set and only one region is specified, this module will omit the region specific suffix where appropriate (e.g. myapp-wu2 will just be myapp) and use a single global resource group. Does not work for multiregion deployments because DNS name conflicts will arise. Accessory items like Keyvault will still be regional specific. Changing this variable is destructive to non-global items (e.g. function apps will be rebuilt but Application Insights instance stays the same). Set to false if you plan to grow an app beyond one region in the future and don't want a destructive rebuild"
  type = bool
  default = true
}

variable azurerm_function_app_runtime {
  description = "The runtime to use for the azure functions workers. This has only been tested with \"powershell\" but others may work fine"
  type = string
  default = "powershell"
}

#Traffic Manager Toggle
variable azurerm_traffic_manager {
  description = "Set to false to disable the Azure Traffic Manager component"
  type = bool
  default = true
}

variable azurerm_key_vault {
  description = "Set to false to disable the Azure Key Vault integration"  
  type = bool
  default = true
}

# Removing this support for now
variable azurerm_key_vault_secrets {
  description = "Specify a map (hashtable) of secrets to be stored in the key vault. In the future these will be securely exposed as App Settings to the function. Example: {mysecret1 = \"supersecret1\",mysecret2 = \"supersecret2\"}"
  default = null
}

variable azure_active_directory_id {
  description = "The Directory ID of your Azure Active Directory, viewable in Properties on the Azure Portal. Defaults to the current Az CLI user's Account."
  type = string
  default = null
}

variable app_settings {
  description = "A map of app_settings to push to Azure Functions."
  type = map(string)
  default = {}
}