# modules/security/role_grants/variables.tf

variable "role_grants" {
  description = "A list of role-to-role inheritance configurations"
  type = list(object({
    role        = string # The role being granted (e.g., "TRANSFORMER_ROLE")
    parent_role = string # The recipient role (e.g., "SYSADMIN")
  }))
  default = []
}