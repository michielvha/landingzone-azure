#!/bin/bash
set -e

echo "======================================================"
echo "Azure Workload Identity Federation Setup"
echo "for Terraform Cloud"
echo "======================================================"
echo ""

# Prompt for required information
read -p "Enter your Terraform Cloud Organization name: " TFC_ORG
read -p "Enter your Terraform Cloud Workspace name (or 'project:*' for all workspaces in a project): " TFC_WORKSPACE
read -p "Enter your Azure Subscription ID (leave empty to use current): " SUBSCRIPTION_ID
read -p "Enter a name for the Azure AD Application (default: terraform-cloud-${TFC_ORG}): " APP_NAME

# Set defaults
APP_NAME=${APP_NAME:-"terraform-cloud-${TFC_ORG}"}
TFC_AUDIENCE=${TFC_AUDIENCE:-"api://AzureADTokenExchange"}

# Get current subscription if not provided
if [ -z "$SUBSCRIPTION_ID" ]; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
  echo "Using current subscription: $SUBSCRIPTION_ID"
fi

TENANT_ID=$(az account show --query tenantId -o tsv)

echo ""
echo "Configuration:"
echo "  Organization: $TFC_ORG"
echo "  Workspace: $TFC_WORKSPACE"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Tenant: $TENANT_ID"
echo "  App Name: $APP_NAME"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

# Create Azure AD Application
echo ""
echo "Creating Azure AD Application..."
APP_ID=$(az ad app create \
  --display-name "$APP_NAME" \
  --query appId -o tsv)

echo "Application created with ID: $APP_ID"

# Create Service Principal
echo ""
echo "Creating Service Principal..."
az ad sp create --id "$APP_ID" --query id -o tsv

sleep 5  # Wait for service principal to propagate

# Construct the subject claim based on workspace pattern
if [[ $TFC_WORKSPACE == project:* ]]; then
  # Project-level wildcard
  SUBJECT="organization:${TFC_ORG}:${TFC_WORKSPACE}:run_phase:*"
else
  # Specific workspace
  SUBJECT="organization:${TFC_ORG}:workspace:${TFC_WORKSPACE}:run_phase:*"
fi

# Create Federated Identity Credential
echo ""
echo "Creating Federated Identity Credential..."
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"terraform-cloud-federated-credential\",
    \"issuer\": \"https://app.terraform.io\",
    \"subject\": \"${SUBJECT}\",
    \"audiences\": [\"${TFC_AUDIENCE}\"],
    \"description\": \"Federated credential for Terraform Cloud workload identity\"
  }"

# Assign Contributor role to the subscription
echo ""
echo "Assigning Contributor role to subscription..."
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

echo ""
echo "======================================================"
echo "Setup Complete!"
echo "======================================================"
echo ""
echo "Add these variables to your Terraform Cloud workspace:"
echo ""
echo "Environment Variables:"
echo "  TFC_AZURE_PROVIDER_AUTH = true"
echo "  TFC_AZURE_RUN_CLIENT_ID = $APP_ID"
echo "  ARM_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "  ARM_TENANT_ID = $TENANT_ID"
echo ""
echo "These should be marked as 'Environment Variables' (not Terraform variables)"
echo ""
echo "Your Terraform provider configuration should include:"
echo "  provider \"azurerm\" {"
echo "    features {}"
echo "    use_oidc = true"
echo "  }"
echo ""
echo "======================================================"
