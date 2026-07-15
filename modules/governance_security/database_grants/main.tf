# modules/governance_security/database_grants/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "this" {
  # Key format: ROLE__ON__DATABASE (guarantees a unique and stable tracking key per target block)
  for_each = { 
    for idx, grant in var.grants : "${grant.role}__ON__${grant.database}" => grant 
  }

  account_role_name = each.value.role
  
  # Passes the list of privileges directly from your YAML config
  privileges = each.value.privilege

  on_account_object {
    object_type = "DATABASE"
    object_name = each.value.database
  }
}