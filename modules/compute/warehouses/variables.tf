# modules/compute/warehouses/variables.tf

variable "warehouses" {
  type    = list(any)
  default = []
}

variable "resource_monitors" {
  description = "Map of available resource monitor names to their fully qualified names"
  type        = map(string)
  default     = {}
}