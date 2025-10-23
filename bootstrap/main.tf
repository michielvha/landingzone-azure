# TODO: Check if we cannot use the values generated here to be set as an environmentset by terraform (we will need it in all namespaces)

terraform {
  required_version = ">= 1.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}

# Get current Azure context
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Variables
variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "tfc_workspaces" {
  description = "List of Terraform Cloud workspace names to create credentials for"
  type        = list(string)
  default     = ["*"]
}

variable "tfc_project_name" {
  description = "Terraform Cloud project name (optional, for project-level credentials)"
  type        = string
  default     = null
}

variable "app_name" {
  description = "Name for the Azure AD application"
  type        = string
  default     = null
}

variable "role_assignments" {
  description = "List of role assignments for the service principal"
  type = list(object({
    role  = string
    scope = optional(string)
  }))
  default = [
    {
      role  = "Contributor"
      scope = null # Will use subscription scope
    }
  ]
}

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

# Outputs
output "client_id" {
  description = "Application (client) ID - use for TFC_AZURE_RUN_CLIENT_ID"
  value       = azuread_application.tfc.client_id
}

output "subscription_id" {
  description = "Subscription ID - use for ARM_SUBSCRIPTION_ID"
  value       = data.azurerm_subscription.current.subscription_id
}

output "tenant_id" {
  description = "Tenant ID - use for ARM_TENANT_ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "terraform_cloud_variables" {
  description = "Variables to set in Terraform Cloud workspace"
  value = {
    TFC_AZURE_PROVIDER_AUTH = "true"
    TFC_AZURE_RUN_CLIENT_ID = azuread_application.tfc.client_id
    ARM_SUBSCRIPTION_ID     = data.azurerm_subscription.current.subscription_id
    ARM_TENANT_ID           = data.azurerm_client_config.current.tenant_id
  }
}

output "subject_claim" {
  description = "The subject claims used for the federated credentials"
  value       = { for k, v in local.workspace_credentials : k => v.subject }
}

output "federated_credentials" {
  description = "Map of all created federated credentials"
  value = {
    for k, v in local.workspace_credentials : k => {
      workspace    = v.workspace
      run_phase    = v.run_phase
      subject      = v.subject
      display_name = v.display_name
    }
  }
}
