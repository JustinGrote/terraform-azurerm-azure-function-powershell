variable "name" {
  description = "The name of your deployment. This will be used as the resource group name and prefix for all related resources. Specify 'default' to use the name of the folder"
  type = string
}
variable "name_suffix" {
  description = "An optional suffix for your resources. By default, this is blank if in the default workspace and appends '-workspacename' if in a non-default workspace"
  type = string
  default = null
}


variable "resource_group" {
  description = "An existing resource group to deploy the azure function in, if required"
  type = object({
    id = string
    name = string
    location = string
    tags = map(string)
  })
  default = null
}

variable "resource_group_name" {
  description = "The resource group name for the new function App. If not specified, a new one will be created"
  default = ""
}

variable "storage_account" {
  description = "The storage account name to use for the azure function. If not specified it will create one."
  default = ""
}

variable "storage_account_resource_group_name" {
  description = "The resource group name of the storage account. Defaults to the same resource group as the Azure Function"
  default = ""
}


variable "location" {
  description = "Defines the Azure Location in which to deploy resources. Defaults to westus2"
  default = "westus2"
}