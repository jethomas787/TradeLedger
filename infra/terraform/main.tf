terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# ── Data sources ──────────────────────────────────────────────
data "azurerm_client_config" "current" {}

# ── Random suffix for globally unique names ───────────────────
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ── Random password — NEVER written to disk ───────────────────
resource "random_password" "pg_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}|;:,.<>?"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 4
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-tradejournal-${var.environment}-canadacentral"
  location = var.location
  tags     = local.common_tags
}

# ── ADLS Gen2 Storage Account ─────────────────────────────────
resource "azurerm_storage_account" "adls" {
  name                     = "sadltradejournal${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # Required for ADLS Gen2
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.adls.id
}

# ── Key Vault (RBAC authorization) ───────────────────────────
resource "azurerm_key_vault" "kv" {
  name                        = "kv-tradejournal-${random_string.suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true # RBAC — not access policies
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false # Dev: allow purge; Prod: true
  tags                        = local.common_tags
}

# ── RBAC: Terraform SP → Key Vault Secrets Officer ──────────
resource "azurerm_role_assignment" "sp_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ── RBAC: Personal Account → Key Vault Administrator ────────
resource "azurerm_role_assignment" "personal_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.personal_account_object_id
}
# ── PostgreSQL Flexible Server ───────────────────────────────
resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "pg-tradejournal-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "15"
  administrator_login    = var.pg_admin_username
  administrator_password = random_password.pg_admin.result # From random provider
  sku_name               = "B_Standard_B1ms"
  storage_mb             = 32768
  backup_retention_days  = 7
  zone                   = "1"
  tags                   = local.common_tags
}

# Allow Azure services to connect (includes AKS pods in later weeks)
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Allow your machine IP (replace with your current IP)
resource "azurerm_postgresql_flexible_server_firewall_rule" "dev_machine" {
  name             = "DevMachine"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = var.dev_machine_ip
  end_ip_address   = var.dev_machine_ip
}
# Wait for RBAC propagation before writing secrets
resource "time_sleep" "kv_rbac_wait" {
  depends_on = [azurerm_role_assignment.sp_kv_secrets_officer]

  create_duration = "90s"
}

resource "azurerm_key_vault_secret" "pg_admin_login" {
  depends_on = [time_sleep.kv_rbac_wait]

  name         = "pg-admin-login"
  value        = var.pg_admin_username
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "pg_admin_password" {
  depends_on = [time_sleep.kv_rbac_wait]

  name         = "pg-admin-password"
  value        = random_password.pg_admin.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "pg_connection_string" {
  depends_on = [time_sleep.kv_rbac_wait]

  name         = "pg-connection-string"
  value        = "host=${azurerm_postgresql_flexible_server.pg.fqdn} dbname=tradejournal user=${var.pg_admin_username} password=${random_password.pg_admin.result} sslmode=require"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "storage_account_key" {
  depends_on = [time_sleep.kv_rbac_wait]

  name         = "storage-account-key"
  value        = azurerm_storage_account.adls.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
}
# ── Locals ───────────────────────────────────────────────────
locals {
  common_tags = {
    project     = "TradeLedger"
    environment = var.environment
    managed_by  = "Terraform"
    week        = "Week1"
  }
}
  resource "azurerm_postgresql_flexible_server_database" "tradejournal" {
  name      = "tradejournal"
  server_id = azurerm_postgresql_flexible_server.pg.id
  collation = "en_US.utf8"
  charset   = "utf8"
}
