# modules/governance_security/warehouse_grants/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

locals {
  # Construct a unique map key formatted as "WAREHOUSE_ROLE"
  grants_map = {
    for item in var.warehouse_grants :
    "${upper(trimspace(item.warehouse))}_${upper(trimspace(item.role))}" => {
      warehouse  = upper(trimspace(item.warehouse))
      role       = upper(trimspace(item.role))
      privileges = [for p in item.privilege : upper(trimspace(p))]
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "this" {
  for_each          = local.grants_map
  account_role_name = each.value.role
  privileges        = each.value.privileges

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = each.value.warehouse
  }
}