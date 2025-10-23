variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "tfc_workspaces" {
  description = "List of Terraform Cloud workspace names to create credentials for"
  type        = list(string)
  default     = ["*"]
}

variable "tfc_project_name" {
  description = "Terraform Cloud project name (optional, for project-level credentials)"
  type        = string
  default     = null
}

variable "app_name" {
  description = "Name for the Azure AD application"
  type        = string
  default     = null
}

variable "role_assignments" {
  description = "List of role assignments for the service principal"
  type = list(object({
    role  = string
    scope = optional(string)
  }))
  default = [
    {
      role  = "Contributor"
      scope = null # Will use subscription scope
    }
  ]
}