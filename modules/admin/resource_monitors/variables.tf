# modules/admin/resource_monitors/variables.tf

variable "resource_monitors" {
  description = "List of resource monitor configurations decoded from YAML"
  type        = any
  default     = []
}