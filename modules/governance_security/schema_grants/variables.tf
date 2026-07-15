# modules/governance_security/schema_grants/variables.tf

variable "grants" {
  description = "A list of schema grant configuration objects parsed from YAML"
  type = list(object({
    database  = string
    schema    = string
    role      = string
    privilege = list(string)
  }))
}