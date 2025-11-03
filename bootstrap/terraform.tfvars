# Terraform Cloud Configuration
tfc_organization = "mikevh"

# List of workspaces to create credentials for
# Each workspace will get 2 credentials (one for plan, one for apply)
tfc_workspaces = ["landingzone-azure", "mgmt", "workload"]

# Optional: Use project-level credentials
tfc_project_name = "Default Project" # ⚠️ IMPORTANT! Include this if workspace is in a project!

# Azure AD Application Name (optional)
# app_name = "terraform-cloud-mikevh"

# Role Assignments - Need both Contributor and User Access Administrator
# Contributor: Create/modify resources
# User Access Administrator: Create role assignments (required for AKS UMI permissions)
role_assignments = [
  {
    role  = "Contributor"
    scope = null  # Uses subscription scope
  },
  {
    role  = "User Access Administrator"
    scope = null  # Uses subscription scope
  }
]
