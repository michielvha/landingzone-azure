# Plan and Apply Credentials

## Why Two Credentials Per Workspace?

**Azure Federated Identity Credentials do NOT support wildcards in the `run_phase` field.**

This means you **cannot** create a single credential with:
```
organization:myorg:project:MyProject:workspace:myworkspace:run_phase:*
```

❌ This will NOT work - Azure will reject it during the OIDC token exchange.

## Solution: Separate Credentials for Plan and Apply

The tool automatically creates **TWO federated credentials** for each workspace:

### 1. Plan Credential
```
Subject: organization:myorg:project:MyProject:workspace:myworkspace:run_phase:plan
Name: terraform-cloud-federated-credential-plan
```

### 2. Apply Credential
```
Subject: organization:myorg:project:MyProject:workspace:myworkspace:run_phase:apply
Name: terraform-cloud-federated-credential-apply
```

## How Terraform Cloud Uses Them

When TFC runs a plan or apply, it sends an OIDC token with the appropriate subject:

- **During `terraform plan`**: TFC sends `run_phase:plan`
- **During `terraform apply`**: TFC sends `run_phase:apply`

Azure matches the incoming token against **all** federated credentials for the application. As long as ONE matches, authentication succeeds.

## Multiple Workspaces

For multiple workspaces, the tool creates numbered credentials:

```yaml
# config.yaml
terraform_cloud:
  organization: "myorg"
  project: "Default Project"
  workspaces:
    - "dev"
    - "staging"
    - "prod"
```

Results in:
```
terraform-cloud-federated-credential-plan-0   (dev workspace, plan)
terraform-cloud-federated-credential-apply-0  (dev workspace, apply)
terraform-cloud-federated-credential-plan-1   (staging workspace, plan)
terraform-cloud-federated-credential-apply-1  (staging workspace, apply)
terraform-cloud-federated-credential-plan-2   (prod workspace, plan)
terraform-cloud-federated-credential-apply-2  (prod workspace, apply)
```

## Verification

You can verify the credentials in Azure Portal:
1. Go to **Azure Active Directory** > **App Registrations**
2. Select your application (e.g., `terraform-cloud-mikevh`)
3. Click **Certificates & secrets** > **Federated credentials**
4. You should see TWO credentials per workspace

Or via Azure CLI:
```bash
az ad app federated-credential list --id <APP_ID>
```

## Troubleshooting

### Error: "No matching federated identity record found"

This means the subject claim in Azure doesn't match what TFC is sending. Check:

1. ✅ **Project name matches** - If workspace is in "Default Project", include it in config
2. ✅ **Both plan and apply credentials exist** - The tool should create both
3. ✅ **Subject format is correct** - Should include project if workspace is in one
4. ✅ **Run the tool again** - It's idempotent and will recreate credentials

### Checking TFC Subject Claims

To see what TFC is actually sending, check the plan/apply logs in Terraform Cloud. Look for OIDC-related errors that show the subject claim TFC is using.
