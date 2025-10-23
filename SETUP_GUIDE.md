# Azure Landing Zone with Terraform Cloud - Setup Guide

This guide walks you through setting up Azure workload identity federation with Terraform Cloud using only Terraform and Azure CLI.

## Overview

**Workload Identity Federation** allows Terraform Cloud to authenticate to Azure without storing any secrets. It uses OpenID Connect (OIDC) to establish a trust relationship between Terraform Cloud and Azure Active Directory.

## Prerequisites

- [ ] Azure subscription with Owner or User Access Administrator permissions
- [ ] Azure CLI installed (`az --version` to verify)
- [ ] Terraform installed locally (for bootstrap)
- [ ] Terraform Cloud account (free tier works)

## Step-by-Step Setup

### 1. Login to Azure

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
   - Name it `landingzone-azure` (or your preferred name)
   - Click "Create workspace"

### 3. Bootstrap with Terraform

Navigate to the bootstrap directory and configure:

```powershell
cd bootstrap

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your details
notepad terraform.tfvars
```

Edit the file:
```hcl
tfc_organization = "your-org-name"
tfc_workspaces   = ["landingzone-azure"]
tfc_project_name = "Default Project"  # Include if workspace is in a project
```

Run Terraform to create the Azure resources:

```powershell
# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Apply the configuration
terraform apply
```

This creates:
- Azure AD Application
- Service Principal  
- Federated Identity Credentials (separate for plan & apply phases)
- Role Assignment (Contributor by default)

### 4. Configure Terraform Cloud Workspace

After the bootstrap completes, copy the output values to Terraform Cloud:

```powershell
# View the outputs
terraform output
```

Now configure your workspace:

1. Go to your workspace in Terraform Cloud
2. Navigate to **Variables**
3. Add these **Environment Variables** (not Terraform variables):

   | Variable | Value | Sensitive |
   |----------|-------|-----------|
   | `TFC_AZURE_PROVIDER_AUTH` | `true` | No |
   | `TFC_AZURE_RUN_CLIENT_ID` | `<client_id from output>` | No |
   | `ARM_SUBSCRIPTION_ID` | `<subscription_id from output>` | No |
   | `ARM_TENANT_ID` | `<tenant_id from output>` | No |

### 5. Update Root Terraform Configuration

Edit `main.tf` in the repository root:

```hcl
terraform {
  cloud {
    organization = "your-org-name"  # ← Change this
    
    workspaces {
      name = "landingzone-azure"    # ← Change this if needed
    }
  }
}
```

### 6. Deploy the Landing Zone

```powershell
# Return to repository root
cd ..

# Login to Terraform Cloud
terraform login

# Initialize with TFC backend
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
3. **Federated Credentials**: Two per workspace (plan & apply phases)
4. **Role Assignment**: Permissions (Contributor by default)

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

### Why Two Credentials Per Workspace?

Azure federated credentials **do not support wildcards** in the `run_phase` field. Therefore, the bootstrap creates:
- One credential with `run_phase:plan` for terraform plan operations
- One credential with `run_phase:apply` for terraform apply operations

This ensures both planning and applying work correctly in Terraform Cloud.

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
1. Check your org and workspace names match exactly in `terraform.tfvars`
2. Verify the federated credentials in Azure portal
3. If workspace is in a project, ensure `tfc_project_name` is set correctly
4. Subject format: `organization:ORG:project:PROJECT:workspace:WORKSPACE:run_phase:PHASE`

### Error: "AuthorizationFailed"

**Cause**: Service principal doesn't have required permissions

**Solution**: 
1. Go to Azure portal → Subscriptions → IAM
2. Verify the app has Contributor role
3. Wait 5-10 minutes for permissions to propagate

## Advanced Configurations

### Multiple Workspaces

To create credentials for multiple workspaces:

```hcl
# In bootstrap/terraform.tfvars
tfc_workspaces = ["dev", "staging", "prod"]
```

This creates 6 federated credentials total (2 per workspace).

### Custom Role Assignments

Edit `bootstrap/terraform.tfvars`:

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

### Wildcard Workspace Credentials

To allow any workspace in your organization:

```hcl
# In bootstrap/terraform.tfvars
tfc_workspaces = ["*"]
```

Note: This still creates separate plan and apply credentials.

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
