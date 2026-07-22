# modules/compute/warehouses/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

resource "snowflake_warehouse" "this" {
  for_each = var.warehouses

  name                                = each.value.name
  comment                             = each.value.comment
  warehouse_size                      = upper(each.value.size)
  auto_resume                         = each.value.auto_resume
  auto_suspend                        = each.value.auto_suspend_seconds
  max_cluster_count                   = each.value.max_cluster_count
  min_cluster_count                   = each.value.min_cluster_count
  initially_suspended                 = each.value.initially_suspended
  enable_query_acceleration           = each.value.enable_query_acceleration
  query_acceleration_max_scale_factor = each.value.query_acceleration_max_scale_factor
}