# modules/security/network_rules/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_network_rule" "this" {
  for_each = var.network_rules

  name     = each.key # Uses "COALESCE_IP_AUS_ALLOWED" automatically
  database = each.value.database
  schema   = each.value.schema
  type     = each.value.type
  mode     = each.value.mode

  # The snowflake provider takes the value list array directly
  value_list = each.value.value_list
  comment    = each.value.comment
}
