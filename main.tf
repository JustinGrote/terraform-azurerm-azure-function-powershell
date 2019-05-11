locals {
  #Default to the folder name if no name is specified
  default_name_prefix = "${
    path.module != "." 
      ? basename(path.module) 
      : basename(path.cwd)
  }"
  name_prefix = "${
    var.name != "terraformnameprefixdefault" 
      ? var.name 
      : "${local.default_name_prefix}-${terraform.workspace}"
  }"

  #If the workspace is not named "default", add it as a suffix
  name_suffix = "${
    terraform.workspace != "default"
      ? ""
      : "-${terraform.workspace}"
  }"
  subscription_id = "8167906e-cadf-4916-861e-c70fdfe0321d"

  #Hacky default but saves an extra data.external call
  this_az_account_azuread_id = "${element(split("/",data.external.this_az_account.result.odata_metadata),3)}"
  azure_active_directory_id = "${
    var.azure_active_directory_id != "azureactivedirectoryiddefault" 
      ? var.name
      : local.this_az_account_azuread_id
  }"

  #Dumb 0.11 workaround, can just reference directly in 0.12
  azurerm_function_app_identity = "${element(azurerm_function_app.this.identity,0)}"
}

provider "azurerm" {
  version = "=1.23.0-dev20190216h00-dev"
  #Development subscription
  subscription_id = "${local.subscription_id}"
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



resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}${local.name_suffix}"
  location = "${var.location}"
}

#Application Insights for Telementry
resource "azurerm_application_insights" "this" {
  name                = "${local.name_prefix}${local.name_suffix}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.this.name}"
  application_type    = "Web"
}

#Azure Key Vault for Secrets

resource "azurerm_key_vault" "this" {
  name                = "${local.name_prefix}${local.name_suffix}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.this.name}"
  tenant_id           = "${local.azure_active_directory_id}"
  sku {
    name = "standard"
  }
}

#Two Integrated Azure Keyvault Secrets. Will replace these with a foreach loop in Terraform 0.12
resource "azurerm_key_vault_secret" "username" {
  name     = "KEYVAULTUSERNAME"
  value    = "replaceme"
  key_vault_id = "${azurerm_key_vault.this.id}"
  depends_on = ["azurerm_key_vault_access_policy.terraform"]
}

resource "azurerm_key_vault_secret" "password" {
  name     = "KEYVAULTPASSWORD"
  value    = "replaceme"
  key_vault_id = "${azurerm_key_vault.this.id}"
  depends_on = ["azurerm_key_vault_access_policy.terraform"]
}

#Grant access to the account running terraform for purposes of adding additional keys
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = "${azurerm_key_vault.this.id}"
  tenant_id = "${local.this_az_account_azuread_id}"
  object_id = "${data.external.this_az_account.result.objectId}"
  secret_permissions = [
    "get",
    "set",
    "delete"
  ]
}

#Grant Read-Only Access for the Azure Function variables
resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id = "${azurerm_key_vault.this.id}"
  tenant_id = "${local.azurerm_function_app_identity["tenant_id"]}"
  object_id = "${local.azurerm_function_app_identity["object_id"]}"
  secret_permissions = [
    "get"
  ]
}

#Function App Infrastructure
resource "azurerm_storage_account" "this" {
  name                     = "${lower(replace("${local.name_prefix}${local.name_suffix}","-",""))}"
  resource_group_name      = "${azurerm_resource_group.this.name}"
  location                 = "${azurerm_resource_group.this.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "this" {
  name                = "${local.name_prefix}${local.name_suffix}"
  location            = "${azurerm_resource_group.this.location}"
  resource_group_name = "${azurerm_resource_group.this.name}"
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "this" {
  name                      = "${local.name_prefix}${local.name_suffix}"
  location                  = "${azurerm_resource_group.this.location}"
  resource_group_name       = "${azurerm_resource_group.this.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.this.id}"
  storage_connection_string = "${azurerm_storage_account.this.primary_connection_string}"
  version                   = "~2"
  enable_builtin_logging    = false
  app_settings              = {
    "FUNCTIONS_WORKER_RUNTIME"        = "powershell"
    "APPINSIGHTS_INSTRUMENTATIONKEY"  = "${azurerm_application_insights.this.instrumentation_key}"
  }
  identity {
    type = "SystemAssigned"
  }
}

#These had to be done separately from app_settings because it created a circular dependency
resource "null_resource" "azurerm_function_app_this_keyvaultsecrets" {
  provisioner "local-exec" {
    command = "az functionapp config appsettings set --subscription ${local.subscription_id} --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_function_app.this.name} --query \"[].name\" --output table --settings ${azurerm_key_vault_secret.username.name}=\"@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=${azurerm_key_vault_secret.username.name};SecretVersion=${azurerm_key_vault_secret.username.version})"
    # ${azurerm_key_vault_secret.username.name}=\"@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=${azurerm_key_vault_secret.username.name};SecretVersion=${azurerm_key_vault_secret.username.version})\" ${azurerm_key_vault_secret.password.name}=\"@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=${azurerm_key_vault_secret.password.name};SecretVersion=${azurerm_key_vault_secret.password.version})\""
  }
}

