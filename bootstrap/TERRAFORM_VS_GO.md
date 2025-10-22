# Terraform Bootstrap vs Go Binary

Both approaches create the necessary Azure resources for Terraform Cloud workload identity federation. Here's how they compare:

## Quick Comparison

| Feature | Terraform Bootstrap | Go Binary |
|---------|-------------------|-----------|
| **Cross-platform** | ✅ Yes (via Terraform) | ✅ Yes (compiled binaries) |
| **Prerequisites** | Terraform + Azure CLI | Azure CLI only |
| **Configuration** | HCL/tfvars | YAML/JSON or Interactive |
| **Plan/Apply Credentials** | ✅ Creates both | ✅ Creates both |
| **Multiple Workspaces** | ✅ Yes | ✅ Yes |
| **State Management** | Requires Terraform state | ✅ Stateless |
| **Idempotency** | ✅ Terraform managed | ✅ Manual cleanup + create |
| **Interactive Mode** | ❌ No | ✅ Yes |
| **Auto Cleanup** | ❌ Must use `terraform destroy` | ✅ Automatic before create |
| **Outputs** | JSON, HCL | Text, JSON, Env |

## When to Use Terraform Bootstrap

Choose the Terraform approach if:

- ✅ You want infrastructure-as-code for the bootstrap process
- ✅ You're already managing Azure resources with Terraform
- ✅ You want Terraform state management of the credentials
- ✅ You need to integrate this into a larger Terraform workflow
- ✅ You want declarative updates and drift detection

**Example workflow:**
```bash
cd bootstrap/terraform-bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

## When to Use Go Binary

Choose the Go binary if:

- ✅ You want a quick, one-command setup
- ✅ You prefer interactive configuration
- ✅ You don't want to manage Terraform state for bootstrap
- ✅ You want automatic cleanup of old credentials
- ✅ You're setting up for the first time

**Example workflow:**
```bash
cd bootstrap/setup-azure-workload-identity
./setup-azure-workload-identity --interactive
```

## Technical Details

### Terraform Bootstrap

**Creates:**
- 1 Azure AD Application
- 1 Service Principal
- 2N Federated Credentials (N = number of workspaces, 2 per workspace for plan+apply)
- M Role Assignments (configurable)

**Uses:**
- `locals.tf` to generate workspace-phase combinations
- `for_each` to create multiple federated credentials
- Terraform state to track resources

**Subject Claim Format:**
```hcl
organization:${var.tfc_organization}:project:${var.tfc_project_name}:workspace:${workspace}:run_phase:${phase}
```

### Go Binary

**Creates:**
- 1 Azure AD Application
- 1 Service Principal  
- 2N Federated Credentials (N = number of workspaces)
- M Role Assignments (configurable)

**Uses:**
- Azure CLI commands via exec
- Temporary JSON files for credential parameters
- No state - checks for existing resources

**Subject Claim Format:**
```go
organization:%s:project:%s:workspace:%s:run_phase:%s
```

## Migration Between Approaches

### From Terraform → Go Binary

If you already used Terraform bootstrap:

1. Note your configuration from terraform.tfvars
2. Run the Go binary with same config - it will update existing resources
3. (Optional) Clean up Terraform state:
   ```bash
   terraform state rm azuread_application_federated_identity_credential.tfc
   ```

### From Go Binary → Terraform

If you used the Go binary first:

1. Import existing resources into Terraform:
   ```bash
   terraform import azuread_application.tfc <app-id>
   terraform import azuread_service_principal.tfc <sp-object-id>
   # Import each federated credential
   terraform import 'azuread_application_federated_identity_credential.tfc["workspace-plan"]' /applications/<app-id>/federatedIdentityCredentials/<cred-id>
   ```

2. Run `terraform plan` to verify no changes needed

## Recommendation

**For most users: Use the Go binary** for initial setup. It's faster, simpler, and doesn't require managing Terraform state for bootstrap resources.

**For advanced users: Use Terraform bootstrap** if you want declarative infrastructure-as-code management of your workload identity configuration.

Both approaches now correctly create separate plan and apply credentials! ✅
