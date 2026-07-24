# modules/databases/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_database" "this" {
  for_each                    = var.databases
  name                        = each.key
  comment                     = each.value.comment
  is_transient                = each.value.is_transient
  data_retention_time_in_days = each.value.data_retention_time_in_days
}