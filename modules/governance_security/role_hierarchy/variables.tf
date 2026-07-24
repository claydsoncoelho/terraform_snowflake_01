# modules/governance_security/role_hierarchy/variables.tf

variable "role_hierarchy" {
  description = "A list of role-to-role inheritance configurations (supports both Account Roles and Database Roles)"
  type        = any
  default     = []
}