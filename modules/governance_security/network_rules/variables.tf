# modules/security/network_rules/variables.tf

variable "network_rules" {
  description = "A map of network rule configurations decoded from YAML"
  type = map(object({
    database   = string
    schema     = string
    type       = string
    mode       = string
    value_list = set(string) # using set(string) here is perfect for deduplicated IPs!
    comment    = optional(string, null) # makes comment optional
  }))
}