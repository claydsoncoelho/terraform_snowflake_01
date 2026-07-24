# modules/governance_security/role_hierarchy/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

locals {
  # Account Role -> Account Role Grants
  account_role_grants = {
    for item in var.role_hierarchy :
    "${upper(trimspace(item.role))}__TO__${upper(trimspace(item.parent_role))}" => {
      role        = upper(trimspace(item.role))
      parent_role = upper(trimspace(item.parent_role))
    }
    if lookup(item, "role", null) != null && lookup(item, "database_role", null) == null
  }

  # Database Role -> Account Role Grants
  database_role_grants = {
    for item in var.role_hierarchy :
    "${upper(trimspace(item.database_name))}.${upper(trimspace(item.database_role))}__TO__${upper(trimspace(item.parent_role))}" => {
      database_name = upper(trimspace(item.database_name))
      database_role = upper(trimspace(item.database_role))
      parent_role   = upper(trimspace(item.parent_role))
    }
    if lookup(item, "database_role", null) != null
  }
}

# 1. Account Role -> Account Role Grants
resource "snowflake_grant_account_role" "this" {
  for_each = local.account_role_grants

  role_name        = each.value.role
  parent_role_name = each.value.parent_role
}

# 2. Database Role -> Account Role Grants
resource "snowflake_grant_database_role" "this" {
  for_each = local.database_role_grants

  database_role_name = "\"${each.value.database_name}\".\"${each.value.database_role}\""
  parent_role_name   = each.value.parent_role
}