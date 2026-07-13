# modules/governance_security/user_role_assignments/variables.tf

variable "assignments" {
  description = "A list of role-to-user mappings parsed from YAML"
  type = list(object({
    user = string
    role = string
  }))
  default = []
}