# modules/security/network_policies/variables.tf

variable "network_policies" {
  description = "A map of network policy configurations decoded from YAML"
  type = map(object({
    comment                   = optional(string, null)
    allowed_network_rule_list = set(string)
    blocked_network_rule_list = optional(set(string), [])
  }))
}

# NEW: Add this to receive the mapped outputs
variable "network_rule_fqns" {
  description = "Map of network rule names to their dynamic fully qualified names"
  type        = map(string)
}