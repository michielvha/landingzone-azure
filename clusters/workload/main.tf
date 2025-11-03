# Workload/Target Cluster Example
# This cluster is managed by ArgoCD running in the management cluster

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
  project     = "workload"
  contact     = "platform-team@example.com"
  repo_name   = "platform"
  repo_path   = "terraform/development/workload"
}

# Workload AKS Cluster managed by ArgoCD
module "aks_workload" {
  source = "app.terraform.io/mikevh/aks/azurerm"

  # Basic Configuration
  project_name    = "workload"
  environment     = "development"
  cluster_version = "1.33.3"

  # Target Cluster Configuration (managed by ArgoCD)
  is_mgmt_cluster  = false # This cluster is managed by ArgoCD

  # ArgoCD Workload Identity Configuration
  # This is the principal ID of the ArgoCD server's managed identity from the mgmt cluster
  argocd_server_wi = {
    enabled      = true
    principal_id = "REPLACE_WITH_ARGOCD_PRINCIPAL_ID" # Get this from mgmt cluster federated credentials output
  }

  # Declarative Onboarding
  # Set to false for automatic cluster secret creation in the mgmt cluster
  declarative_onboarding = false

  # Resource Group (from module)
  resource_group = module.resource_group.resource_group

  # Networking Configuration - aligned with mgmt cluster
  networking = {
    subnet_name          = "lz-production-kubernetes-subnet"
    resource_group_name  = "landingzone-prd-we-rg"
    virtual_network_name = "lz-production-vnet"
    network_plugin       = "azure"
    service_cidr         = "192.168.1.0/24"  # Different from mgmt (192.168.0.0/24)
    dns_service_ip       = "192.168.1.10"
  }

  # Default Node Pool
  default_node_pool = {
    node_count   = 2
    max_pods     = 50
    os_disk_size = 30
    vm_size      = "Standard_D2s_v3"
    os_disk_type = "Ephemeral"
    name         = "system"
  }

  # Auto-scaling for default node pool
  auto_scaler = {
    min_count = 2
    max_count = 3
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

  # Private Cluster Configuration
  # Set to true for production environments where API server should not be publicly accessible
  # Set to false for development/testing where public access is acceptable
  enable_private_cluster   = false # Public cluster for easier management/development
  enable_private_dns_zone  = false # Only relevant when enable_private_cluster = true
  
  # Optional: Restrict API server access to specific IP ranges (recommended for public clusters)
  # api_server_authorized_ip_ranges = ["YOUR_IP/32"]

  # Tags
  custom_tags = {
    managed-by  = "argocd"
    application = "workload"
  }
}

# Outputs
output "workload_cluster_name" {
  value = module.aks_workload.cluster_name
}

output "workload_cluster_id" {
  value = module.aks_workload.id
}

output "workload_oidc_issuer_url" {
  value = module.aks_workload.oidc_issuer_url
}

output "workload_api_server_url" {
  value = module.aks_workload.aks_cluster_api_server_url
}
