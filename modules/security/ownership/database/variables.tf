# modules/security/ownership/database/variables.tf

variable "database_ownerships" {
  type = list(object({
    database_name = string
    account_role  = string
  }))
  description = "List of databases and the account roles that should own them."
}