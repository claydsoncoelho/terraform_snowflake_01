output "resource_monitors" {
  description = "Map of created resource monitor objects"
  value       = { for k, v in snowflake_resource_monitor.this : k => v.fully_qualified_name }
}