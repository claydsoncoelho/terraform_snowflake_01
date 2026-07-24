# modules/security/network_policies/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
    }
  }
}

resource "snowflake_network_policy" "this" {
  for_each = var.network_policies

  name    = each.key
  comment = each.value.comment

  # Look up the actual fully qualified name from the rule outputs map
  allowed_network_rule_list = [
    for rule in each.value.allowed_network_rule_list : var.network_rule_fqns[rule]
  ]

  blocked_network_rule_list = length(each.value.blocked_network_rule_list) > 0 ? [
    for rule in each.value.blocked_network_rule_list : var.network_rule_fqns[rule]
  ] : null
}