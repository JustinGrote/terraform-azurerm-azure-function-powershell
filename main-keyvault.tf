locals {
  azure_active_directory_id = "${
    var.azure_active_directory_id != null
      ? var.azure_active_directory_id
      : data.azurerm_client_config.this.tenant_id
  }"

  #Nested Loop Strategy: https://serverfault.com/questions/833810/terraform-use-nested-loops-with-count/968309#968309
  policy_count = "${
    var.azurerm_key_vault_secrets != null 
      ? length(var.azurerm_key_vault_secrets) * local.location_count
      : 0
  }"
}

data "azurerm_subscription" "this" {}

data "azurerm_client_config" "this" {}

data "external" "this_az_account" {
  program = [
    "az",
    "ad",
    "signed-in-user",
    "show",
    "--query",
    "{displayName: displayName,objectId: objectId,objectType: objectType,odata_metadata: \"odata.metadata\"}"
  ]
}

resource "azurerm_key_vault" "this" {
  count               = var.azurerm_key_vault ? local.location_count : 0
  name                = "${local.name_prefix}-${replace(var.location[count.index],local.azure_short_region_regex,"$1")}${local.name_suffix}"
  location            = azurerm_resource_group.this[count.index].location
  resource_group_name = azurerm_resource_group.this[count.index].name
  tenant_id           = local.azure_active_directory_id
  sku {
    name = "standard"
  }
}

#Nested Loop Strategy: https://serverfault.com/questions/833810/terraform-use-nested-loops-with-count/968309#968309
# resource "azurerm_key_vault_secret" "this" {
#   count = local.policy_count
#   key_vault_id = azurerm_key_vault.this[count.index % local.location_count].id
#   name = keys(var.azurerm_key_vault_secrets)[floor(count.index / length(var.location))]
#   value = var.azurerm_key_vault_secrets[keys(var.azurerm_key_vault_secrets)[floor(count.index / length(var.location))]]
# }

resource "azurerm_key_vault_access_policy" "terraform" {
  count               = var.azurerm_key_vault ? 1 : 0
  key_vault_id        = azurerm_key_vault.this[0].id
  tenant_id           = local.azure_active_directory_id
  object_id           = data.external.this_az_account.result.objectId
  secret_permissions  = [
    "get",
    "set",
    "delete"
  ]
}


