# Get current Azure context
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Create Azure AD Application
resource "azuread_application" "tfc" {
  display_name = local.app_name
  description  = "Application for Terraform Cloud workload identity federation"
}

# Create Service Principal
resource "azuread_service_principal" "tfc" {
  client_id                    = azuread_application.tfc.client_id
  app_role_assignment_required = false
  description                  = "Service Principal for Terraform Cloud"
}

# Create Federated Identity Credentials (one for plan, one for apply, for each workspace)
resource "azuread_application_federated_identity_credential" "tfc" {
  for_each = local.workspace_credentials

  application_id = azuread_application.tfc.id
  display_name   = each.value.display_name
  description    = "Federated credential for TFC workspace: ${each.value.workspace} (${each.value.run_phase})"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://app.terraform.io"
  subject        = each.value.subject
}

# Assign roles to the service principal
resource "azurerm_role_assignment" "tfc" {
  for_each = { for idx, ra in var.role_assignments : idx => ra }

  scope                = each.value.scope != null ? each.value.scope : data.azurerm_subscription.current.id
  role_definition_name = each.value.role
  principal_id         = azuread_service_principal.tfc.object_id
}