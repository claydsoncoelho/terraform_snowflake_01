# modules/account/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

resource "snowflake_account_parameter" "parameters" {
  for_each = var.parameters
  key      = each.key
  value    = each.value
}