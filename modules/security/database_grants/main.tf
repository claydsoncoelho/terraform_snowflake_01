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
  for_each = { for idx, grant in var.grants : "${grant.database}_${grant.role}_${grant.privilege}" => grant }

  account_role_name = each.value.role
  privileges        = [each.value.privilege]

  on_account_object {
    object_type = "DATABASE"
    object_name = each.value.database
  }
}
