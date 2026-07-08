# modules/security/ownership/schema/variables.tf

variable "schema_ownerships" {
  type = list(object({
    database_name = string
    schema_name   = string
    account_role  = string
  }))
  description = "List of schemas and the account roles that should own them."
}