# modules/schemas/variables.tf

variable "schemas" {
  description = "A map of schemas to their respective database configurations"
  type = map(object({
    database                    = string
    comment                     = optional(string, "Managed by Terraform")
    data_retention_time_in_days = optional(number, 1)
    with_managed_access         = optional(bool, false)
  }))
}
