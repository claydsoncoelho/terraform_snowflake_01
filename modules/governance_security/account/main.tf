# modules/account/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_account_parameter" "parameters" {
  for_each = var.parameters
  key      = each.key
  value    = each.value
}