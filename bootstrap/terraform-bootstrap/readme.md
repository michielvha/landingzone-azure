# Terraform Bootstrap for Azure Workload Identity

This Terraform module creates the Azure AD application, service principal, and federated identity credentials needed for Terraform Cloud workload identity federation.

## Features

✅ Creates **2 credentials per workspace** (plan + apply) - Azure does NOT support `run_phase:*` wildcards  
✅ Supports multiple workspaces in a single run  
✅ Project-aware subject claims  
✅ Declarative infrastructure-as-code approach  

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.0
- Appropriate Azure AD permissions to create applications and service principals

## Usage

1. **Authenticate with az login:**

   terraform-bootstrap will use your user context to apply the initial bootstrap, make sure your user has enough rights
   ```bash
   az login --use-device-code
   ```

1. **Copy the example tfvars:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars:**
   ```hcl
   tfc_organization = "your-org"
   tfc_workspaces   = ["landingzone-azure", "staging", "prod"]
   tfc_project_name = "Default Project"  # Include if workspace is in a project
   ```

3. **Initialize and apply:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure Terraform Cloud:**
   
   Add these environment variables to each TFC workspace:
   ```
   TFC_AZURE_PROVIDER_AUTH = true
   TFC_AZURE_RUN_CLIENT_ID = <client_id from output>
   ARM_SUBSCRIPTION_ID     = <subscription_id from output>
   ARM_TENANT_ID           = <tenant_id from output>
   ```

## How It Works

For each workspace specified, this module creates **TWO** federated credentials:
- One with `run_phase:plan` for terraform plan operations
- One with `run_phase:apply` for terraform apply operations

This is required because Azure federated credentials do NOT support wildcards in the `run_phase` field.

### Example Output

For `tfc_workspaces = ["dev", "staging"]`, this creates:
- `terraform-cloud-federated-credential-plan-0` (dev, plan)
- `terraform-cloud-federated-credential-apply-0` (dev, apply)
- `terraform-cloud-federated-credential-plan-1` (staging, plan)
- `terraform-cloud-federated-credential-apply-1` (staging, apply)

## Alternative: Go Binary

For a more user-friendly CLI experience with interactive mode and automatic cleanup, consider using the Go binary instead:

```bash
cd ../setup-azure-workload-identity
./setup-azure-workload-identity --interactive
```

See [setup-azure-workload-identity README](../setup-azure-workload-identity/README.md) for details.