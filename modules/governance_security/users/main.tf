# modules/governance_security/users/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_user" "this" {
  for_each = var.users

  # Critical structural identifiers
  name       = each.key
  login_name = lookup(each.value, "login_name", each.key) # Falls back to the map key if login_name is omitted
  password       = lookup(each.value, "password", null)
  must_change_password = lookup(each.value, "must_change_password", false)
  
  # Standard Metadata (Generic Lookups)
  display_name  = lookup(each.value, "display_name", null)
  comment       = lookup(each.value, "comment", null)
  disabled      = lookup(each.value, "disabled", false)
  email         = lookup(each.value, "email", null)
  first_name    = lookup(each.value, "first_name", null)
  last_name     = lookup(each.value, "last_name", null)

  # Platform Defaults
  default_warehouse = lookup(each.value, "default_warehouse", null)
  default_role      = lookup(each.value, "default_role", null)
  default_namespace = lookup(each.value, "default_namespace", null)

  # Policies & Security
  network_policy = lookup(each.value, "network_policy", null)  
}