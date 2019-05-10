variable "name" {
  description = "The name of your deployment. This will be used as the resource group name and prefix for all related resources. Defaults to the name of the folder if not specified"
  default = "terraformnameprefixdefault"
}
variable "azure_active_directory_id" {
  description = "The Directory ID of your Azure Active Directory, viewable in Properties on the Azure Portal. Defaults to the current Az CLI User's Account"
  default = "azureactivedirectoryiddefault"
}

variable "location" {
  description = "Defines the Azure Location in which to deploy resources. Defaults to westus2"
  default = "westus2"
}