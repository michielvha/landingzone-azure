# Azure Workload Identity Setup Tool

[![Go Version](https://img.shields.io/badge/Go-1.21+-00ADD8?style=flat&logo=go)](https://go.dev/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)](https://github.com/michielvha/landingzone-azure)

A cross-platform CLI tool to set up Azure Workload Identity Federation for Terraform Cloud.

## Why a Go Binary?

✅ **Cross-Platform**: Works on Windows, Linux, macOS  
✅ **No Dependencies**: Single binary, no bash/PowerShell required  
✅ **Config-Driven**: YAML or JSON configuration files  
✅ **Portable**: Easy to distribute and version  
✅ **Better UX**: Structured output, error handling  

## Installation

### Pre-built Binaries

Download from releases (coming soon) or build from source:

```bash
# Build for your current platform
go build -o setup-azure-workload-identity

# Build for all platforms
./build.sh
```

### From Source

```bash
cd bootstrap/setup-azure-workload-identity
go mod download
go build -o setup-azure-workload-identity
```

## Usage

### Interactive Mode

The easiest way to get started:

```bash
./setup-azure-workload-identity --interactive
```

### Config File Mode

1. Copy the example config:
   ```bash
   cp config.yaml.example config.yaml
   ```

2. Edit `config.yaml` with your values:
   ```yaml
   terraform_cloud:
     organization: "my-org"
     workspace: "azure-landing-zone"
     project: "Default Project"  # ⚠️ IMPORTANT! Include this!
   
   azure:
     role: "Contributor"
   
   application:
     audience: "api://AzureADTokenExchange"
   ```

   > **⚠️ Important:** Most Terraform Cloud workspaces are automatically placed in the "Default Project". 
   > If you don't specify the project name, the subject claim won't match and authentication will fail!
   > Check your workspace in TFC to see which project it's in.

3. Run the setup:
   ```bash
   ./setup-azure-workload-identity --config config.yaml
   ```

### Output Formats

#### Default (Human-Readable)
```bash
./setup-azure-workload-identity --config config.yaml
```

#### JSON Output
```bash
./setup-azure-workload-identity --config config.yaml --output json
```

#### Environment Variables (for scripting)
```bash
./setup-azure-workload-identity --config config.yaml --output env > .env
```

## Configuration File

### Minimal Configuration

```yaml
terraform_cloud:
  organization: "my-org"
  workspace: "my-workspace"
```

### Full Configuration

```yaml
terraform_cloud:
  organization: "my-org"
  workspace: "azure-landing-zone"
  project: "infrastructure"  # Optional

azure:
  subscription_id: "xxx"  # Optional: auto-detected if empty
  tenant_id: "xxx"        # Optional: auto-detected if empty
  role: "Contributor"
  
  # Advanced: Multiple roles
  roles:
    - name: "Contributor"
      scope: "/subscriptions/xxx"
    - name: "User Access Administrator"
      scope: "/subscriptions/xxx/resourceGroups/my-rg"

application:
  name: "terraform-cloud-custom"
  audience: "api://AzureADTokenExchange"
```

### JSON Configuration

You can also use JSON instead of YAML:

```json
{
  "terraform_cloud": {
    "organization": "my-org",
    "workspace": "my-workspace"
  },
  "azure": {
    "role": "Contributor"
  },
  "application": {
    "audience": "api://AzureADTokenExchange"
  }
}
```

## Examples

### Setup for a Specific Workspace

```yaml
terraform_cloud:
  organization: "acme-corp"
  workspace: "azure-prod"

azure:
  role: "Contributor"
```

### Setup for All Workspaces in an Organization

```yaml
terraform_cloud:
  organization: "acme-corp"
  workspace: "*"
```

### Setup for a Project (All Workspaces in Project)

```yaml
terraform_cloud:
  organization: "acme-corp"
  project: "infrastructure"
  workspace: "*"
```

### Multiple Role Assignments

```yaml
terraform_cloud:
  organization: "acme-corp"
  workspace: "azure-prod"

azure:
  roles:
    - name: "Contributor"
    - name: "User Access Administrator"
      scope: "/subscriptions/xxx/resourceGroups/networking-rg"
    - name: "Key Vault Administrator"
      scope: "/subscriptions/xxx/resourceGroups/security-rg"
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Setup Azure Workload Identity
  run: |
    curl -LO https://github.com/your-org/releases/setup-azure-workload-identity
    chmod +x setup-azure-workload-identity
    ./setup-azure-workload-identity --config config.yaml --output env >> $GITHUB_ENV
```

### GitLab CI

```yaml
setup_azure:
  script:
    - ./setup-azure-workload-identity --config config.yaml --output json > azure-config.json
  artifacts:
    paths:
      - azure-config.json
```

## Building

### Single Platform

```bash
go build -o setup-azure-workload-identity
```

### Multi-Platform

```bash
# Linux
GOOS=linux GOARCH=amd64 go build -o bin/setup-azure-workload-identity-linux-amd64

# macOS (Intel)
GOOS=darwin GOARCH=amd64 go build -o bin/setup-azure-workload-identity-darwin-amd64

# macOS (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o bin/setup-azure-workload-identity-darwin-arm64

# Windows
GOOS=windows GOARCH=amd64 go build -o bin/setup-azure-workload-identity-windows-amd64.exe
```

## Troubleshooting

### Azure CLI Not Found

Make sure Azure CLI is installed and in your PATH:
- Install from: https://aka.ms/azure-cli
- Verify: `az --version`

### Not Logged In

```bash
az login
```

### Invalid Configuration

Run with verbose output:
```bash
./setup-azure-workload-identity --config config.yaml -v
```

### Error: "No matching federated identity record found"

**Full error:**
```
AADSTS700213: No matching federated identity record found for presented assertion subject 
'organization:myorg:project:Default Project:workspace:myworkspace:run_phase:plan'
```

**Cause:** The subject claim in your federated credential doesn't match what Terraform Cloud is sending.

**Solution:** 
1. Check the error message to see what subject TFC is actually using
2. If it includes `project:Default Project:`, add this to your config:
   ```yaml
   terraform_cloud:
     organization: "myorg"
     workspace: "myworkspace"
     project: "Default Project"  # ← Add this!
   ```
3. Re-run the setup tool to recreate the federated credential with the correct subject

**Quick Fix Script:**
```powershell
# Use the fix script we created
cd bootstrap
.\fix-federated-credential.ps1
```

## Development

### Run Tests

```bash
go test ./...
```

### Run with Hot Reload

```bash
go run main.go --interactive
```

### Format Code

```bash
go fmt ./...
```

## License

MIT
