# Azure Landing Zone with Terraform Cloud - Complete Setup Guide

This guide walks you through setting up Azure workload identity federation with Terraform Cloud from scratch.

## Overview

**Workload Identity Federation** allows Terraform Cloud to authenticate to Azure without storing any secrets. It uses OpenID Connect (OIDC) to establish a trust relationship between Terraform Cloud and Azure Active Directory.

## Prerequisites

- [ ] Azure subscription with Owner or User Access Administrator permissions
- [ ] Azure CLI installed (`az --version` to verify)
- [ ] Terraform Cloud account (free tier works)
- [ ] Git installed

## Step-by-Step Setup

### 1. Prepare Azure CLI

```powershell
# Login to Azure
az login

# Verify you're in the correct subscription
az account show

# If needed, set the correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Create Terraform Cloud Organization & Workspace

1. Go to [app.terraform.io](https://app.terraform.io)
2. Create a new organization (or use existing)
3. Create a new workspace:
   - Choose "CLI-driven workflow"
   - Name it `azure-landing-zone` (or your preferred name)
   - Click "Create workspace"

### 3. Set Up Workload Identity Federation

Choose one of these methods:

#### Option A: PowerShell Script (Recommended for Windows)

```powershell
cd bootstrap
.\setup-workload-identity.ps1
```

When prompted, enter:
- **TFC Organization**: Your Terraform Cloud org name
- **TFC Workspace**: `azure-landing-zone` (or your workspace name)
- **Subscription ID**: Press Enter to use current subscription
- **App Name**: Press Enter to use default

#### Option B: Bash Script (For WSL/Linux/macOS)

```bash
cd bootstrap
chmod +x setup-workload-identity.sh
./setup-workload-identity.sh
```

#### Option C: Terraform Bootstrap (Most Automated)

```powershell
cd bootstrap/terraform-bootstrap

# Copy and edit the tfvars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Run Terraform
terraform init
terraform plan
terraform apply
```

### 4. Configure Terraform Cloud Workspace

After running the setup script, you'll get output like this:

```
TFC_AZURE_PROVIDER_AUTH = true
TFC_AZURE_RUN_CLIENT_ID = 12345678-1234-1234-1234-123456789abc
ARM_SUBSCRIPTION_ID = 87654321-4321-4321-4321-abcdef123456
ARM_TENANT_ID = abcdef12-3456-7890-abcd-ef1234567890
```

Now configure your workspace:

1. Go to your workspace in Terraform Cloud
2. Navigate to **Variables**
3. Add these **Environment Variables** (not Terraform variables):

   | Variable | Value | Sensitive |
   |----------|-------|-----------|
   | `TFC_AZURE_PROVIDER_AUTH` | `true` | No |
   | `TFC_AZURE_RUN_CLIENT_ID` | `<your-client-id>` | No |
   | `ARM_SUBSCRIPTION_ID` | `<your-subscription-id>` | No |
   | `ARM_TENANT_ID` | `<your-tenant-id>` | No |

### 5. Update Terraform Configuration

Edit `main.tf` in the root directory:

```hcl
terraform {
  cloud {
    organization = "YOUR_ORG_NAME"  # ← Change this
    
    workspaces {
      name = "azure-landing-zone"    # ← Change this if needed
    }
  }
}
```

### 6. Initialize and Deploy

```powershell
# Login to Terraform Cloud
terraform login

# Initialize Terraform (will migrate to TFC)
terraform init

# Plan the deployment
terraform plan

# Apply (can also be done in TFC UI)
terraform apply
```

### 7. Verify the Setup

After applying, check that:

1. ✅ The Terraform run completed successfully in TFC
2. ✅ Resources were created in Azure portal
3. ✅ No authentication errors in the logs

## Understanding the Architecture

### What Was Created in Azure?

1. **Azure AD Application**: Represents Terraform Cloud
2. **Service Principal**: The identity TFC uses
3. **Federated Credential**: The OIDC trust configuration
4. **Role Assignment**: Permissions (usually Contributor)

### How Does Authentication Work?

```
┌─────────────────┐
│ Terraform Cloud │
│   (Run starts)  │
└────────┬────────┘
         │ 1. Request token with claims
         ▼
┌─────────────────────────┐
│  https://app.terraform.io│
│    (OIDC Issuer)        │
└────────┬────────────────┘
         │ 2. Issue JWT token
         ▼
┌──────────────────────┐
│   Azure AD           │
│ - Verify issuer      │
│ - Verify subject     │
│ - Verify audience    │
└────────┬─────────────┘
         │ 3. Exchange for Azure token
         ▼
┌──────────────────────┐
│ Azure Resources      │
│ (Deploy/Manage)      │
└──────────────────────┘
```

### Key Security Points

- ✅ **No secrets stored**: No client secrets or passwords anywhere
- ✅ **Short-lived tokens**: Azure tokens expire quickly
- ✅ **Specific scope**: Trust is limited to your TFC org/workspace
- ✅ **Audit trail**: All actions logged in Azure Activity Log

## Troubleshooting

### Error: "Failed to obtain OIDC token"

**Cause**: Environment variables not set correctly in TFC

**Solution**: Double-check all 4 environment variables are set as **Environment Variables** (not Terraform variables)

### Error: "AADSTS700016: Application not found"

**Cause**: Client ID is incorrect or app registration doesn't exist

**Solution**: Verify `TFC_AZURE_RUN_CLIENT_ID` matches the Application ID in Azure portal

### Error: "AADSTS70021: No matching federated identity record found"

**Cause**: Subject claim mismatch

**Solution**: 
1. Check your org and workspace names match exactly
2. Verify the federated credential in Azure portal
3. Subject should be: `organization:YOUR_ORG:workspace:YOUR_WORKSPACE:run_phase:*`

### Error: "AuthorizationFailed"

**Cause**: Service principal doesn't have required permissions

**Solution**: 
1. Go to Azure portal → Subscriptions → IAM
2. Verify the app has Contributor role
3. Wait 5-10 minutes for permissions to propagate

## Advanced Configurations

### Use Project-Level Credentials

To use one set of credentials for all workspaces in a project:

```powershell
# When running setup script
Enter workspace name: project:YOUR_PROJECT_NAME
```

Subject claim becomes: `organization:YOUR_ORG:project:YOUR_PROJECT:workspace:*:run_phase:*`

### Custom Role Assignments

Edit `bootstrap/terraform-bootstrap/terraform.tfvars`:

```hcl
role_assignments = [
  {
    role  = "Contributor"
    scope = null  # Subscription scope
  },
  {
    role  = "User Access Administrator"
    scope = "/subscriptions/xxx/resourceGroups/my-rg"
  }
]
```

### Multiple Environments

Create separate workspaces for each environment:

```hcl
# In Terraform Cloud, create:
# - azure-landing-zone-dev
# - azure-landing-zone-staging  
# - azure-landing-zone-prod

# Each workspace can have different variable values
```

## Next Steps

1. **Add Policies**: Implement Azure Policy for governance
2. **Enable Monitoring**: Set up Log Analytics and Azure Monitor
3. **Add Security**: Configure Azure Defender, Key Vault
4. **Hub-Spoke Networking**: Expand to hub-spoke topology
5. **Management Groups**: For enterprise-scale deployments

## Resources

- [Terraform Cloud Dynamic Credentials for Azure](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration)
- [Azure Workload Identity Federation](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [Azure Landing Zones](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Terraform azurerm Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## Support

For issues:
1. Check Terraform Cloud run logs
2. Check Azure Activity Log
3. Review this troubleshooting guide
4. Open an issue in this repository
