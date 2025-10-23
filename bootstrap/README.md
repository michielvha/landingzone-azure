# Terraform Bootstrap for Azure Workload Identity

This Terraform module creates the Azure AD application, service principal, and federated identity credentials needed for Terraform Cloud workload identity federation. It also automatically configures a **global Terraform Cloud Variable Set** with all required Azure credentials - no manual configuration needed!

## Features

✅ Creates **2 federated credentials per workspace** (plan + apply) - Azure does NOT support `run_phase:*` wildcards  
✅ Supports multiple workspaces in a single run  
✅ Project-aware subject claims  
✅ **Automatic Variable Set** - credentials available in all workspaces  
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

2. **Authenticate with Terraform Cloud:**

   ```powershell
   terraform login
   ```

   This will open your browser to generate a token and store it automatically in `~/.terraform.d/credentials.tfrc.json`.
   
   > **Note:** You only need to do this once. The TFE provider will use these credentials to create the variable set.

3. **Copy the example configuration:**

   ```powershell
   cp terraform.tfvars.example terraform.tfvars
   ```

4. **Edit terraform.tfvars:**

   ```hcl
   tfc_organization = "your-org"
   tfc_workspaces   = ["landingzone-azure"]
   tfc_project_name = "Default Project"  # Include if workspace is in a project
   ```

5. **Initialize and apply:**

   ```powershell
   terraform init
   terraform plan
   terraform apply
   ```

   This will:
   - ✅ Create Azure AD application and service principal
   - ✅ Create federated identity credentials
   - ✅ Assign Azure RBAC roles
   - ✅ **Create a global variable set in Terraform Cloud**
   - ✅ **Populate the variable set with all required environment variables**
   
   All your workspaces will automatically have access to the Azure credentials! 🎉

## What Gets Created

### Azure Resources
- **Azure AD Application** for workload identity
- **Service Principal** linked to the application
- **Federated Identity Credentials** (2 per workspace: plan + apply)
- **Role Assignments** (default: Contributor at subscription level)

### Terraform Cloud Resources (Automatic!)
- **Global Variable Set** named "Azure Workload Identity Credentials"
- **Environment Variables** automatically set in all workspaces:
  - `TFC_AZURE_PROVIDER_AUTH = true`
  - `TFC_AZURE_RUN_CLIENT_ID = <client_id>`
  - `ARM_SUBSCRIPTION_ID = <subscription_id>`
  - `ARM_TENANT_ID = <tenant_id>`

The variable set is **global** by default, meaning:
- ✅ Automatically available in **all workspaces** in your TFC organization
- ✅ No need to manually assign to each workspace
- ✅ New workspaces automatically get the credentials
- ✅ Centralized management - update once, applies everywhere

### Verification

After applying, you can verify the variable set was created:

1. Go to your Terraform Cloud organization
2. Navigate to **Settings** → **Variable Sets**
3. You should see **"Azure Workload Identity Credentials"**
4. Click on it to view the 4 environment variables
5. Check the **"Applied to workspaces"** section - it should show as **Global**

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

### Error: 401 Unauthorized when creating Variable Set

**Cause**: The TFE provider cannot authenticate with Terraform Cloud.

**Solution**: 
1. Run `terraform login` to authenticate with Terraform Cloud
2. Or verify your token in `~/.terraform.d/credentials.tfrc.json`
3. Or manually set `$env:TFE_TOKEN = "your-api-token"` (not recommended for local use)

## Advanced Configuration

### Make Variable Set Workspace-Specific

If you don't want the variable set to be global, modify the `tfe_variable_set` resource:

```hcl
resource "tfe_variable_set" "azure_credentials" {
  name         = "Azure Workload Identity Credentials"
  description  = "Azure credentials for workload identity federation"
  organization = var.tfc_organization
  global       = false  # Change to false
}

# Then add workspace assignments
resource "tfe_workspace_variable_set" "workspaces" {
  for_each = toset(var.tfc_workspaces)
  
  variable_set_id = tfe_variable_set.azure_credentials.id
  workspace_id    = data.tfe_workspace.workspaces[each.key].id
}
```

### Add Additional Variables

You can add more variables to the set:

```hcl
resource "tfe_variable" "custom_var" {
  key             = "MY_CUSTOM_VAR"
  value           = "my-value"
  category        = "env"  # or "terraform" for Terraform variables
  description     = "My custom variable"
  variable_set_id = tfe_variable_set.azure_credentials.id
  sensitive       = true  # Mark as sensitive if needed
}
```

## Learn More

- [Azure Workload Identity Federation](https://learn.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation)
- [Terraform Cloud Variable Sets](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/variables/managing-variables#variable-sets)
- [TFE Provider Documentation](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs)
