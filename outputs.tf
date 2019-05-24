

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

output "azurerm_traffic_manager_fqdn" {
  description = "The address endpoint for the Azure Function Traffic Manager. Use as the most reliable entry point"
  value = azurerm_traffic_manager_profile.this.*.fqdn
}

output "azurerm_function_app_default_hostnames" {
  description = "The address endpoint for the individual Azure Function endpoints. Use to test on a per location basis."
  value = azurerm_function_app.this.*.default_hostname
}

output "azurerm_function_app_outbound_ip_addresses" {
  description = "All active outbound IP addresses of the azure functions. Useful for firewall rules."
  value = sort(
            distinct(
              split(",",
                join(",",
                  azurerm_function_app.this[*].outbound_ip_addresses
                )
              )
            )
          )
}

output "azurerm_function_app_possible_outbound_ip_addresses" {
  description = "All potential outbound IP addresses of the azure functions. Useful for firewall rules."
  value = sort(
            distinct(
              split(",",
                join(",",
                  azurerm_function_app.this[*].possible_outbound_ip_addresses
                )
              )
            )
          )
}