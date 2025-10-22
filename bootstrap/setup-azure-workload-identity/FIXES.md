# Fixes Applied to the Go Binary

## Issues Found and Fixed

### 1. ✅ Interactive Mode Input Issues
**Problem:** Questions were appearing together, `Scanln` wasn't waiting for user input properly.

**Fix:** Replaced `fmt.Scanln()` with `bufio.Scanner` for better input handling:
```go
scanner := bufio.NewScanner(os.Stdin)
scanner.Scan()
input := strings.TrimSpace(scanner.Text())
```

### 2. ✅ Project Name Not Prompted in Interactive Mode
**Problem:** Interactive mode didn't ask for the project name, causing subject claim mismatches.

**Fix:** Added explicit prompt for project name with sensible default:
```go
fmt.Print("Enter your Terraform Cloud Project name (default: Default Project): ")
scanner.Scan()
config.TerraformCloud.Project = strings.TrimSpace(scanner.Text())
if config.TerraformCloud.Project == "" {
    config.TerraformCloud.Project = "Default Project"
}
```

### 3. ✅ Workspace Should Default to `*`
**Problem:** No default for workspace, should assume all workspaces.

**Fix:** Added default value for workspace:
```go
fmt.Print("Enter your Terraform Cloud Workspace name (default: * for all): ")
scanner.Scan()
config.TerraformCloud.Workspace = strings.TrimSpace(scanner.Text())
if config.TerraformCloud.Workspace == "" {
    config.TerraformCloud.Workspace = "*"
}
```

### 4. ✅ Subject Claim Construction Was Correct
**Finding:** The `constructSubjectClaim()` function was actually correct all along! It properly handles:
- Specific workspace: `organization:ORG:workspace:WORKSPACE:run_phase:*`
- All workspaces: `organization:ORG:workspace:*:run_phase:*`
- With project: `organization:ORG:project:PROJECT:workspace:WORKSPACE:run_phase:*`

The issue was just that the interactive mode wasn't asking for the project name.

### 5. ✅ Updated Documentation
**Changes:**
- Updated `config.yaml.example` to highlight the importance of the project field
- Added troubleshooting section for "No matching federated identity record" error
- Clarified that "Default Project" is the default project in TFC
- Added better defaults and clearer prompts

## New Interactive Flow

```
====================================================
Azure Workload Identity Federation Setup
for Terraform Cloud
====================================================

Enter your Terraform Cloud Organization name: mikevh
Enter your Terraform Cloud Project name (default: Default Project): [press Enter]
Enter your Terraform Cloud Workspace name (default: * for all): landingzone-azure
Enter Azure Subscription ID (leave empty for current): [press Enter]
Enter Application name (leave empty for default): [press Enter]
```

**Defaults:**
- Project: "Default Project"
- Workspace: "*" (all workspaces)
- Subscription: Current Azure subscription
- App name: "terraform-cloud-{organization}"

## Subject Claim Examples

After these fixes, the tool correctly generates:

```yaml
# Specific workspace in Default Project
organization:mikevh:project:Default Project:workspace:landingzone-azure:run_phase:*

# All workspaces in Default Project
organization:mikevh:project:Default Project:workspace:*:run_phase:*

# Specific workspace, no project (old style, rarely used)
organization:mikevh:workspace:landingzone-azure:run_phase:*
```

## Testing

Run the tests to verify:
```bash
cd bootstrap/setup-azure-workload-identity
go test -v
```

All tests should pass, including the new test case for project-based subject claims.

## What Users Should Do Now

### If You Already Ran the Tool
1. The federated credential subject won't match
2. Run the fix script: `.\bootstrap\fix-federated-credential.ps1`
3. Or delete and recreate the federated credential in Azure Portal

### Starting Fresh
1. Use the updated binary
2. When prompted, enter your project name (usually "Default Project")
3. Everything will work correctly!

## Files Modified

- ✅ `main.go` - Fixed interactive mode, added bufio import
- ✅ `main_test.go` - Added test case for project-based claims
- ✅ `config.yaml.example` - Highlighted project field importance
- ✅ `README.md` - Added troubleshooting section
- ✅ `fix-federated-credential.ps1` - Created quick fix script

## Commits Needed

```bash
git add bootstrap/setup-azure-workload-identity/
git commit -m "fix: improve interactive mode and project handling

- Use bufio.Scanner for better input handling
- Add explicit project name prompt with 'Default Project' default
- Default workspace to '*' for all workspaces
- Update documentation with troubleshooting
- Add fix script for existing deployments"
```
