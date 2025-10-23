# Azure Landing Zone Setup - Complete! ✅

## What We Built

A complete Azure Landing Zone repository for Terraform Cloud with **OIDC Workload Identity Federation** - no client secrets needed!

### Key Components

1. **Terraform Bootstrap Module**
   - Creates Azure AD Application and Service Principal
   - Configures Federated Identity Credentials
   - Sets up role assignments
   - Idempotent and declarative

2. **Landing Zone Infrastructure**
   - Networking module with VNet, subnets, NSGs
   - Terraform Cloud backend configuration
   - Azure provider with OIDC enabled

3. **Pure Terraform Approach**
   - No custom scripts or binaries needed
   - Uses Azure CLI for initial authentication only
   - Everything else is Terraform

## Critical Discoveries

### 1. Azure Doesn't Support run_phase Wildcards ⚠️

**Problem**: Originally tried to use `run_phase:*` in federated credentials.

**Azure Error**: "No matching federated identity record found"

**Solution**: Create TWO separate credentials per workspace:
- `run_phase:plan` for terraform plan operations
- `run_phase:apply` for terraform apply operations

### 2. TFC Workspaces in Projects MUST Include Project in Subject

**Problem**: Subject claim mismatch - Azure had no project, TFC was sending project.

**Root Cause**: Terraform Cloud automatically includes the project name in the OIDC subject claim when a workspace is in a project (including "Default Project").

**Solution**: Always specify the project in your config:
```hcl
tfc_project_name = "Default Project"  # REQUIRED if workspace is in a project!
```

## Current Setup

### Azure Resources Created
- **Application**: `terraform-cloud-mikevh` (db67dee7-f73a-4cc0-9cd8-e6baae221ca4)
- **Service Principal**: Linked to application
- **Federated Credentials**:
  - `terraform-cloud-federated-credential-plan`
    - Subject: `organization:mikevh:project:Default Project:workspace:landingzone-azure:run_phase:plan`
  - `terraform-cloud-federated-credential-apply`
    - Subject: `organization:mikevh:project:Default Project:workspace:landingzone-azure:run_phase:apply`
- **Role Assignment**: Contributor on subscription a85f8d7e-0a62-46f5-91c6-d0f75a0e891c

### TFC Environment Variables
Already configured in workspace `landingzone-azure`:
```
TFC_AZURE_PROVIDER_AUTH = true
TFC_AZURE_RUN_CLIENT_ID = db67dee7-f73a-4cc0-9cd8-e6baae221ca4
ARM_SUBSCRIPTION_ID     = a85f8d7e-0a62-46f5-91c6-d0f75a0e891c
ARM_TENANT_ID           = a05a1c32-1d1e-46dd-9dc8-faa312104c77
```

## Verified Working ✅

Last successful test:
```bash
$ terraform plan
...
Plan: 14 to add, 0 to change, 0 to destroy.
```

The plan successfully:
- ✅ Authenticated via OIDC (no client secret!)
- ✅ Fetched Azure subscription and client config
- ✅ Planned to create 14 networking resources

## How to Use This Repository

### Initial Bootstrap (One-Time Setup)

```powershell
# 1. Login to Azure
az login

# 2. Run the Terraform bootstrap
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your TFC org and workspace names

terraform init
terraform apply

# 3. Copy outputs to Terraform Cloud workspace variables
terraform output
```

### Deploy the Landing Zone

```powershell
# 1. Login to Terraform Cloud
terraform login

# 2. Initialize with TFC backend
cd ..
terraform init

# 3. Deploy infrastructure
terraform apply
```

This will create:
- 1 Resource Group (`lz-dev-network-rg`)
- 1 Virtual Network (`lz-dev-vnet`)
- 4 Subnets (gateway, firewall, management, workload)
- 4 Network Security Groups
- 4 NSG-to-Subnet associations

### To Add More Workspaces

1. Create new workspaces in TFC (e.g., `staging`, `prod`)
2. Update `bootstrap/terraform.tfvars`:
   ```hcl
   tfc_workspaces = ["landingzone-azure", "staging", "prod"]
   ```
3. Re-run the bootstrap:
   ```powershell
   cd bootstrap
   terraform apply
   ```

This will create plan+apply credentials for all workspaces (2 credentials × 3 workspaces = 6 total).

### To Extend the Landing Zone

Add more modules for:
- **Identity**: Azure AD groups, service principals
- **Management**: Log Analytics, Azure Monitor
- **Security**: Azure Policy, Security Center, Key Vault
- **Compute**: VM scale sets, App Services, AKS
- **Database**: SQL Database, Cosmos DB, PostgreSQL

## File Structure

```
landingzone-azure/
├── README.md                   # Quick start guide
├── SETUP_GUIDE.md             # Detailed setup instructions
├── COMPLETE.md                # This file - project summary
├── main.tf                    # Root module with TFC backend
├── bootstrap/
│   ├── main.tf                # Azure AD app & federated credentials
│   ├── locals.tf              # Subject claim generation logic
│   ├── terraform.tfvars       # Your TFC configuration
│   ├── terraform.tfvars.example
│   └── README.md
└── modules/
    └── networking/
        ├── main.tf            # VNet, subnets, NSGs
        ├── variables.tf
        └── outputs.tf
```

## Key Learnings for Future Projects

1. **Always check TFC workspace project** - It affects OIDC subject claims
2. **Azure federated creds are very specific** - No wildcards in run_phase
3. **Terraform for everything** - No need for custom scripts or binaries
4. **Azure CLI for bootstrap only** - User context is sufficient for initial setup
5. **Idempotency is critical** - Terraform handles this naturally
6. **Document edge cases** - Save others from the same debugging journey

## Resources

- [Terraform Cloud OIDC Docs](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration)
- [Azure Federated Identity Docs](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Azure Landing Zone Best Practices](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)

---

**Status**: ✅ **COMPLETE AND WORKING**

Last updated: October 23, 2025

---

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
