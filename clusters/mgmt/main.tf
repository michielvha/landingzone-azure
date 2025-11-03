# Management Cluster Example
# This cluster hosts ArgoCD and manages other target clusters

# Data sources for existing resources
data "azurerm_log_analytics_workspace" "law" {
  name                = "logs"
  resource_group_name = "prd-we"
}

# SSH key for cluster access
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Resource Group
module "resource_group" {
  source = "app.terraform.io/mikevh/terraform-azurerm-resource-group/azurerm"

  location    = "westeurope"
  environment = "development"
  project     = "mgmt"
  contact     = "platform-team@example.com"
  repo_name   = "platform"
  repo_path   = "terraform/development/mgmt"
}

# Management AKS Cluster with ArgoCD
module "aks_mgmt" {
  source = "app.terraform.io/mikevh/aks/azurerm"

  # Basic Configuration
  project_name    = "mgmt"
  environment     = "development"
  cluster_version = "1.33.3"

  # ArgoCD Management Cluster Configuration
  is_mgmt_cluster  = true # This cluster hosts ArgoCD

  # Resource Group (from module)
  resource_group = module.resource_group.resource_group

  # Networking Configuration
  networking = {
    subnet_name          = "lz-production-kubernetes-subnet"
    resource_group_name  = "landingzone-prd-we-rg"
    virtual_network_name = "lz-production-vnet"
    network_plugin       = "azure"
    service_cidr         = "192.168.0.0/24"
    dns_service_ip       = "192.168.0.10"
  }

  # Default Node Pool
  default_node_pool = {
    node_count   = 2
    max_pods     = 50
    os_disk_size = 128
    vm_size      = "Standard_D4as_v5"
    os_disk_type = "Ephemeral"
    name         = "system"
  }

  # Auto-scaling for default node pool
  auto_scaler = {
    min_count = 2
    max_count = 5
  }

  # Linux Profile for SSH access
  linux_profile = {
    admin_username = "azureuser"
    ssh_key        = tls_private_key.key.public_key_openssh
  }

  # Monitoring
  log_analytics_workspace_resource_id = data.azurerm_log_analytics_workspace.law.id

  # Use default load balancer for outbound traffic (no user-defined routing)
  use_route_table = false

  # Admin groups for cluster access (empty for now, add Azure AD group object IDs as needed)
  admin_group_object_ids = []

  # Tags
  custom_tags = {
    purpose = "argocd-management"
  }
}

module "federated_credentials" {
  for_each = { for cred in local.federated_credentials : cred.purpose => cred }
  source   = "app.terraform.io/mikevh/federated-credentials/azurerm"
  version  = ">=0.0.1,<1.0.0"

  base_resource_name = module.aks_mgmt.cluster_name
  oidc_issuer_url    = module.aks_mgmt.oidc_issuer_url
  purpose            = each.value.purpose
  resource_group     = module.resource_group.resource_group
  service_accounts   = each.value.service_accounts
}

locals {
  federated_credentials = [
    {
      purpose = "argocd-prd"
      service_accounts = [
        {
          name      = "argocd-server"
          namespace = "argocd"
        },
        {
          name      = "argocd-application-controller"
          namespace = "argocd"
        }
      ]
    }
  ]
}

# Outputs
output "mgmt_cluster_name" {
  value = module.aks_mgmt.cluster_name
}

output "mgmt_cluster_id" {
  value = module.aks_mgmt.id
}

output "mgmt_oidc_issuer_url" {
  value = module.aks_mgmt.oidc_issuer_url
}
