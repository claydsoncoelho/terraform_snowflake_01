# modules/schemas/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_schema" "this" {
  for_each                    = var.schemas
  name                        = each.value.name
  database                    = each.value.database
  comment                     = each.value.comment
  data_retention_time_in_days = each.value.data_retention_time_in_days
  with_managed_access         = each.value.with_managed_access
}
