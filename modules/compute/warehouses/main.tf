# modules/compute/warehouses/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
  }
}

locals {
  warehouses_map = {
    for item in var.warehouses :
    upper(trimspace(item.name)) => item
  }
}

resource "snowflake_warehouse" "this" {
  for_each = local.warehouses_map

  name                                = each.value.name
  comment                             = lookup(each.value, "comment", null)
  warehouse_size                      = upper(lookup(each.value, "size", "X-SMALL"))
  auto_resume                         = lookup(each.value, "auto_resume", true)
  auto_suspend                        = lookup(each.value, "auto_suspend_seconds", 300)
  max_cluster_count                   = lookup(each.value, "max_cluster_count", 1)
  min_cluster_count                   = lookup(each.value, "min_cluster_count", 1)
  initially_suspended                 = lookup(each.value, "initially_suspended", true)
  enable_query_acceleration           = lookup(each.value, "enable_query_acceleration", false)
  query_acceleration_max_scale_factor = lookup(each.value, "query_acceleration_max_scale_factor", 0)
  resource_monitor                    = lookup(each.value, "resource_monitor", null) != null ? lookup(var.resource_monitors, upper(trimspace(each.value.resource_monitor)), upper(trimspace(each.value.resource_monitor))) : null
}