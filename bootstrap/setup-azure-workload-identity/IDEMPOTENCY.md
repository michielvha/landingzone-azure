# Idempotency Fixes

## Problem
The tool failed when run multiple times because it tried to create resources that already existed:
- Azure AD Application
- Service Principal  
- Federated Credential
- Role Assignments

## Solution
Made the tool **idempotent** - safe to run multiple times. Now it:
1. ✅ Checks if resources exist before creating
2. ✅ Reuses existing resources
3. ✅ Updates federated credentials if needed
4. ✅ Skips role assignments that already exist

## Changes Made

### 1. Azure AD Application - Check Before Create
```go
// Before: Always created new app
appID, err := runAzCommand(ctx, "ad", "app", "create", ...)

// After: Check if exists first
appID, err := runAzCommand(ctx, "ad", "app", "list",
    "--display-name", config.Application.Name,
    "--query", "[0].appId", "-o", "tsv")

if appID == "" {
    // Create if doesn't exist
    appID, err = runAzCommand(ctx, "ad", "app", "create", ...)
} else {
    fmt.Printf("✅ Found existing application: %s\n", appID)
}
```

### 2. Service Principal - Check Before Create
```go
// Check if SP exists for this app
spID, err := runAzCommand(ctx, "ad", "sp", "list",
    "--filter", fmt.Sprintf("appId eq '%s'", applicationID),
    "--query", "[0].id", "-o", "tsv")

if spID == "" {
    // Create if doesn't exist
    runAzCommand(ctx, "ad", "sp", "create", "--id", applicationID)
} else {
    fmt.Println("✅ Service Principal already exists")
}
```

### 3. Federated Credential - Delete & Recreate to Update
```go
// Check if credential exists
existingCred, err := runAzCommand(ctx, "ad", "app", "federated-credential", "list",
    "--id", applicationID,
    "--query", "[?name=='terraform-cloud-federated-credential'].name | [0]", "-o", "tsv")

if existingCred != "" {
    // Delete old one
    runAzCommand(ctx, "ad", "app", "federated-credential", "delete", ...)
}

// Create new/updated credential
runAzCommand(ctx, "ad", "app", "federated-credential", "create", ...)
```

This is important because you **can't update** the subject claim on an existing credential - you must delete and recreate it.

### 4. Role Assignments - Check Before Create
```go
// Check if role assignment exists
existingRole, err := runAzCommand(ctx, "role", "assignment", "list",
    "--assignee", applicationID,
    "--role", roleName,
    "--scope", scope,
    "--query", "[0].id", "-o", "tsv")

if existingRole != "" {
    fmt.Printf("✅ Role already assigned: %s\n", roleName)
    continue
}

// Create if doesn't exist
runAzCommand(ctx, "role", "assignment", "create", ...)
```

### 5. Cross-Platform Sleep
```go
// Before: Unix-only
exec.Command("sleep", "5").Run()

// After: Works everywhere
time.Sleep(5 * time.Second)
```

## Benefits

### ✅ Safe to Run Multiple Times
```bash
# First run - creates everything
./setup-azure-workload-identity --config config.yaml

# Second run - updates federated credential, reuses everything else
./setup-azure-workload-identity --config config.yaml

# Update project name - just updates the credential
# Edit config.yaml: project: "My New Project"
./setup-azure-workload-identity --config config.yaml
```

### ✅ Easy to Fix Misconfigurations
If you initially forgot to specify the project:
```bash
# First run - wrong subject claim
./setup-azure-workload-identity --config config-no-project.yaml

# Edit config to add project
# config.yaml: project: "Default Project"

# Re-run - updates federated credential with correct subject
./setup-azure-workload-identity --config config.yaml
```

### ✅ No Manual Cleanup Needed
Before: Had to manually delete app registration to try again
After: Just re-run with updated config

## Output Example

```
🔨 Checking for existing Azure AD Application...
✅ Found existing application: db67dee7-f73a-4cc0-9cd8-e6baae221ca4

🔨 Checking for existing Service Principal...
✅ Service Principal already exists

⏳ Waiting for propagation (5 seconds)...

📋 Subject claim: organization:mikevh:project:Default Project:workspace:landingzone-azure:run_phase:*

🔨 Checking for existing Federated Identity Credential...
📝 Updating existing federated credential...
📝 Creating Federated Identity Credential...
✅ Federated credential created

🔨 Assigning roles...
✅ Role already assigned: Contributor (scope: /subscriptions/...)

======================================================
✅ Setup Complete!
======================================================
```

## Use Cases

### 1. Update Project Name
```bash
# Original config
terraform_cloud:
  workspace: "landingzone-azure"

# Updated config  
terraform_cloud:
  workspace: "landingzone-azure"
  project: "Default Project"  # Added

# Re-run tool - updates federated credential only
./setup-azure-workload-identity --config config.yaml
```

### 2. Add More Role Assignments
```yaml
# config.yaml
azure:
  roles:
    - name: "Contributor"
    - name: "User Access Administrator"  # Added new role
```

Re-run - adds new role, skips existing Contributor role.

### 3. Change Workspace from Specific to Wildcard
```yaml
# Before
workspace: "prod"

# After
workspace: "*"
```

Re-run - updates federated credential with new subject claim.

## Testing

The tool is now safe to test repeatedly:
```bash
# Try it multiple times
./setup-azure-workload-identity --interactive

# Should succeed every time
# Should reuse existing resources
# Should update federated credential if subject changed
```

## Backwards Compatible

- ✅ Still works for fresh setups
- ✅ Handles existing resources gracefully
- ✅ No breaking changes to config format
- ✅ Same output format
