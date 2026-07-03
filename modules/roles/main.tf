# modules/roles/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

resource "snowflake_account_role" "this" {
  for_each = var.account_roles
  name     = each.key
  comment  = each.value.comment
}