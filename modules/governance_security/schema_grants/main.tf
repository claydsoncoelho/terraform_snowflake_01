# modules/governance_security/schema_grants/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

# 1. Standard Schema-Level Grants
resource "snowflake_grant_privileges_to_account_role" "schema_grants" {
  for_each = {
    for idx, grant in var.grants : "${grant.role}__ON__${grant.database}.${grant.schema}" => grant
    if length(grant.schema_privileges) > 0
  }

  account_role_name = each.value.role
  privileges        = each.value.schema_privileges

  on_schema {
    schema_name = "\"${each.value.database}\".\"${each.value.schema}\""
  }
}

# ==============================================================================
# 2. Generic ALL Object Grants (Privileges grouped in a single list)
# ==============================================================================
resource "snowflake_grant_privileges_to_account_role" "all_objects_grants" {
  for_each = {
    for g in flatten([
      for grant in var.grants : [
        for obj_type, privileges in grant.all_objects : {
          # Unique key mapped strictly to the Object Type rather than individual privileges
          key         = "${grant.role}__ON__${grant.database}.${grant.schema}__ALL_${upper(obj_type)}"
          role        = grant.role
          database    = grant.database
          schema      = grant.schema
          object_type = replace(upper(obj_type), "_", " ")
          # Pass the whole slice of privileges directly (e.g., ["READ", "WRITE"])
          privileges  = [for p in privileges : upper(p)]
        }
      ]
    ]) : g.key => g
  }

  account_role_name = each.value.role
  privileges        = each.value.privileges

  on_schema_object {
    all {
      object_type_plural = each.value.object_type
      in_schema          = "\"${each.value.database}\".\"${each.value.schema}\""
    }
  }
}

# ==============================================================================
# 3. Generic FUTURE Object Grants (Privileges grouped in a single list)
# ==============================================================================
resource "snowflake_grant_privileges_to_account_role" "future_objects_grants" {
  for_each = {
    for g in flatten([
      for grant in var.grants : [
        for obj_type, privileges in grant.future_objects : {
          # Unique key mapped strictly to the Object Type rather than individual privileges
          key         = "${grant.role}__ON__${grant.database}.${grant.schema}__FUTURE_${upper(obj_type)}"
          role        = grant.role
          database    = grant.database
          schema      = grant.schema
          object_type = replace(upper(obj_type), "_", " ")
          # Pass the whole slice of privileges directly (e.g., ["READ", "WRITE"])
          privileges  = [for p in privileges : upper(p)]
        }
      ]
    ]) : g.key => g
  }

  account_role_name = each.value.role
  privileges        = each.value.privileges

  on_schema_object {
    future {
      object_type_plural = each.value.object_type
      in_schema          = "\"${each.value.database}\".\"${each.value.schema}\""
    }
  }
}