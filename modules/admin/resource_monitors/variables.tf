# modules/admin/resource_monitors/variables.tf

variable "resource_monitors" {
  description = "Resource monitor configurations. Names and defaults are normalised in the root module."
  type = list(object({
    name                      = string
    credit_quota              = number
    frequency                 = string
    start_timestamp           = string
    notify_triggers           = list(number)
    suspend_trigger           = number
    suspend_immediate_trigger = number
    set_for_account           = bool
  }))
  default = []
}