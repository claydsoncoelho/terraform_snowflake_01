# modules/admin/resource_monitors/main.tf

terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
      version = "2.17.0" 
    }
  }
}

locals {
  # Build a map of all resource monitors keyed by UPPERCASE name
  monitors_map = {
    for item in var.resource_monitors :
    upper(trimspace(item.name)) => item
  }

  # Filter down to only monitors where set_for_account is set to true
  account_monitors = {
    for key, item in local.monitors_map :
    key => item
    if lookup(item, "set_for_account", false) == true
  }
}

# Create all Resource Monitors
resource "snowflake_resource_monitor" "this" {
  for_each = local.monitors_map

  name                      = each.value.name
  credit_quota              = lookup(each.value, "credit_quota", null)
  frequency                 = lookup(each.value, "frequency", "MONTHLY")
  start_timestamp           = lookup(each.value, "start_timestamp", "IMMEDIATELY")
  notify_triggers           = lookup(each.value, "notify_triggers", null)
  suspend_trigger           = lookup(each.value, "suspend_trigger", null)
  suspend_immediate_trigger = lookup(each.value, "suspend_immediate_trigger", null)
}

# Dynamically attach any monitor marked with set_for_account = true
resource "snowflake_execute" "account_resource_monitor_attachment" {
  for_each = local.account_monitors

  execute = "ALTER ACCOUNT SET RESOURCE_MONITOR = ${snowflake_resource_monitor.this[each.key].name}"
  revert  = "ALTER ACCOUNT UNSET RESOURCE_MONITOR"

  depends_on = [
    snowflake_resource_monitor.this
  ]
}