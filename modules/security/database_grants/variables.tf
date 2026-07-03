# modules/security/database_grants/variables.tf

variable "grants" {
  type = list(object({
    database  = string
    role      = string
    privilege = string
  }))
}