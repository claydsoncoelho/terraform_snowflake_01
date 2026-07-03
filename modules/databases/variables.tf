# modules/databases/variables.tf

variable "databases" {
  description = "Configuration for Snowflake databases"
  type = map(object({
    comment                     = optional(string, "Managed by Terraform")
    is_transient                = optional(bool, false)
    data_retention_time_in_days = optional(number, 1)
  }))
}
