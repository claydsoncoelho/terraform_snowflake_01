# modules/governance_security/database_grants/variables.tf

variable "grants" {
  description = "A list of database grant configuration objects parsed from YAML"
  type = list(object({
    database  = string
    role      = string
    privilege = list(string) # Changed from string to list of strings
  }))
}