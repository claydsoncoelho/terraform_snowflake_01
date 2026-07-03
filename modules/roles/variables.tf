# modules/roles/variables.tf

variable "account_roles" {
  description = "A configuration map of Snowflake account roles to provision"
  type = map(object({
    comment = optional(string, "Managed by Terraform")
  }))
}
