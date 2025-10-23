# Terraform Bootstrap for Azure Workload Identity

This Terraform module creates the Azure AD application, service principal, and federated identity credentials needed for Terraform Cloud workload identity federation.

## Features

✅ Creates **2 credentials per workspace** (plan + apply) - Azure does NOT support `run_phase:*` wildcards  
✅ Supports multiple workspaces in a single run  
✅ Project-aware subject claims  
✅ Declarative infrastructure-as-code approach  
✅ Idempotent - safe to run multiple times

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.0
- Appropriate Azure AD permissions to create applications and service principals
- Terraform Cloud organization and workspace(s) created

## Quick Start

1. **Authenticate with Azure CLI:**

   ```powershell
   az login
   ```

   The bootstrap will use your user credentials to create the initial Azure resources.

2. **Copy the example configuration:**

   ```powershell
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars:**

   ```hcl
   tfc_organization = "your-org"
   tfc_workspaces   = ["landingzone-azure"]
   tfc_project_name = "Default Project"  # Include if workspace is in a project
   ```

4. **Initialize and apply:**

   ```powershell
   terraform init
   terraform plan
   terraform apply
   ```

5. **Configure Terraform Cloud:**
   
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

## Configuration Options

### Multiple Workspaces

```hcl
tfc_workspaces = ["dev", "staging", "prod"]
```

Creates credentials for all specified workspaces.

### Wildcard Workspace

```hcl
tfc_workspaces = ["*"]
```

Allows any workspace in the organization to authenticate (still creates separate plan/apply credentials).

### Custom Role Assignments

```hcl
role_assignments = [
  {
    role  = "Contributor"
    scope = null  # Uses subscription scope
  },
  {
    role  = "Reader"
    scope = "/subscriptions/xxx/resourceGroups/my-rg"
  }
]
```

### Custom Application Name

```hcl
app_name = "my-custom-app-name"
```

Defaults to `terraform-cloud-{organization}` if not specified.

## Outputs

After successful apply, you'll see:

```hcl
client_id                = "db67dee7-..."
subscription_id          = "a85f8d7e-..."
tenant_id               = "a05a1c32-..."
terraform_cloud_variables = {
  TFC_AZURE_PROVIDER_AUTH = "true"
  TFC_AZURE_RUN_CLIENT_ID = "db67dee7-..."
  ARM_SUBSCRIPTION_ID     = "a85f8d7e-..."
  ARM_TENANT_ID          = "a05a1c32-..."
}
```

## Subject Claim Format

The subject claims follow this format:

**Without project:**
```
organization:{org}:workspace:{workspace}:run_phase:{phase}
```

**With project:**
```
organization:{org}:project:{project}:workspace:{workspace}:run_phase:{phase}
```

## Troubleshooting

### Error: Insufficient privileges to complete the operation

**Cause**: Your Azure user doesn't have permission to create app registrations.

**Solution**: Ask your Azure AD admin to grant you "Application Developer" role or higher.

### Error: Subject claim mismatch in Terraform Cloud

**Cause**: The `tfc_project_name` doesn't match your actual workspace project.

**Solution**: Check your workspace in Terraform Cloud and update `terraform.tfvars` accordingly.

### Error: Multiple federated credentials with same subject

**Cause**: Re-running bootstrap after changing workspace configuration.

**Solution**: The module is idempotent. Run `terraform apply` again to update credentials.
