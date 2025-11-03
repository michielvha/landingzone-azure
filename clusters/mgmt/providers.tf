terraform {
  # Configure Terraform Cloud backend
  cloud {
    organization = "mikevh"

    workspaces {
      name = "clusters-mgmt"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.0.0,<5.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=3.0.0,<4.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }

  # Enable OIDC authentication for Terraform Cloud
  use_oidc        = true
  subscription_id = "a85f8d7e-0a62-46f5-91c6-d0f75a0e891c"

  # These should be provided via environment variables in TFC:
  # ARM_SUBSCRIPTION_ID
  # ARM_TENANT_ID
  # TFC_AZURE_RUN_CLIENT_ID
}

provider "azuread" {
  # Uses the same OIDC authentication as azurerm
  use_oidc = true
}
