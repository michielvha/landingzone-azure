terraform {
  required_version = ">= 1.9"

  # Configure Terraform Cloud backend
  cloud {
    organization = "mikevh"

    workspaces {
      name = "landingzone-azure"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0" # Accept any version >= 3.0 (including 4.x, 5.x, etc.)
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.0" # Accept any version >= 2.0 (including 3.x, 4.x, etc.)
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