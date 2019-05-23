

resource "azurerm_traffic_manager_profile" "this" {
  count                   = var.azurerm_traffic_manager == true ? 1 : 0
  name                    = "${local.name_prefix}${local.name_suffix}"
  resource_group_name     = lower(azurerm_resource_group.global.name)
  traffic_routing_method  = "Performance"
  dns_config {
    relative_name         = lower("${local.name_prefix}${local.name_suffix}")
    ttl                   = 100
  }
  monitor_config {
    protocol              = "http"
    port                  = 80
    path                  = "/"
  }
  tags                    = local.global_tags
}

resource "azurerm_traffic_manager_endpoint" "this" {
  count               = var.azurerm_traffic_manager ? local.location_count : 0
  name                = azurerm_function_app.this[count.index].name
  resource_group_name = lower(azurerm_traffic_manager_profile.this[0].resource_group_name)
  profile_name        = azurerm_traffic_manager_profile.this[0].name
  target_resource_id  = azurerm_function_app.this[count.index].id
  type                = "azureEndpoints"
}
