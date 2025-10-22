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

variable "tfc_workspace_name" {
  description = "Terraform Cloud workspace name (use 'project:*' for all workspaces in a project)"
  type        = string
  default     = "*"
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

locals {
  app_name = var.app_name != null ? var.app_name : "terraform-cloud-${var.tfc_organization}"
  
  # Determine subject based on workspace or project
  subject = var.tfc_project_name != null ? (
    "organization:${var.tfc_organization}:project:${var.tfc_project_name}:workspace:${var.tfc_workspace_name}:run_phase:*"
  ) : (
    var.tfc_workspace_name == "*" ? (
      "organization:${var.tfc_organization}:workspace:*:run_phase:*"
    ) : (
      "organization:${var.tfc_organization}:workspace:${var.tfc_workspace_name}:run_phase:*"
    )
  )
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

# Create Federated Identity Credential
resource "azuread_application_federated_identity_credential" "tfc" {
  application_id = azuread_application.tfc.id
  display_name   = "terraform-cloud-federated-credential"
  description    = "Federated credential for Terraform Cloud workload identity"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://app.terraform.io"
  subject        = local.subject
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
  description = "The subject claim used for the federated credential"
  value       = local.subject
}
