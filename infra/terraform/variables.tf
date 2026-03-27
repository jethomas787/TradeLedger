# ── Variables ────────────────────────────────────────────────
variable "location" {
  description = "Azure region"
  default     = "canadacentral"
}

variable "environment" {
  description = "Environment name"
  default     = "dev"
}

variable "pg_admin_username" {
  description = "PostgreSQL administrator login"
  default     = "pgadmin"
}

variable "personal_account_object_id" {
  description = "Object ID of your personal Azure AD account (for KV admin)"
  type        = string
  # Find with: az ad signed-in-user show --query id -o tsv
}

variable "dev_machine_ip" {
  description = "Your machine IP for PostgreSQL firewall"
  type        = string
  # Find with: curl -s https://api.ipify.org
}
variable "project_prefix" {
  description = "Short prefix used in resource naming"
  default     = "tradejournal"
}