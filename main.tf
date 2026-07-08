# main.tf
# Main Terraform configuration file for Snowflake deployment
# This file orchestrates the creation of all Snowflake resources through modules

# Important Terraform functions used in this file:
# fileset() function is a directory scanner. It takes two arguments: a base path and a pattern to match.
# path.module is a built-in Terraform variable that evaluates to the absolute path of the directory where this current file lives.

#========================================================================
# PROVIDER CONFIGURATION
#========================================================================
terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }

  # Backend configuration for Azure Blob Storage
  backend "azurerm" {
    resource_group_name  = "snowflake_learning"
    storage_account_name = "snowflake4learning"
    container_name       = "my-container" 
    key                  = "snowflake.prod.terraform.tfstate"
    use_azuread_auth     = true
  }
}

#========================================================================
# LOCAL VARIABLES
#========================================================================
locals {
  organization_name          = "egtaggb"
  account_name               = "ik00397"
  snowflake_user             = var.snowflake_user
  snowflake_private_key_path = var.snowflake_private_key_path

  # ---------------------------------------------- Account Parameters -----------------------------------------
  # YAML Parsing Engine for Account Parameters (Decodes directly into a Map)
  account_parameters = yamldecode(fileexists("${path.module}/configs/account/account_parameter.yaml") ? file("${path.module}/configs/account/account_parameter.yaml") : "{}")

  # ---------------------------------------------- Network Rules -----------------------------------------
  # YAML Parsing Engine for Network Rules (Decodes into a Map of Objects)
  network_rules = yamldecode(fileexists("${path.module}/configs/security/network_rules.yaml") ? file("${path.module}/configs/security/network_rules.yaml") : "{}")

  # ---------------------------------------------- Roles -----------------------------------------
  # YAML Parsing Engine for Account Roles
  role_files = fileset(path.module, "configs/roles/*.yaml")
  account_roles = {
    for filename in local.role_files :
    yamldecode(file("${path.module}/${filename}")).name => yamldecode(file("${path.module}/${filename}"))
  }

  # ---------------------------------------------- Databases -----------------------------------------
  # YAML Parsing Engine for Databases
  database_files = fileset(path.module, "configs/databases/*.yaml")
  databases = {
    for filename in local.database_files :
    yamldecode(file("${path.module}/${filename}")).name => yamldecode(file("${path.module}/${filename}"))
  }

  # ---------------------------------------------- Schemas -----------------------------------------
  # YAML Engine: Schemas
  # The "**/*.yaml" pattern captures both the folder name and the filename
  schema_files = fileset(path.module, "configs/schemas/**/*.yaml")
  schemas = {
    for filename in local.schema_files :
    # Keep the unique Map tracking key as DATABASE.SCHEMA
    "${upper(split("/", filename)[2])}.${upper(yamldecode(file("${path.module}/${filename}")).name)}" => {
      
      name                        = upper(yamldecode(file("${path.module}/${filename}")).name)
      comment                     = try(yamldecode(file("${path.module}/${filename}")).comment, null)
      data_retention_time_in_days = try(yamldecode(file("${path.module}/${filename}")).data_retention_time_in_days, null)
      with_managed_access         = try(yamldecode(file("${path.module}/${filename}")).with_managed_access, null)
      database                    = upper(split("/", filename)[2])
    }
  }

  # ---------------------------------------------- Security -----------------------------------------
  # YAML Parsing Engine for Role Hierarchy 
  # Reads the single hierarchy file and loads it into a native Terraform list
  role_hierarchy = [
    for grant in yamldecode(fileexists("${path.module}/configs/security/role_hierarchy.yaml") ? file("${path.module}/configs/security/role_hierarchy.yaml") : "[]") :
    grant if grant != null
  ]
  # YAML Engine: Database Grants
  database_grants = [
    for assignment in yamldecode(fileexists("${path.module}/configs/security/database_grants.yaml") ? file("${path.module}/configs/security/database_grants.yaml") : "[]") :
    assignment if assignment != null
  ]
  # YAML Engine: Schema Grants
  schema_grants = [
    for assignment in yamldecode(fileexists("${path.module}/configs/security/schema_grants.yaml") ? file("${path.module}/configs/security/schema_grants.yaml") : "[]") :
    assignment if assignment != null
  ]
  # YAML Engine: Ownership Grants
  ownership_data = yamldecode(fileexists("${path.module}/configs/security/ownerships.yaml") ? file("${path.module}/configs/security/ownerships.yaml") : "databases: []\nschemas: []") 
}

#========================================================================
# SNOWFLAKE PROVIDERS SETUP
#========================================================================

# Default Provider (Used for Warehouses, Databases, Schemas)
provider "snowflake" {
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.snowflake_user
  role              = "SYSADMIN" 
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(local.snowflake_private_key_path)
}

# Aliased Security Provider (Used for Roles & User Management)
provider "snowflake" {
  alias             = "security"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.snowflake_user
  role              = "SECURITYADMIN" 
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(local.snowflake_private_key_path)
}

# Aliased Account Admin Provider (Used for account-level operations)
provider "snowflake" {
  alias             = "account_admin"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.snowflake_user
  role              = "ACCOUNTADMIN" 
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(local.snowflake_private_key_path)
}

#========================================================================
# SYSTEM ORCHESTRATION MODULES
#========================================================================

# Dependency Order of Execution:

# ├── snowflake_roles
# |   └── role_hierarchy
# |       ├── snowflake_database_grants
# |       └── snowflake_schema_grants
# |
# └── snowflake_databases
#     ├── snowflake_database_grants
#     |   └── database_ownership
#     └── snowflake_schemas
#         └── snowflake_schema_grants
#             └── schema_ownership

#========================================================================
# ACCOUNT CONFIGURATION
#========================================================================
# Apply account-level parameters (settings that affect the entire Snowflake account)
#
# Dependencies: None (account parameters can be set independently)
#------------------------------------------------------------------------

# Apply account-level parameters
module "account_parameters" {
  source = "./modules/account"
  providers = {
    snowflake = snowflake.account_admin
  }
  parameters = local.account_parameters
}

#------------------------------------------------------------------------
# ACCOUNT ROLES
#------------------------------------------------------------------------
# Instantiates custom module using the memory-compiled YAML data map
module "snowflake_roles" {
  source        = "./modules/roles"
  account_roles = local.account_roles
  
  providers = {
    snowflake = snowflake.security
  }
}

#------------------------------------------------------------------------
# DATABASES
#------------------------------------------------------------------------
# Create the Databases (SYSADMIN role is used automatically by default)
module "snowflake_databases" {
  source    = "./modules/databases"
  databases = local.databases
}

#------------------------------------------------------------------------
# SCHEMAS
#------------------------------------------------------------------------
# Create the Schemas
module "snowflake_schemas" {
  source  = "./modules/schemas"
  schemas = local.schemas

  # Ensures databases exist before Snowflake attempts to create schemas inside them!
  depends_on = [module.snowflake_databases]
}

#------------------------------------------------------------------------
# SECURITY: ROLE TO ROLE GRANTS
#------------------------------------------------------------------------
# Create the Assignments
module "role_hierarchy" {
  source              = "./modules/security/role_hierarchy"
  role_hierarchy = local.role_hierarchy

  providers = {
    snowflake = snowflake.security
  }
  
  # Ensure roles are built entirely before trying to assign them!
  depends_on = [module.snowflake_roles]
}

#------------------------------------------------------------------------
# SECURITY: Database Grants
#------------------------------------------------------------------------
# Module 5: Create Database Entitlements
module "snowflake_database_grants" {
  source = "./modules/security/database_grants"
  grants = local.database_grants

  # Essential Guardrails: Databases and Roles must exist entirely 
  # before your pipeline attempts to tie security rules between them!
  depends_on = [
    module.database_ownership,
    module.role_hierarchy
  ]
}

#------------------------------------------------------------------------
# SECURITY: Schema Grants
#------------------------------------------------------------------------
# Create Schema Entitlements
module "snowflake_schema_grants" {
  source = "./modules/security/schema_grants"
  grants = local.schema_grants

  # Crucial Guardrails: Schemas and Roles must be completely 
  # live before attempting to bind privileges between them!
  depends_on = [
    module.schema_ownership,
    module.role_hierarchy
  ]
}

#------------------------------------------------------------------------
# SECURITY: Ownership Grants
#------------------------------------------------------------------------
# Create Ownership Entitlements for Databases
module "database_ownership" {
  source              = "./modules/security/ownership/database"
  database_ownerships = local.ownership_data.databases

  # Execute ownership assignment right after creation
  depends_on = [
    module.snowflake_databases
  ]
}

# Create Ownership Entitlements for Schemas
module "schema_ownership" {
  source            = "./modules/security/ownership/schema"
  schema_ownerships = local.ownership_data.schemas

  # Execute ownership assignment right after creation
  depends_on = [
    module.snowflake_schemas
  ]
}

#------------------------------------------------------------------------
# SECURITY: Network Rules
#------------------------------------------------------------------------
module "snowflake_network_rules" {
  source        = "./modules/security/network_rules"
  network_rules = local.network_rules

  # Dependency Guardrail: Ensure schemas exist before building rules inside them!
  depends_on = [
    module.snowflake_schemas
  ]
}