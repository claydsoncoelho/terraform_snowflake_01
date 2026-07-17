# modules/governance_security/schema_grants/variables.tf

variable "grants" {
  description = "A list of schema grant configuration objects resolved from profiles and custom definitions"
  type = list(object({
    database          = string
    schema            = string
    role              = string
    schema_privileges = optional(list(string), [])
    all_objects       = optional(map(list(string)), {})
    future_objects    = optional(map(list(string)), {})
  }))
}