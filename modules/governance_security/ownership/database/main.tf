# modules/security/ownership/database/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_grant_ownership" "database_ownership" {
  for_each = {
    for idx, entry in var.database_ownerships : 
    "${entry.database_name}__TO__${entry.account_role}" => entry
  }

  account_role_name   = each.value.account_role
  outbound_privileges = "REVOKE"

  # FIX: Pull attributes directly into the 'on' block
  on {
    object_type = "DATABASE"
    object_name = each.value.database_name
  }
}