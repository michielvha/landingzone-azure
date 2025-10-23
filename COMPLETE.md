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
