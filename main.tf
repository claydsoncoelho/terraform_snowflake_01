# main.tf
# Main Terraform configuration file for Snowflake deployment
# This file orchestrates the creation of all Snowflake resources through modules
#
# Authentication:
# - GitHub Actions: Secrets and variables are set via repository settings and passed as TF_VAR_* environment variables
# - Azure DevOps: Variables are set via Variable Groups and Secure Files
# - Local: Set environment variables TF_VAR_snowflake_user, TF_VAR_snowflake_private_key_passphrase, etc.

#========================================================================
# PROVIDER CONFIGURATION
#========================================================================
# Terraform and Snowflake provider setup
# 
# Dependencies: None (this is the foundation)
#------------------------------------------------------------------------

# Configure Terraform to use the Snowflake provider
# Version pinned to ensure consistent behavior across environments
# https://registry.terraform.io/providers/Snowflakedb/snowflake/latest/docs

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }

  # Backend configuration for Azure Blob Storage
  # Stores Terraform state remotely for team collaboration and state locking
  # You should comment this out if you are running Terraform locally without remote state management
  # Use this command to migrate your local state to the remote backend: `terraform init -migrate-state`
  # You can also use `az login` or `az logout` to authenticate with Azure CLI for backend access55rrr
  backend "azurerm" {
    resource_group_name  = "snowflake_learning"
    storage_account_name = "snowflake4learning"
    container_name       = "my-container"
    key                  = "snowflake.prod.terraform.tfstate" # Name of state file
    # Forces Terraform to use your OIDC Token/RBAC 
    # instead of trying to list the Storage Account Master Keys
    use_azuread_auth     = true
  }
}

#========================================================================
# LOCAL VARIABLES
#========================================================================
locals {
  organization_name = "egtaggb"
  account_name      = "ik00397"
  snowflake_user              = var.snowflake_user
  snowflake_private_key_path  = var.snowflake_private_key_path
}

# Configure the Snowflake provider with authentication details
# Credentials are provided via variables (set by GitHub Actions workflow or locally via TF_VAR_* environment variables)
#
# Authentication Flow:
# 1. JWT authentication using encrypted private key
# 2. Passphrase decrypts the private key at runtime (Not used here yet.)
# 3. Connects as specified user with specified role

# Default Provider (Used for Warehouses, Databases, Schemas)
provider "snowflake" {
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.snowflake_user
  role              = "SYSADMIN" # Focuses on infrastructure ownership
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(local.snowflake_private_key_path)
}

# Aliased Security Provider (Used for Roles & User Management)
provider "snowflake" {
  alias             = "security"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.user
  role              = "SECURITYADMIN" # Focuses on security and RBAC
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(local.private_key_path)
}

#========================================================================
# ROLES
#========================================================================
module "roles" {
  source        = "./modules/roles"
  account_roles = var.account_roles
  providers = {
    snowflake = snowflake.security
  }
}

#========================================================================
# DATABASES
#========================================================================
module "databases" {
  source    = "./modules/databases"
  databases = var.databases
}

#========================================================================
# SCHEMAS
#========================================================================
module "schemas" {
  source  = "./modules/schemas"
  schemas = var.schemas
  
  # Forces schemas to wait until databases are fully active
  depends_on = [module.databases] 
}

#========================================================================
# SECURITY (Roles and Grants)
#========================================================================
# Establish the Role Hierarchy (SYSADMIN inheritance)
module "role_grants" {
  source      = "./modules/security/role_grants"
  role_grants = var.role_to_role_grants
  providers = {
    snowflake = snowflake.security
  }
  depends_on = [module.roles]
}

module "database_grants" {
  source    = "./modules/security/database_grants"
  grants    = var.database_privileges
  providers = {
    snowflake = snowflake.security
  }
  depends_on = [module.databases]
}

module "schema_grants" {
  source    = "./modules/security/schema_grants"
  grants    = var.schema_privileges
  providers = {
    snowflake = snowflake.security
  }
  depends_on = [module.schemas]
}

#========================================================================
# COMPUTE RESOURCES (To be modularized next)
#========================================================================

resource "snowflake_warehouse" "tf_warehouse" {
  name                      = "TF_DEMO_WH"
  warehouse_type            = "STANDARD"
  warehouse_size            = "X-SMALL"
  max_cluster_count         = 1
  min_cluster_count         = 1
  auto_suspend              = 10
  auto_resume               = true
  enable_query_acceleration = false
  initially_suspended       = true
}
