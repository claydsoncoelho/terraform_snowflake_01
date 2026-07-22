# modules/compute/warehouses/variables.tf

variable "warehouses" {
  description = "Map of warehouse configurations keyed by warehouse name"
  type = map(object({
    name                                = string
    comment                             = optional(string, null)
    size                                = optional(string, "X-SMALL")
    auto_resume                         = optional(bool, true)
    auto_suspend_seconds                = optional(number, 300)
    max_cluster_count                   = optional(number, 1)
    min_cluster_count                   = optional(number, 1)
    initially_suspended                 = optional(bool, true)
    enable_query_acceleration           = optional(bool, false)
    query_acceleration_max_scale_factor = optional(number, 0)
  }))
}