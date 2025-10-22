# Quick Start Guide

Get up and running in 2 minutes!

## Step 1: Build the Binary

### On Windows (PowerShell)
```powershell
cd bootstrap/setup-azure-workload-identity
go build -o setup-azure-workload-identity.exe
```

### On Linux/macOS
```bash
cd bootstrap/setup-azure-workload-identity
go build -o setup-azure-workload-identity
chmod +x setup-azure-workload-identity
```

## Step 2: Run Interactive Setup

```bash
# Make sure you're logged into Azure CLI first
az login

# Run the interactive setup
./setup-azure-workload-identity --interactive
```

You'll be prompted for:
- Terraform Cloud Organization name
- Terraform Cloud Workspace name
- (Optional) Azure Subscription ID
- (Optional) Application name

## Step 3: Configure Terraform Cloud

The tool will output something like:

```
Add these variables to your Terraform Cloud workspace:

Environment Variables:
  TFC_AZURE_PROVIDER_AUTH = true
  TFC_AZURE_RUN_CLIENT_ID = 12345678-1234-1234-1234-123456789abc
  ARM_SUBSCRIPTION_ID     = 87654321-4321-4321-4321-abcdef123456
  ARM_TENANT_ID           = abcdef12-3456-7890-abcd-ef1234567890
```

Go to your Terraform Cloud workspace → Variables → Add these as **Environment Variables**.

## Step 4: Test It!

Create a simple test in your Terraform:

```hcl
terraform {
  cloud {
    organization = "YOUR_ORG"
    workspaces {
      name = "YOUR_WORKSPACE"
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

Run `terraform init && terraform apply` and it should authenticate successfully! 🎉

## Advanced: Config File Mode

For repeatable setups or CI/CD:

1. Create `config.yaml`:
```yaml
terraform_cloud:
  organization: "my-org"
  workspace: "azure-prod"

azure:
  role: "Contributor"
```

2. Run:
```bash
./setup-azure-workload-identity --config config.yaml --output env > .env
```

## Troubleshooting

**Problem**: Azure CLI not found  
**Solution**: Install from https://aka.ms/azure-cli

**Problem**: Not logged in  
**Solution**: Run `az login`

**Problem**: Permission denied  
**Solution**: Make sure you have Owner or User Access Administrator role

## Next Steps

- See full README.md for all configuration options
- Check out the config.yaml.example for advanced scenarios
- Use `--output json` for programmatic usage
