# modules/admin/resource_monitors/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
  }
}

locals {
  monitors_map = {
    for item in var.resource_monitors :
    upper(trimspace(item.name)) => item
  }

  account_monitors = {
    for key, item in local.monitors_map :
    key => item
    if item.set_for_account
  }
}

resource "snowflake_resource_monitor" "this" {
  for_each = local.monitors_map

  name                      = each.key
  credit_quota              = each.value.credit_quota
  frequency                 = each.value.frequency
  start_timestamp           = each.value.start_timestamp
  notify_triggers           = each.value.notify_triggers
  suspend_trigger           = each.value.suspend_trigger
  suspend_immediate_trigger = each.value.suspend_immediate_trigger

  lifecycle {
    precondition {
      condition     = each.value.frequency == null || each.value.start_timestamp != null
      error_message = "Resource monitor ${each.key}: setting 'frequency' requires 'start_timestamp'."
    }
  }
}

resource "snowflake_execute" "account_resource_monitor_attachment" {
  for_each = local.account_monitors

  execute = "ALTER ACCOUNT SET RESOURCE_MONITOR = ${snowflake_resource_monitor.this[each.key].name}"
  revert  = "ALTER ACCOUNT UNSET RESOURCE_MONITOR"

  lifecycle {
    precondition {
      condition     = length(local.account_monitors) <= 1
      error_message = "Only one resource monitor may set set_for_account = true. Found: ${join(", ", keys(local.account_monitors))}."
    }
  }
}