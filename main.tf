# main.tf
# Main Terraform configuration file for Snowflake deployment
# This file orchestrates the creation of all Snowflake resources through modules

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
  organization_name          = var.organization_name
  account_name               = var.account_name
  snowflake_user             = var.snowflake_user
  snowflake_private_key_path = var.snowflake_private_key_path

  #---------------------------------------------- Paths -----------------------------------------
  permission_sets_path        = "${path.module}/configs/envs/common/governance_security/permission_sets.yaml"
  account_parameters_path     = "${path.module}/configs/envs/common/governance_security/account_parameter.yaml"
  network_rules_path          = "${path.module}/configs/envs/common/governance_security/network_rules.yaml"
  network_policies_path       = "${path.module}/configs/envs/common/governance_security/network_policies.yaml"
  users_path                  = "${path.module}/configs/envs/common/governance_security/users.yaml"
  user_role_assignments_path  = "${path.module}/configs/envs/common/governance_security/user_role_assignments.yaml"
  roles_path                  = "${path.module}/configs/envs/*/governance_security/roles/*.yaml"
  role_hierarchy_path         = "${path.module}/configs/envs/*/governance_security/role_hierarchy.yaml"
  databases_path              = "${path.module}/configs/envs/*/catalog/databases/*.yaml"
  schemas_path                = "${path.module}/configs/envs/*/catalog/schemas/*.yaml"
  database_grants_path        = "${path.module}/configs/envs/*/governance_security/database_grants/*.yaml"
  schema_grants_path          = "${path.module}/configs/envs/*/governance_security/schema_grants/*.yaml"
  ownerships_path             = "${path.module}/configs/envs/*/governance_security/ownerships.yaml"
  warehouses_path             = "${path.module}/configs/envs/*/compute/warehouses/*.yaml"
  warehouse_grants_path       = "${path.module}/configs/envs/*/governance_security/warehouse_grants/*.yaml"
  resource_monitors_path      = "${path.module}/configs/envs/*/admin/resource_monitors/*.yaml"
  
  # ---------------------------------------------- Schema Grants -----------------------------------------
  # Load the single source-of-truth profiles map
  # Resulting shape: { "SCHEMA_READ" = { schema_privilege = [...], all_objects = {...} }, ... }
  permission_sets = yamldecode(file(local.permission_sets_path))

  # ---------------------------------------------- Account Parameters -----------------------------------------
  # YAML Parsing Engine for Account Parameters (Decodes directly into a Map)
  account_parameters = yamldecode(fileexists(local.account_parameters_path) ? file(local.account_parameters_path) : "{}")

  # ---------------------------------------------- Network Rules -----------------------------------------
  # YAML Parsing Engine for Network Rules (Decodes into a Map of Objects)
  network_rules = yamldecode(fileexists(local.network_rules_path) ? file(local.network_rules_path) : "{}")

  # ---------------------------------------------- Network Policies -----------------------------------------
  network_policies = yamldecode(fileexists(local.network_policies_path) ? file(local.network_policies_path) : "{}")

  # ---------------------------------------------- Roles -----------------------------------------
  # 1. Grab all YAML files in the roles folder
  role_files = fileset(path.module, local.roles_path)

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
  users = yamldecode(fileexists(local.users_path) ? file(local.users_path) : "{}")

  # ---------------------------------------- User Role Assignments ------------------------------------
  user_role_assignments = yamldecode(fileexists(local.user_role_assignments_path) ? file(local.user_role_assignments_path) : "[]")

  # ---------------------------------------------- Databases -----------------------------------------
  # 1. Grab all YAML files in the databases folder
  database_files = fileset(path.module, local.databases_path)

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
  schema_files = fileset(path.module, local.schemas_path)

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
  # 1. Dynamically locate any hierarchy files in any environment folder (entirely optional!)
  role_hierarchy_files = fileset(path.module, local.role_hierarchy_path)

  # 2. Decode and flatten hierarchies across all discovered environments
  role_hierarchy = flatten([
    for filename in local.role_hierarchy_files : [
      for grant in yamldecode(file("${path.module}/${filename}")) : {
        role        = upper(grant.role)
        parent_role = upper(grant.parent_role)
        environment = split("/", filename)[2] # Automatically extracts 'dev', 'test', or 'prod'. Not needed, but useful example of how to parse the filename for metadata.
      }
    ]
  ])

  # YAML Engine: Database Grants
  # 1. Grab all YAML files inside the database_grants directory
  database_grant_files = fileset(path.module, local.database_grants_path)

  # 2. Decode and flatten the lists of grants from all matching files
  database_grants = flatten([
    for filename in local.database_grant_files : [
      for assignment in yamldecode(file("${path.module}/${filename}")) : {
        database       = upper(assignment.database)
        role           = upper(assignment.role)
        privilege      = [for priv in try(assignment.privilege, []) : upper(priv)]
        all_schemas    = [for priv in try(assignment.all_schemas, []) : upper(priv)]
        future_schemas = [for priv in try(assignment.future_schemas, []) : upper(priv)]
      }
    ]
  ])
  
  # YAML Engine: Schema Grants
  # 1. Parse out environment schema files via fileset
  schema_grants_files = fileset(path.module, local.schema_grants_path)
  
  raw_schema_grants = flatten([
    for filename in local.schema_grants_files : yamldecode(file("${path.module}/${filename}"))
  ])

  # 2. Enrich the environment rules by resolving permission_set strings into complete objects
  enriched_schema_grants = [
    for g in local.raw_schema_grants : {
      database    = g.database
      schema      = g.schema
      role        = g.role
      
      # Resolve baseline schema privileges from profile
      schema_privileges = concat(lookup(local.permission_sets[g.permission_set], "schema_privilege", []), lookup(g, "custom_schema_privileges", []))
      
      # Merge profile objects with any optional ad-hoc custom definitions
      all_objects    = merge(lookup(local.permission_sets[g.permission_set], "all_objects", {}), lookup(g, "custom_all_objects", {}))
      future_objects = merge(lookup(local.permission_sets[g.permission_set], "future_objects", {}), lookup(g, "custom_future_objects", {}))
    }
  ]
  
  # YAML Engine: Ownership Grants
  # 1. Dynamically locate any ownerships files in any environment folder (entirely optional!)
  ownership_files = fileset(path.module, "configs/envs/*/governance_security/ownerships.yaml")

  # 2. Decode the YAML files across all environments
  decoded_ownerships = [
    for filename in local.ownership_files : {
      content     = yamldecode(file("${path.module}/${filename}"))
      environment = split("/", filename)[2] # Extracts 'dev', 'test', 'prod', etc.
    }
  ]

  # 3. Flatten and extract Database Ownerships
  ownership_databases = flatten([
    for item in local.decoded_ownerships : [
      for db in try(item.content.databases, []) : {
        database_name = upper(db.database_name)
        account_role  = upper(db.account_role)
        environment   = item.environment
      }
    ]
  ])

  # 4. Flatten and extract Schema Ownerships
  ownership_schemas = flatten([
    for item in local.decoded_ownerships : [
      for schema in try(item.content.schemas, []) : {
        database_name = upper(schema.database_name)
        schema_name   = upper(schema.schema_name)
        account_role  = upper(schema.account_role)
        environment   = item.environment
      }
    ]
  ])

  # YAML Engine: Warehouses
  warehouse_files = fileset(path.module, local.warehouses_path)

  flat_warehouses = flatten([
    for filename in local.warehouse_files : [
      for wh in yamldecode(file("${path.module}/${filename}")) : {
        name                                = upper(wh.name)
        comment                             = try(wh.comment, null)
        size                                = try(wh.size, "X-SMALL")
        auto_resume                         = try(wh.auto_resume, true)
        auto_suspend_seconds                = try(wh.auto_suspend_seconds, 300)
        max_cluster_count                   = try(wh.max_cluster_count, 1)
        min_cluster_count                   = try(wh.min_cluster_count, 1)
        initially_suspended                 = try(wh.initially_suspended, true)
        enable_query_acceleration           = try(wh.enable_query_acceleration, false)
        query_acceleration_max_scale_factor = try(wh.query_acceleration_max_scale_factor, 0)
        resource_monitor                    = try(wh.resource_monitor, null)
      }
    ]
  ])

  # YAML Engine: Warehouses Grants
  warehouse_grant_files = fileset(path.module, local.warehouse_grants_path)

  warehouse_grants = flatten([
    for file in local.warehouse_grant_files : yamldecode(file(file))
  ])

  # YAML Engine: Resource Monitors
  resource_monitor_files = fileset(path.module, local.resource_monitors_path)

  resource_monitors = flatten([
    for file in local.resource_monitor_files : yamldecode(file(file))
  ])
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
  source = "./modules/governance_security/account"
  providers = {
    snowflake = snowflake.accountadmin
  }
  parameters = local.account_parameters

  depends_on = [
    module.snowflake_resource_monitors
  ]
}

#------------------------------------------------------------------------
# ACCOUNT ROLES
#------------------------------------------------------------------------
# Instantiates custom module using the memory-compiled YAML data map
module "snowflake_roles" {
  source        = "./modules/governance_security/roles"
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
  source    = "./modules/catalog/databases"
  databases = local.databases
}

#------------------------------------------------------------------------
# SCHEMAS
#------------------------------------------------------------------------
# Create the Schemas
module "snowflake_schemas" {
  source  = "./modules/catalog/schemas"
  schemas = local.schemas

  # Ensures databases exist before Snowflake attempts to create schemas inside them!
  depends_on = [module.snowflake_databases]
}

#------------------------------------------------------------------------
# SECURITY: ROLE TO ROLE GRANTS
#------------------------------------------------------------------------
# Create Assignments
module "role_hierarchy" {
  source              = "./modules/governance_security/role_hierarchy"
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
  grants = local.enriched_schema_grants

  # Crucial Guardrails: Schemas and Roles must be completely 
  # live before attempting to bind privileges between them!
  depends_on = [
    module.schema_ownership,
    module.role_hierarchy
  ]
}

#------------------------------------------------------------------------
# SECURITY: Network Rules
#------------------------------------------------------------------------
module "snowflake_network_rules" {
  source        = "./modules/governance_security/network_rules"
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
  source           = "./modules/governance_security/network_policies"
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
  source              = "./modules/governance_security/ownership/database"
  database_ownerships = local.ownership_databases

  # Execute ownership assignment right after creation
  depends_on = [
    module.snowflake_schemas
  ]
}

# Create Ownership Entitlements for Schemas
module "schema_ownership" {
  source            = "./modules/governance_security/ownership/schema"
  schema_ownerships = local.ownership_schemas

  # Execute ownership assignment right after creation
  depends_on = [
    module.snowflake_schemas
  ]
}

#------------------------------------------------------------------------
# RESOURCE MONITORS
#------------------------------------------------------------------------
module "snowflake_resource_monitors" {
  source            = "./modules/admin/resource_monitors"
  resource_monitors = local.resource_monitors

  providers = {
    snowflake = snowflake.accountadmin
  }
}

#------------------------------------------------------------------------
# WAREHOUSES
#------------------------------------------------------------------------
module "snowflake_warehouses" {
  source     = "./modules/compute/warehouses"
  warehouses = local.flat_warehouses

  resource_monitors = module.snowflake_resource_monitors.resource_monitors

  depends_on = [
    module.snowflake_resource_monitors
  ]
}

# ------------------------------------------------------------------------------
# WAREHOUSES GRANTS
# ------------------------------------------------------------------------------

# Grant Warehouse Privileges to Roles
module "snowflake_warehouse_grants" {
  source           = "./modules/governance_security/warehouse_grants"
  warehouse_grants = local.warehouse_grants

  providers = {
    snowflake = snowflake.security
  }

  # Ensures warehouses are fully created prior to applying privilege grants
  depends_on = [
    module.snowflake_warehouses,
    module.snowflake_roles
  ]
}

