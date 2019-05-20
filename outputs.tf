output "azurerm_storage_account_name" {
  description = "The storage account for the Azure Function Instance"
  value = "${azurerm_storage_account.this.name}"
}
output "function_app_uri" {
  description = "The base URI for the Azure Functions Host. All your Azure Functions will be called from here"
  value = "https://${azurerm_function_app.this.name}.azurewebsites.net"
}
data "azurerm_subscription" "this" {}
output "function_app_portal_uri" {
  description = "The Azure Portal Management URL to view and manage your new Azure Function"
  value = "https://portal.azure.com/#blade/WebsitesExtension/FunctionsIFrameBlade/id/%2Fsubscriptions%2F${data.azurerm_subscription.this.id}%2FresourceGroups%2F${local.resource_group_name}%2Fproviders%2FMicrosoft.Web%2Fsites%2F${azurerm_app_service_plan.this.name}"
}

output "function_app_outbound_ip_addresses" {
  description = "A list of possible outbound IP addresses that the Azure Function Host request may originate from. Use in firewall rules"
  value = "${azurerm_function_app.this.outbound_ip_addresses}"
}