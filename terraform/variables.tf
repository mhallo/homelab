# Stack secrets. Values come from TF_VAR_<name> fields on the Bitwarden item;
# ephemeral, so they can only reach write-only arguments and never state.

variable "cf_dns_api_token" {
  description = "traefik: CF_DNS_API_TOKEN"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "db_password" {
  description = "immich: DB_PASSWORD"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "db_username" {
  description = "immich: DB_USERNAME"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "db_database_name" {
  description = "immich: DB_DATABASE_NAME"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "ts_authkey" {
  description = "tailscale: TS_AUTHKEY"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "secret_key_base" {
  description = "sure: SECRET_KEY_BASE"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "postgres_password" {
  description = "sure: POSTGRES_PASSWORD"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "active_record_encryption_primary_key" {
  description = "sure: ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "active_record_encryption_deterministic_key" {
  description = "sure: ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "active_record_encryption_key_derivation_salt" {
  description = "sure: ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "b2_key_id" {
  description = "backrest: B2 application key id, limited to the backup bucket"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "b2_application_key" {
  description = "backrest: B2 application key"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "restic_password" {
  description = "backrest: the restic repo's password. Lose it and the backups are unreadable"
  type        = string
  sensitive   = true
  ephemeral   = true
}
