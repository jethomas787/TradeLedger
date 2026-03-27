output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "storage_account_name" {
  value = azurerm_storage_account.adls.name
}

output "pg_server_fqdn" {
  value = azurerm_postgresql_flexible_server.pg.fqdn
}

output "pg_admin_username" {
  value = var.pg_admin_username
}

output "pg_connection_string_hint" {
  description = "Retrieve full string from Key Vault — never printed here"
  value       = "az keyvault secret show --vault-name ${azurerm_key_vault.kv.name} --name pg-connection-string --query value -o tsv"
  sensitive   = false
}