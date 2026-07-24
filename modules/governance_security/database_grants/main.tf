# modules/governance_security/database_grants/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
    }
  }
}

# 1. Direct Grants ON DATABASE (e.g., USAGE, CREATE SCHEMA)
resource "snowflake_grant_privileges_to_account_role" "database_grants" {
  for_each = {
    for idx, grant in var.grants : "${grant.role}__ON__DB_${grant.database}" => grant
    if length(grant.privilege) > 0
  }

  account_role_name = each.value.role
  privileges        = [for p in each.value.privilege : upper(p)]

  on_account_object {
    object_type = "DATABASE"
    object_name = "\"${each.value.database}\""
  }
}

# 2. Grants ON ALL SCHEMAS IN DATABASE
resource "snowflake_grant_privileges_to_account_role" "all_schemas_grants" {
  for_each = {
    for idx, grant in var.grants : "${grant.role}__ON__ALL_SCHEMAS_${grant.database}" => grant
    if length(grant.all_schemas) > 0
  }

  account_role_name = each.value.role
  privileges        = [for p in each.value.all_schemas : upper(p)]

  on_schema {
    all_schemas_in_database = "\"${each.value.database}\""
  }
}

# 3. Grants ON FUTURE SCHEMAS IN DATABASE
resource "snowflake_grant_privileges_to_account_role" "future_schemas_grants" {
  for_each = {
    for idx, grant in var.grants : "${grant.role}__ON__FUTURE_SCHEMAS_${grant.database}" => grant
    if length(grant.future_schemas) > 0
  }

  account_role_name = each.value.role
  privileges        = [for p in each.value.future_schemas : upper(p)]

  on_schema {
    future_schemas_in_database = "\"${each.value.database}\""
  }
}