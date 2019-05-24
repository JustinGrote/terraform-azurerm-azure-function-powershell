locals {
  azure_active_directory_id = "${
    var.azure_active_directory_id != null
      ? var.azure_active_directory_id
      : data.azurerm_client_config.this.tenant_id
  }"

  #Nested Loop Strategy: https://serverfault.com/questions/833810/terraform-use-nested-loops-with-count/968309#968309
  secret_count = "${
    var.azurerm_key_vault_secrets != null 
      ? length(var.azurerm_key_vault_secrets) * local.location_count
      : 0
  }"
}

data "azurerm_subscription" "this" {}

data "azurerm_client_config" "this" {}

data "external" "this_az_account" {
  count = var.azurerm_key_vault ? 1 : 0
  program = [
    "az",
    "ad",
    "signed-in-user",
    "show",
    "--query",
    "{displayName: displayName,objectId: objectId,objectType: objectType,odata_metadata: \"odata.metadata\"}"
  ]
  depends_on = [
    azurerm_key_vault.this[0]
  ]
}

resource "azurerm_key_vault" "this" {
  count               = var.azurerm_key_vault ? local.location_count : 0
  name                = length(local.default_name[count.index]) <= 24 ? local.default_name[count.index] : local.storage_account_short_name[count.index]
  location            = azurerm_resource_group.this[count.index].location
  resource_group_name = azurerm_resource_group.this[count.index].name
  tenant_id           = local.azure_active_directory_id
  sku {
    name = "standard"
  }
  tags                = local.global_tags
}

resource "azurerm_key_vault_access_policy" "terraformuser" {
  count               = var.azurerm_key_vault ? local.location_count : 0
  key_vault_id        = azurerm_key_vault.this[count.index].id
  tenant_id           = local.azure_active_directory_id
  object_id           = data.external.this_az_account[0].result.objectId
  secret_permissions  = [
    "get",
    "set",
    "delete"
  ]
}

resource "azurerm_key_vault_access_policy" "this" {
  count               = var.azurerm_key_vault ? local.location_count : 0
  key_vault_id        = azurerm_key_vault.this[count.index].id
  tenant_id           = azurerm_function_app.this[count.index].identity[0].tenant_id
  object_id           = azurerm_function_app.this[count.index].identity[0].principal_id
  secret_permissions  = [
    "get"
  ]
}

#Nested Loop Strategy: https://serverfault.com/questions/833810/terraform-use-nested-loops-with-count/968309#968309
resource "azurerm_key_vault_secret" "this" {
  count             = local.secret_count
  key_vault_id      = azurerm_key_vault.this[count.index % local.location_count].id
  name              = keys(var.azurerm_key_vault_secrets)[floor(count.index / length(var.location))]
  value             = var.azurerm_key_vault_secrets[keys(var.azurerm_key_vault_secrets)[floor(count.index / length(var.location))]]
  #Key Vault doesn't grant sufficient rights by default
  depends_on = [
    azurerm_key_vault_access_policy.terraformuser
  ]
  tags              = local.global_tags
}