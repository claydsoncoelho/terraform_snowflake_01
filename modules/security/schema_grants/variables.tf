# modules/security/schema_grants/variables.tf

variable "grants" {
  type = list(object({
    database  = string
    schema    = string
    role      = string
    privilege = string
  }))
}