# modules/security/role_hierarchy/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

resource "snowflake_grant_account_role" "this" {
  for_each = { for idx, grant in var.role_hierarchy : "${grant.role}_TO_${grant.parent_role}" => grant }

  role_name        = each.value.role
  parent_role_name = each.value.parent_role
}
