terraform {
  required_version = ">= 1.9"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.70"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "a85f8d7e-0a62-46f5-91c6-d0f75a0e891c"
}

provider "azuread" {
}

provider "tfe" {
  # Authentication via terraform login
}