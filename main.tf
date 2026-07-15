# main.tf
# Main Terraform configuration file for Snowflake deployment
# This file orchestrates the creation of all Snowflake resources through modules

# Important Terraform functions used in this file:
# fileset() function is a directory scanner. It takes two arguments: a base path and a pattern to match.
# path.module is a built-in Terraform variable that evaluates to the absolute path of the directory where this current file lives.

# https://registry.terraform.io/providers/snowflakedb/snowflake/latest/docs

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
  account_parameters = yamldecode(fileexists("${path.module}/configs/governance_security/account_parameter.yaml") ? file("${path.module}/configs/governance_security/account_parameter.yaml") : "{}")

  # ---------------------------------------------- Network Rules -----------------------------------------
  # YAML Parsing Engine for Network Rules (Decodes into a Map of Objects)
  network_rules = yamldecode(fileexists("${path.module}/configs/governance_security/network_rules.yaml") ? file("${path.module}/configs/governance_security/network_rules.yaml") : "{}")

  # ---------------------------------------------- Network Policies -----------------------------------------
  network_policies = yamldecode(fileexists("${path.module}/configs/governance_security/network_policies.yaml") ? file("${path.module}/configs/governance_security/network_policies.yaml") : "{}")

  # ---------------------------------------------- Roles -----------------------------------------
  # 1. Grab all YAML files in the roles folder
  role_files = fileset(path.module, "configs/governance_security/roles/*.yaml")

  # 2. Decode files and flatten the nested lists into a single flat list of roles
  flat_account_roles = flatten([
    for filename in local.role_files : [
      for role in yamldecode(file("${path.module}/${filename}")) : {
        name    = upper(role.name)
        comment = try(role.comment, null)
      }
    ]
  ])

  # 3. Project the flat list into a map keyed by ROLE_NAME for your roles module loop
  account_roles = {
    for role in local.flat_account_roles : role.name => role
  }

  # --------------------------------------------- Users ---------------------------------------------------
  users = yamldecode(fileexists("${path.module}/configs/governance_security/users.yaml") ? file("${path.module}/configs/governance_security/users.yaml") : "{}")

  # ---------------------------------------- User Role Assignments ------------------------------------
  user_role_assignments = yamldecode(fileexists("${path.module}/configs/governance_security/user_role_assignments.yaml") ? file("${path.module}/configs/governance_security/user_role_assignments.yaml") : "[]")

  # ---------------------------------------------- Databases -----------------------------------------
  # 1. Grab all YAML files in the databases folder
  database_files = fileset(path.module, "configs/catalog/databases/*.yaml")

  # 2. Decode files and flatten the nested lists into a single flat list of databases
  flat_databases = flatten([
    for filename in local.database_files : [
      for db in yamldecode(file("${path.module}/${filename}")) : {
        name                        = upper(db.name)
        comment                     = try(db.comment, null)
        data_retention_time_in_days = try(db.data_retention_time_in_days, null)
      }
    ]
  ])

  # 3. Project the flat list into a map keyed by DATABASE_NAME for your database module
  databases = {
    for db in local.flat_databases : db.name => db
  }

  # ---------------------------------------------- Schemas -----------------------------------------
  # 1. Grab all YAML files in the schemas folder
  schema_files = fileset(path.module, "configs/catalog/schemas/*.yaml")

  # 2. Decode files and flatten the nested lists into a single flat list of schemas
  flat_schemas = flatten([
    for filename in local.schema_files : [
      for schema in yamldecode(file("${path.module}/${filename}")) : {
        database                    = upper(schema.database)
        name                        = upper(schema.name)
        comment                     = try(schema.comment, null)
        data_retention_time_in_days = try(schema.data_retention_time_in_days, null)
        with_managed_access         = try(schema.with_managed_access, null)
      }
    ]
  ])

  # 3. Project the flat list into a map keyed by "DATABASE.SCHEMA" for the for_each module engine
  schemas = {
    for schema in local.flat_schemas : "${schema.database}.${schema.name}" => schema
  }

  # ---------------------------------------------- Security -----------------------------------------
  # YAML Parsing Engine for Role Hierarchy 
  # Reads the single hierarchy file and loads it into a native Terraform list
  role_hierarchy = [
    for grant in yamldecode(fileexists("${path.module}/configs/governance_security/role_hierarchy.yaml") ? file("${path.module}/configs/governance_security/role_hierarchy.yaml") : "[]") :
    grant if grant != null
  ]

  # YAML Engine: Database Grants
  # 1. Grab all YAML files inside the database_grants directory
  database_grant_files = fileset(path.module, "configs/governance_security/database_grants/*.yaml")

  # 2. Decode and flatten the lists of grants from all matching files
  database_grants = flatten([
    for filename in local.database_grant_files : [
      for assignment in yamldecode(file("${path.module}/${filename}")) : {
        database  = upper(assignment.database)
        role      = upper(assignment.role)
        privilege = [for priv in assignment.privilege : upper(priv)]
      }
    ]
  ])
  
  # YAML Engine: Schema Grants
  # 1. Grab all YAML files inside the schema_grants directory
  schema_grant_files = fileset(path.module, "configs/governance_security/schema_grants/*.yaml")

  # 2. Decode and flatten the lists of grants from all matching files
  schema_grants = flatten([
    for filename in local.schema_grant_files : [
      for assignment in yamldecode(file("${path.module}/${filename}")) : {
        database  = upper(assignment.database)
        schema    = upper(assignment.schema)
        role      = upper(assignment.role)
        privilege = [for priv in assignment.privilege : upper(priv)]
      }
    ]
  ])
  
  # YAML Engine: Ownership Grants
  ownership_data = yamldecode(fileexists("${path.module}/configs/governance_security/ownerships.yaml") ? file("${path.module}/configs/governance_security/ownerships.yaml") : "databases: []\nschemas: []") 
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
  alias             = "accountadmin"
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
    snowflake = snowflake.accountadmin
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
# Create Assignments
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
# Create Database Entitlements
module "snowflake_database_grants" {
  source = "./modules/governance_security/database_grants"
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
  source = "./modules/governance_security/schema_grants"
  grants = local.schema_grants

  # Crucial Guardrails: Schemas and Roles must be completely 
  # live before attempting to bind privileges between them!
  depends_on = [
    module.schema_ownership,
    module.role_hierarchy
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

#------------------------------------------------------------------------
# SECURITY: Network Policies
#------------------------------------------------------------------------
module "snowflake_network_policies" {
  source           = "./modules/security/network_policies"
  network_policies = local.network_policies

  providers = {
    snowflake = snowflake.accountadmin
  }
  
  # PASS THE OUTPUT: Feeds the dynamic map down into the policy engine
  network_rule_fqns = module.snowflake_network_rules.fully_qualified_names
}

#------------------------------------------------------------------------
# SECURITY: User Provisioning
#------------------------------------------------------------------------
module "snowflake_users" {
  source = "./modules/governance_security/users"
  users  = local.users

  providers = {
    snowflake = snowflake.accountadmin
  }

  # Strict Dependency: Network Policies must build completely before assignments
  depends_on = [
    module.snowflake_network_policies
  ]
}

#------------------------------------------------------------------------
# SECURITY: User Role Assignments
#------------------------------------------------------------------------
module "snowflake_user_role_assignments" {
  source      = "./modules/governance_security/user_role_assignments"
  assignments = local.user_role_assignments

  providers = {
    snowflake = snowflake.security
  }

  # Dependency Guardrail: Make sure users and your roles exist first!
  depends_on = [
    module.snowflake_users,
    module.snowflake_roles # Assumes you have your role provision module named this
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
    module.snowflake_schemas
  ]
}