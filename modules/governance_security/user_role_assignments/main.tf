# modules/governance_security/user_role_assignments/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_grant_account_role" "this" {
  for_each = { for idx, item in var.assignments : "${item.role}__TO__${item.user}" => item }

  role_name = each.value.role
  user_name = each.value.user
}