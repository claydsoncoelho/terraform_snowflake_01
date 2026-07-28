# modules/governance_security/warehouse_grants/variables.tf

variable "warehouse_grants" {
  type = list(object({
    warehouse = string
    role      = string
    privilege = list(string)
  }))
  description = "Warehouse privilege assignments."
}