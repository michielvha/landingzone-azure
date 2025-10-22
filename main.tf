terraform {
  required_version = ">= 1.0"
  
  # Configure Terraform Cloud backend
  cloud {
    organization = "mikevh"  # Replace with your TFC organization
    
    workspaces {
      name = "landingzone-azure"  # Replace with your workspace name
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
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
  use_oidc = true
  
  # These will be provided via environment variables in TFC:
  # ARM_SUBSCRIPTION_ID
  # ARM_TENANT_ID
  # TFC_AZURE_RUN_CLIENT_ID
}

provider "azuread" {
  # Uses the same OIDC authentication as azurerm
  use_oidc = true
}

# Get current Azure context
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Variables
variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Environment = "dev"
    Project     = "AzureLandingZone"
  }
}

# Management Groups (optional - for enterprise landing zones)
# module "management_groups" {
#   source = "./modules/management-groups"
#   
#   root_id          = "contoso"
#   root_name        = "Contoso"
#   management_groups = {
#     platform = {
#       display_name = "Platform"
#     }
#     landing_zones = {
#       display_name = "Landing Zones"
#     }
#   }
# }

# Core Networking
module "networking" {
  source = "./modules/networking"

  location            = var.location
  environment         = var.environment
  address_space       = ["10.0.0.0/16"]
  
  subnets = {
    gateway = {
      address_prefixes = ["10.0.0.0/24"]
    }
    firewall = {
      address_prefixes = ["10.0.1.0/24"]
    }
    management = {
      address_prefixes = ["10.0.2.0/24"]
    }
    workload = {
      address_prefixes = ["10.0.10.0/24"]
    }
  }

  tags = var.tags
}

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
