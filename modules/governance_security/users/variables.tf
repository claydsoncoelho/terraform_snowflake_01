# modules/governance_security/users/variables.tf

variable "users" {
  description = "A completely generic map of user account attributes parsed from YAML"
  type        = map(any)
  default     = {}
}