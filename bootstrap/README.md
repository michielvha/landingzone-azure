# Bootstrap - Workload Identity Federation Setup

This directory contains multiple tools to set up workload identity federation between Terraform Cloud and Azure.

## What Gets Created

1. **Azure AD Application**: Represents Terraform Cloud in Azure AD
2. **Service Principal**: Identity that Terraform Cloud will use
3. **Federated Credential**: Trust relationship using OIDC
4. **Role Assignments**: Permissions for the service principal

## Prerequisites

- Azure CLI installed and authenticated
- Permissions to create App Registrations and assign roles
- Your Terraform Cloud organization name
- Your Terraform Cloud workspace name (or use wildcards)

## Usage

### Option 1: Using Go Binary (Recommended - Cross-Platform) ⭐

**Works on Windows, Linux, and macOS with a single binary!**

```bash
cd setup-azure-workload-identity

# Interactive mode (easiest)
./setup-azure-workload-identity --interactive

# Or use a config file
cp config.yaml.example config.yaml
# Edit config.yaml with your values
./setup-azure-workload-identity --config config.yaml
```

See [setup-azure-workload-identity/README.md](./setup-azure-workload-identity/README.md) for detailed usage.

### Option 2: Using Bash Script (Linux/macOS/WSL)

```bash
chmod +x setup-workload-identity.sh
./setup-workload-identity.sh
```

### Option 3: Using PowerShell Script (Windows)

```powershell
.\setup-workload-identity.ps1
```

### Option 4: Using Terraform Bootstrap

```bash
cd terraform-bootstrap
terraform init
terraform apply
```

## Outputs

After running the setup, you'll receive:

```
ARM_CLIENT_ID=<application-id>
ARM_SUBSCRIPTION_ID=<subscription-id>
ARM_TENANT_ID=<tenant-id>
```

## Configuring Terraform Cloud

1. Go to your workspace in Terraform Cloud
2. Navigate to Variables
3. Add these as **Environment Variables**:
   - `TFC_AZURE_PROVIDER_AUTH` = `true` (enables dynamic credentials)
   - `TFC_AZURE_RUN_CLIENT_ID` = `<application-id from above>`
   - `ARM_SUBSCRIPTION_ID` = `<subscription-id>`
   - `ARM_TENANT_ID` = `<tenant-id>`

## Verification

Test the setup with a simple Terraform configuration:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

data "azurerm_subscription" "current" {}

output "subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
}
```
