

# data "azurerm_subscription" "this" {}
# # output "function_app_portal_uri" {
# #   description = "The Azure Portal Management URL to view and manage your new Azure Function"
# #   value = "https://portal.azure.com/#blade/WebsitesExtension/FunctionsIFrameBlade/id/%2Fsubscriptions%2F${data.azurerm_subscription.this.id}%2FresourceGroups%2F${local.resource_group.name}%2Fproviders%2FMicrosoft.Web%2Fsites%2F${azurerm_app_service_plan.this.name}"

output "azurerm_application_insights" {
  value = azurerm_application_insights.this
}

output "azurerm_function_app" {
  value = azurerm_function_app.this
}
 
output "azurerm_traffic_manager_profile" {
  value = azurerm_traffic_manager_profile.this
}

output "azurerm_key_vault" {
  value = azurerm_key_vault.this
}

