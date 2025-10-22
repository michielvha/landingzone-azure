locals {
  app_name = var.app_name != null ? var.app_name : "terraform-cloud-${var.tfc_organization}"

  # Define run phases - Azure does NOT support wildcards in run_phase
  run_phases = ["plan", "apply"]

  # Generate subject claims for each workspace and run phase combination
  # This creates a map like: { "workspace-plan" => "org:...:run_phase:plan", "workspace-apply" => "org:...:run_phase:apply" }
  workspace_credentials = merge([
    for workspace in var.tfc_workspaces : {
      for phase in local.run_phases :
      "${workspace}-${phase}" => {
        workspace = workspace
        run_phase = phase
        subject = var.tfc_project_name != null ? (
          "organization:${var.tfc_organization}:project:${var.tfc_project_name}:workspace:${workspace}:run_phase:${phase}"
          ) : (
          "organization:${var.tfc_organization}:workspace:${workspace}:run_phase:${phase}"
        )
        display_name = length(var.tfc_workspaces) > 1 ? (
          "terraform-cloud-federated-credential-${phase}-${index(var.tfc_workspaces, workspace)}"
          ) : (
          "terraform-cloud-federated-credential-${phase}"
        )
      }
    }
  ]...)
}
