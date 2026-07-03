# variables.tf
# This file defines all variables used across the Snowflake Terraform configuration

#------------------------------------------------------------------------
# PROVIDER AUTHENTICATION VARIABLES (Secure)
#------------------------------------------------------------------------

# Snowflake service account username
# GitHub Actions: Set via repository variable SNOWFLAKE_USER (visible in logs)
# Azure DevOps: Set via Variable Group
# Local: Set via environment variable TF_VAR_snowflake_user
variable "snowflake_user" {
  description = "Snowflake service account username for Terraform authentication"
  type        = string
  sensitive   = false # Changed to false since this is now a variable, not a secret
}

# Snowflake private key file path
# GitHub Actions: Set via workflow (after creating file from secret)
# Azure DevOps: Set via pipeline (after downloading from Secure Files)
# Local: Path to private key file
variable "snowflake_private_key_path" {
  description = "Path to the Snowflake private key file"
  type        = string
  default     = "~/.ssh/snowflake_tf_snow_key.p8"
}

#------------------------------------------------------------------------
# ACCOUNT ROLES
#------------------------------------------------------------------------
variable "account_roles" {
  description = "Map of global account roles to create"
  type = map(object({
    comment = optional(string, "Managed by Terraform")
  }))
}

#------------------------------------------------------------------------
# DATABASE CONFIGURATION
#------------------------------------------------------------------------
variable "databases" {
  description = "Configuration for Snowflake databases"
  type = map(object({
    comment                     = optional(string, "Managed by Terraform")
    is_transient                = optional(bool, false)
    data_retention_time_in_days = optional(number, 1)
  }))
}

#------------------------------------------------------------------------
# SCHEMA CONFIGURATION
#------------------------------------------------------------------------
variable "schemas" {
  description = "Configuration for schemas mapped to their respective databases"
  type = map(object({
    database                    = string # The parent database name
    comment                     = optional(string, "Managed by Terraform")
    data_retention_time_in_days = optional(number, 1)
    with_managed_access         = optional(bool, false)
  }))
}

#------------------------------------------------------------------------
# ACCESS CONTROL CONFIGURATION (RBAC)
#------------------------------------------------------------------------
variable "role_to_role_grants" {
  description = "Global role hierarchy configuration mappings"
  type = list(object({
    role        = string
    parent_role = string
  }))
  default = []
}

variable "database_privileges" {
  description = "Database-level privilege assignments"
  type = list(object({
    database  = string
    role      = string
    privilege = string # e.g., "USAGE", "CREATE SCHEMA"
  }))
  default = []
}

variable "schema_privileges" {
  description = "Schema-level privilege assignments"
  type = list(object({
    database  = string
    schema    = string
    role      = string
    privilege = string # e.g., "USAGE", "SELECT"
  }))
  default = []
}