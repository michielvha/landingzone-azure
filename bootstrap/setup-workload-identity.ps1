# Azure Workload Identity Federation Setup for Terraform Cloud
# PowerShell version

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Azure Workload Identity Federation Setup" -ForegroundColor Cyan
Write-Host "for Terraform Cloud" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Prompt for required information
$TFC_ORG = Read-Host "Enter your Terraform Cloud Organization name"
$TFC_WORKSPACE = Read-Host "Enter your Terraform Cloud Workspace name (or 'project:*' for all workspaces in a project)"
$SUBSCRIPTION_ID = Read-Host "Enter your Azure Subscription ID (leave empty to use current)"
$APP_NAME_INPUT = Read-Host "Enter a name for the Azure AD Application (default: terraform-cloud-$TFC_ORG)"

# Set defaults
if ([string]::IsNullOrWhiteSpace($APP_NAME_INPUT)) {
    $APP_NAME = "terraform-cloud-$TFC_ORG"
} else {
    $APP_NAME = $APP_NAME_INPUT
}

$TFC_AUDIENCE = "api://AzureADTokenExchange"

# Get current subscription if not provided
if ([string]::IsNullOrWhiteSpace($SUBSCRIPTION_ID)) {
    $SUBSCRIPTION_ID = (az account show --query id -o tsv)
    Write-Host "Using current subscription: $SUBSCRIPTION_ID" -ForegroundColor Yellow
}

$TENANT_ID = (az account show --query tenantId -o tsv)

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Green
Write-Host "  Organization: $TFC_ORG"
Write-Host "  Workspace: $TFC_WORKSPACE"
Write-Host "  Subscription: $SUBSCRIPTION_ID"
Write-Host "  Tenant: $TENANT_ID"
Write-Host "  App Name: $APP_NAME"
Write-Host ""

$confirmation = Read-Host "Continue? (y/n)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    exit
}

# Create Azure AD Application
Write-Host ""
Write-Host "Creating Azure AD Application..." -ForegroundColor Green
$APP_ID = (az ad app create --display-name "$APP_NAME" --query appId -o tsv)
Write-Host "Application created with ID: $APP_ID" -ForegroundColor Green

# Create Service Principal
Write-Host ""
Write-Host "Creating Service Principal..." -ForegroundColor Green
az ad sp create --id "$APP_ID" --query id -o tsv | Out-Null

Start-Sleep -Seconds 5  # Wait for service principal to propagate

# Construct the subject claim based on workspace pattern
if ($TFC_WORKSPACE -like "project:*") {
    # Project-level wildcard
    $SUBJECT = "organization:${TFC_ORG}:${TFC_WORKSPACE}:run_phase:*"
} else {
    # Specific workspace
    $SUBJECT = "organization:${TFC_ORG}:workspace:${TFC_WORKSPACE}:run_phase:*"
}

# Create Federated Identity Credential
Write-Host ""
Write-Host "Creating Federated Identity Credential..." -ForegroundColor Green

$federatedCredParams = @{
    name = "terraform-cloud-federated-credential"
    issuer = "https://app.terraform.io"
    subject = $SUBJECT
    audiences = @($TFC_AUDIENCE)
    description = "Federated credential for Terraform Cloud workload identity"
} | ConvertTo-Json -Compress

az ad app federated-credential create --id "$APP_ID" --parameters $federatedCredParams

# Assign Contributor role to the subscription
Write-Host ""
Write-Host "Assigning Contributor role to subscription..." -ForegroundColor Green
az role assignment create `
    --assignee "$APP_ID" `
    --role "Contributor" `
    --scope "/subscriptions/$SUBSCRIPTION_ID" | Out-Null

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Add these variables to your Terraform Cloud workspace:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Environment Variables:" -ForegroundColor Green
Write-Host "  TFC_AZURE_PROVIDER_AUTH = true"
Write-Host "  TFC_AZURE_RUN_CLIENT_ID = $APP_ID"
Write-Host "  ARM_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
Write-Host "  ARM_TENANT_ID = $TENANT_ID"
Write-Host ""
Write-Host "These should be marked as 'Environment Variables' (not Terraform variables)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Your Terraform provider configuration should include:" -ForegroundColor Green
Write-Host "  provider `"azurerm`" {"
Write-Host "    features {}"
Write-Host "    use_oidc = true"
Write-Host "  }"
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
