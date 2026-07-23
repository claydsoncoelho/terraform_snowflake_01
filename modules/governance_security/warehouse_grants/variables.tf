# modules/governance_security/warehouse_grants/variables.tf

variable "warehouse_grants" {
  description = "List of warehouse grant configuration objects decoded from YAML"
  type = list(object({
    warehouse = string
    role      = string
    privilege = list(string)
  }))
  default = []
}