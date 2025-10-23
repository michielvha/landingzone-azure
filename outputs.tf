# Outputs
output "subscription_id" {
  description = "Current subscription ID"
  value       = data.azurerm_subscription.current.subscription_id
}

output "tenant_id" {
  description = "Current tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "virtual_network_id" {
  description = "Virtual network ID"
  value       = module.networking.virtual_network_id
}
