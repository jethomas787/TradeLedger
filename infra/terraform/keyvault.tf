resource "azurerm_key_vault" "tradejournal" {
  name                        = "${var.project_prefix}-kv-${random_string.suffix.result}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true 
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false # dev only
  tags                        = local.tags
}

resource "azurerm_role_assignment" "terraform_kv_officer" {
  scope                = azurerm_key_vault.tradejournal.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}


