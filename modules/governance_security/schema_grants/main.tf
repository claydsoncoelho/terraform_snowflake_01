# modules/governance_security/schema_grants/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "schema_grants" {
  # Key format: ROLE__ON__DATABASE.SCHEMA
  for_each = {
    for idx, grant in var.grants : "${grant.role}__ON__${grant.database}.${grant.schema}" => grant
  }

  account_role_name = each.value.role
  privileges         = each.value.privilege

  on_schema {
    schema_name = "\"${each.value.database}\".\"${each.value.schema}\""
  }
}