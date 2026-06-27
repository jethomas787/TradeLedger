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
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.5.0"
    }
    http = { 
      source = "hashicorp/http",          
      version = "~> 3.0"   
      } 
  }
}

provider "azurerm" { 
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true // Dev: allow purge; Prod: false
      recover_soft_deleted_key_vaults = true // Dev: recover; Prod: false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false // Dev: allow deletion; Prod: true
    }
  }
}

# ── Data sources ──────────────────────────────────────────────
data "azurerm_client_config" "current" {} # Get current SP/identity info for RBAC role assignments

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
  /* Resource Group is the container for all resources in this project, logical container storage account and DB rely on this */
  name     = "rg-tradejournal-${var.environment}-canadacentral"
  location = var.location
  tags     = local.common_tags
}

# ── ADLS Gen2 Storage Account ─────────────────────────────────
resource "azurerm_storage_account" "adls" { 
  /* ADLS Gen2 for data lake storage, adls2 is the latest version of Azure Data Lake Storage,
 built on top of Azure Blob Storage. Provides destination for ingested and processed data */
  name                     = "sadltradejournal${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"  
  account_replication_type = "LRS"
  # LRS
  account_kind             = "StorageV2" 
  # 
  is_hns_enabled           = true # Required for ADLS Gen2
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  /*  provides hierarchical namespace for data lake storage */
  name               = "bronze"
  storage_account_id = azurerm_storage_account.adls.id
}

resource "azurerm_postgresql_flexible_server" "pg" {
  /* PostgreSQL Flexible Server is a fully managed database service that provides built-in high availability, 
    scaling, and maintenance capabilities. It offers more control and flexibility compared to Azure Database for PostgreSQL Single Server,
    making it ideal for production workloads.  Flexible Server simply means next generation database server */
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

resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  /* Allow Azure services to access the PostgreSQL server. This is required for Azure Data Factory and other Azure services to connect to the database. 
    In production, you might want to restrict this and only allow specific IP ranges or service endpoints.
    By default Azure blocks all external connections to the database.
    Never set the IP to 0.0.0.0 to 255.255.255.255 */
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

data "http" "my_public_ip" {
  // Take the current public IP address for firewall rule
  url = "https://api.ipify.org"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "local_access" {
  /* Allow local access from your public IP address. This is useful for development and testing purposes.
  without this Azure will block local access resulting Connection Refused errors */
  name             = "AllowLocalHomeIP"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = data.http.my_public_ip.response_body
  end_ip_address   = data.http.my_public_ip.response_body
}

resource "azurerm_postgresql_flexible_server_database" "tradejournal" {
  /* Create a database for the trade journal application. The instance where the database is created and runs on */
  name      = "tradejournal"
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_consumption_budget_resource_group" "tp_budget" {
  /* Create a budget for the resource group. */
  name              = "budget-${var.project_prefix}-dev"
  resource_group_id = azurerm_resource_group.rg.id
  amount            = 60 # Monthly total ($15/week baseline)
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  # Alert 1: 50% ($30) - Early Warning
  notification {
    enabled        = true
    threshold      = 50.0
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = ["your-email@example.com"]
  }

  # Alert 2: 75% ($45) - Critical Threshold
  notification {
    enabled        = true
    threshold      = 75.0
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = ["your-email@example.com"]
  }

  # Alert 3: 90% ($54) - Near Limit
  notification {
    enabled        = true
    threshold      = 90.0
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = ["your-email@example.com"]
  }

  # Alert 4: Forecasted 100% ($60) - Predictive
  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = ["your-email@example.com"]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}

resource "azurerm_key_vault_secret" "kafka_producer_key"{
  name = "kafka-producer-key"
  value = confluent_api_key.producer_key.id
  key_vault_id = azurerm_key_vault.kv.id
}
resource "azurerm_key_vault_secret" "kafka_producer_secret" {
  name = "kafka-producer-secret"
  value = confluent_api_key.producer_key.secret
  key_vault_id = azurerm_key_vault.kv.id
}

resource "confluent_service_account" "admin" {
  display_name = "tradeledger-admin-sa"
  description  = "Service account for cluster administration"
}

resource "confluent_api_key" "cluster_admin" {
  display_name = "cluster-admin-api-key"
  description  = "Kafka API Key owned by the admin service account"

  owner {
    id          = confluent_service_account.admin.id
    api_version = confluent_service_account.admin.api_version
    kind        = confluent_service_account.admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.main.id
    api_version = confluent_kafka_cluster.main.api_version
    kind        = confluent_kafka_cluster.main.kind

    environment {
      id = confluent_environment.main.id
    }
  }
}

resource "confluent_environment" "main"{
  display_name = "tradeledger - ${var.environment}"
}

resource "confluent_kafka_cluster" "main" {
  display_name = "tradeledger-cluster"
  availability = "SINGLE_ZONE"
  cloud        = "AZURE"
  region       = "canadacentral"
  standard{}
  
  environment {
    id = confluent_environment.main.id
  }
}

resource "confluent_kafka_topic" "trades_raw" {
  topic_name       = "trades-raw"
  partitions_count = 3
  rest_endpoint    = confluent_kafka_cluster.main.rest_endpoint

  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret 
  }

  config = {
    "retention.ms"   = "604800000"
    "cleanup.policy" = "delete"
  }
}

resource "confluent_service_account" "producer" {
  display_name = "tradeledger_producer"
  description = "GBM simulator producer = write access to trade-raw only"
}

resource "confluent_service_account" "consumer" {
  display_name = "tradeledger_consumer"
  description = "Bronze consumer - read access to trade- raw only" 
}

resource "confluent_api_key" "producer_key" {
  display_name = "producer-api-key"
  owner {
      id  = confluent_service_account.producer.id
      api_version = confluent_service_account.producer.api_version
      kind  = confluent_service_account.producer.kind
  }
  managed_resource{
      id = confluent_kafka_cluster.main.id
      api_version = confluent_kafka_cluster.main.api_version
      kind = confluent_kafka_cluster.main.kind
      environment {
        id = confluent_environment.main.id
      }
  }
}

# Generate API Key for the Consumer
resource "confluent_api_key" "consumer_key" {
  display_name = "consumer-api-key"
  owner {
    id          = confluent_service_account.consumer.id
    api_version = confluent_service_account.consumer.api_version
    kind        = confluent_service_account.consumer.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.main.id
    api_version = confluent_kafka_cluster.main.api_version
    kind        = confluent_kafka_cluster.main.kind
    environment {
      id = confluent_environment.main.id # Fixed reference
    }
  }
}

# Vault the Consumer Credentials
resource "azurerm_key_vault_secret" "kafka_consumer_key" {
  name         = "kafka-consumer-key"
  value        = confluent_api_key.consumer_key.id
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "kafka_consumer_secret" {
  name         = "kafka-consumer-secret"
  value        = confluent_api_key.consumer_key.secret
  key_vault_id = azurerm_key_vault.kv.id
}

# 1. Allow Producer to WRITE to the topic
resource "confluent_kafka_acl" "producer_write" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.trades_raw.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint
  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

# 2. Allow Consumer to READ from the topic
resource "confluent_kafka_acl" "consumer_read" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.trades_raw.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint
  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

# 3. Allow Consumer to READ the Consumer Group (Required for offsets)
resource "confluent_kafka_acl" "app_consumer_group" {
  kafka_cluster {
    id = confluent_kafka_cluster.main.id
  }
  resource_type = "GROUP"
  resource_name = "bronze-consumer-group" 
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.main.rest_endpoint
  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}


