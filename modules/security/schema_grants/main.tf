# modules/security/schema_grants/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "this" {
  for_each = { for idx, grant in var.grants : "${grant.privilege}__ON__${grant.database}.${grant.schema}__TO__${grant.role}" => grant }

  account_role_name = each.value.role
  privileges        = [each.value.privilege]

  on_schema {
    # Expects the fully qualified format: "DATABASE_NAME"."SCHEMA_NAME"
    schema_name = "\"${each.value.database}\".\"${each.value.schema}\""
  }
}
