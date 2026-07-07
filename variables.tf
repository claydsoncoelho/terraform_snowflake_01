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
