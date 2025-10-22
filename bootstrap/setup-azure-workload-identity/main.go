package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const (
	version = "1.0.0"
)

// Config represents the configuration for setting up workload identity
type Config struct {
	TerraformCloud TerraformCloudConfig `yaml:"terraform_cloud" json:"terraform_cloud"`
	Azure          AzureConfig          `yaml:"azure" json:"azure"`
	Application    ApplicationConfig    `yaml:"application" json:"application"`
}

type TerraformCloudConfig struct {
	Organization string   `yaml:"organization" json:"organization"`
	Workspace    string   `yaml:"workspace" json:"workspace"`
	Workspaces   []string `yaml:"workspaces,omitempty" json:"workspaces,omitempty"` // Multiple workspaces
	Project      string   `yaml:"project,omitempty" json:"project,omitempty"`
}

type AzureConfig struct {
	SubscriptionID string   `yaml:"subscription_id,omitempty" json:"subscription_id,omitempty"`
	TenantID       string   `yaml:"tenant_id,omitempty" json:"tenant_id,omitempty"`
	Role           string   `yaml:"role" json:"role"`
	Scope          string   `yaml:"scope,omitempty" json:"scope,omitempty"`
	Roles          []RoleAssignment `yaml:"roles,omitempty" json:"roles,omitempty"`
}

type RoleAssignment struct {
	Name  string `yaml:"name" json:"name"`
	Scope string `yaml:"scope,omitempty" json:"scope,omitempty"`
}

type ApplicationConfig struct {
	Name     string `yaml:"name,omitempty" json:"name,omitempty"`
	Audience string `yaml:"audience" json:"audience"`
}

// AzureResources holds the created Azure resources
type AzureResources struct {
	ApplicationID  string `json:"application_id"`
	SubscriptionID string `json:"subscription_id"`
	TenantID       string `json:"tenant_id"`
	Subject        string `json:"subject"`
}

func main() {
	configPath := flag.String("config", "config.yaml", "Path to configuration file")
	interactive := flag.Bool("interactive", false, "Run in interactive mode")
	outputFormat := flag.String("output", "text", "Output format: text, json, env")
	showVersion := flag.Bool("version", false, "Show version")
	flag.Parse()

	if *showVersion {
		fmt.Printf("Azure Workload Identity Setup v%s\n", version)
		os.Exit(0)
	}

	var config Config
	var err error

	if *interactive {
		config, err = interactiveSetup()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error in interactive setup: %v\n", err)
			os.Exit(1)
		}
	} else {
		config, err = loadConfig(*configPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error loading config: %v\n", err)
			os.Exit(1)
		}
	}

	if err := validateConfig(&config); err != nil {
		fmt.Fprintf(os.Stderr, "Invalid configuration: %v\n", err)
		os.Exit(1)
	}

	// Setup Azure resources
	resources, err := setupAzureWorkloadIdentity(config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error setting up Azure workload identity: %v\n", err)
		os.Exit(1)
	}

	// Output results
	outputResults(resources, *outputFormat)
}

func loadConfig(path string) (Config, error) {
	var config Config

	data, err := os.ReadFile(path)
	if err != nil {
		return config, fmt.Errorf("failed to read config file: %w", err)
	}

	// Try YAML first, then JSON
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		err = json.Unmarshal(data, &config)
		if err != nil {
			return config, fmt.Errorf("failed to parse config (tried YAML and JSON): %w", err)
		}
	}

	return config, nil
}

func interactiveSetup() (Config, error) {
	config := Config{}
	scanner := bufio.NewScanner(os.Stdin)

	fmt.Println("====================================================")
	fmt.Println("Azure Workload Identity Federation Setup")
	fmt.Println("for Terraform Cloud")
	fmt.Println("====================================================")
	fmt.Println()

	// Terraform Cloud configuration
	fmt.Print("Enter your Terraform Cloud Organization name: ")
	scanner.Scan()
	config.TerraformCloud.Organization = strings.TrimSpace(scanner.Text())

	fmt.Print("Enter your Terraform Cloud Workspace name (default: * for all): ")
	scanner.Scan()
	config.TerraformCloud.Workspace = strings.TrimSpace(scanner.Text())
	if config.TerraformCloud.Workspace == "" {
		config.TerraformCloud.Workspace = "*"
	}

	// Azure configuration
	fmt.Print("Enter Azure Subscription ID (leave empty for current): ")
	scanner.Scan()
	config.Azure.SubscriptionID = strings.TrimSpace(scanner.Text())

	fmt.Print("Enter Application name (leave empty for default): ")
	scanner.Scan()
	config.Application.Name = strings.TrimSpace(scanner.Text())
	if config.Application.Name == "" {
		config.Application.Name = fmt.Sprintf("terraform-cloud-%s", config.TerraformCloud.Organization)
	}

	// Set defaults
	config.Application.Audience = "api://AzureADTokenExchange"
	config.Azure.Role = "Contributor"

	return config, nil
}

func validateConfig(config *Config) error {
	if config.TerraformCloud.Organization == "" {
		return fmt.Errorf("terraform_cloud.organization is required")
	}

	if config.TerraformCloud.Workspace == "" {
		config.TerraformCloud.Workspace = "*"
	}

	if config.Application.Audience == "" {
		config.Application.Audience = "api://AzureADTokenExchange"
	}

	if config.Application.Name == "" {
		config.Application.Name = fmt.Sprintf("terraform-cloud-%s", config.TerraformCloud.Organization)
	}

	if config.Azure.Role == "" && len(config.Azure.Roles) == 0 {
		config.Azure.Role = "Contributor"
	}

	return nil
}

func setupAzureWorkloadIdentity(config Config) (*AzureResources, error) {
	ctx := context.Background()
	resources := &AzureResources{}

	fmt.Println("\n🔍 Checking Azure CLI...")
	if err := checkAzureCLI(ctx); err != nil {
		return nil, err
	}

	fmt.Println("✅ Azure CLI found")

	// Get current Azure context
	if config.Azure.SubscriptionID == "" {
		fmt.Println("\n📋 Getting current subscription...")
		subID, err := runAzCommand(ctx, "account", "show", "--query", "id", "-o", "tsv")
		if err != nil {
			return nil, fmt.Errorf("failed to get subscription: %w", err)
		}
		config.Azure.SubscriptionID = strings.TrimSpace(subID)
		fmt.Printf("✅ Using subscription: %s\n", config.Azure.SubscriptionID)
	}
	resources.SubscriptionID = config.Azure.SubscriptionID

	if config.Azure.TenantID == "" {
		tenantID, err := runAzCommand(ctx, "account", "show", "--query", "tenantId", "-o", "tsv")
		if err != nil {
			return nil, fmt.Errorf("failed to get tenant: %w", err)
		}
		config.Azure.TenantID = strings.TrimSpace(tenantID)
	}
	resources.TenantID = config.Azure.TenantID

	// Display configuration
	fmt.Println("\n📝 Configuration:")
	fmt.Printf("  Organization: %s\n", config.TerraformCloud.Organization)
	if config.TerraformCloud.Project != "" {
		fmt.Printf("  Project:      %s\n", config.TerraformCloud.Project)
	}
	fmt.Printf("  Workspace:    %s\n", config.TerraformCloud.Workspace)
	fmt.Printf("  Subscription: %s\n", config.Azure.SubscriptionID)
	fmt.Printf("  Tenant:       %s\n", config.Azure.TenantID)
	fmt.Printf("  App Name:     %s\n", config.Application.Name)
	fmt.Println()

	// Create or get existing Azure AD Application
	fmt.Println("🔨 Checking for existing Azure AD Application...")
	appID, err := runAzCommand(ctx, "ad", "app", "list",
		"--display-name", config.Application.Name,
		"--query", "[0].appId", "-o", "tsv")
	
	appID = strings.TrimSpace(appID)
	
	if appID == "" || err != nil {
		// App doesn't exist, create it
		fmt.Println("📝 Creating new Azure AD Application...")
		appID, err = runAzCommand(ctx, "ad", "app", "create",
			"--display-name", config.Application.Name,
			"--query", "appId", "-o", "tsv")
		if err != nil {
			return nil, fmt.Errorf("failed to create application: %w", err)
		}
		appID = strings.TrimSpace(appID)
		fmt.Printf("✅ Application created: %s\n", appID)
	} else {
		fmt.Printf("✅ Found existing application: %s\n", appID)
	}
	resources.ApplicationID = appID

	// Create or verify Service Principal exists
	fmt.Println("\n🔨 Checking for existing Service Principal...")
	spID, err := runAzCommand(ctx, "ad", "sp", "list",
		"--filter", fmt.Sprintf("appId eq '%s'", resources.ApplicationID),
		"--query", "[0].id", "-o", "tsv")
	
	spID = strings.TrimSpace(spID)
	
	if spID == "" || err != nil {
		// SP doesn't exist, create it
		fmt.Println("📝 Creating Service Principal...")
		_, err = runAzCommand(ctx, "ad", "sp", "create", "--id", resources.ApplicationID)
		if err != nil {
			return nil, fmt.Errorf("failed to create service principal: %w", err)
		}
		fmt.Println("✅ Service Principal created")
	} else {
		fmt.Println("✅ Service Principal already exists")
	}

	// Wait for propagation
	fmt.Println("\n⏳ Waiting for propagation (5 seconds)...")
	time.Sleep(5 * time.Second)

	// Construct subject claim(s)
	workspaces := config.TerraformCloud.Workspaces
	if len(workspaces) == 0 && config.TerraformCloud.Workspace != "" {
		workspaces = []string{config.TerraformCloud.Workspace}
	}
	if len(workspaces) == 0 {
		workspaces = []string{"*"} // Default to all workspaces
	}

	fmt.Printf("\n📋 Creating credentials for %d workspace(s)...\n", len(workspaces))
	fmt.Println("   Creating 2 credentials per workspace (plan + apply)")

	// First, clean up any old credentials from previous runs
	fmt.Println("\n🧹 Cleaning up old credentials...")
	existingCreds, err := runAzCommand(ctx, "ad", "app", "federated-credential", "list",
		"--id", resources.ApplicationID,
		"--query", "[].name", "-o", "tsv")
	if err == nil && strings.TrimSpace(existingCreds) != "" {
		for _, credName := range strings.Split(strings.TrimSpace(existingCreds), "\n") {
			if strings.HasPrefix(credName, "terraform-cloud-federated-credential") {
				fmt.Printf("   Deleting: %s\n", credName)
				_, _ = runAzCommand(ctx, "ad", "app", "federated-credential", "delete",
					"--id", resources.ApplicationID,
					"--federated-credential-id", credName)
			}
		}
	}

	// Create federated credential for each workspace
	for i, workspace := range workspaces {
		fmt.Printf("\n🔨 Workspace: %s\n", workspace)

		// Create credentials for both plan and apply run phases
		runPhases := []string{"plan", "apply"}
		for _, runPhase := range runPhases {
			subject := constructSubjectClaim(config.TerraformCloud.Organization, config.TerraformCloud.Project, workspace, runPhase)
			credName := fmt.Sprintf("terraform-cloud-federated-credential-%s-%d", runPhase, i)
			if len(workspaces) == 1 {
				credName = fmt.Sprintf("terraform-cloud-federated-credential-%s", runPhase)
			}

			fmt.Printf("   Subject (%s): %s\n", runPhase, subject)

			// Create the federated credential
			fmt.Printf("   📝 Creating %s credential...\n", runPhase)
			federatedCred := map[string]interface{}{
				"name":        credName,
				"issuer":      "https://app.terraform.io",
				"subject":     subject,
				"audiences":   []string{config.Application.Audience},
				"description": fmt.Sprintf("Federated credential for TFC workspace: %s (%s)", workspace, runPhase),
			}
			credJSON, _ := json.Marshal(federatedCred)

			// Write to temp file to avoid shell escaping issues
			tmpFile, err := os.CreateTemp("", "federated-cred-*.json")
			if err != nil {
				return nil, fmt.Errorf("failed to create temp file: %w", err)
			}
			tmpPath := tmpFile.Name()
			defer os.Remove(tmpPath)

			if _, err := tmpFile.Write(credJSON); err != nil {
				tmpFile.Close()
				return nil, fmt.Errorf("failed to write temp file: %w", err)
			}
			tmpFile.Close()

			_, err = runAzCommand(ctx, "ad", "app", "federated-credential", "create",
				"--id", resources.ApplicationID,
				"--parameters", "@"+tmpPath)
			if err != nil {
				return nil, fmt.Errorf("failed to create federated credential for %s (%s): %w", workspace, runPhase, err)
			}
			fmt.Printf("   ✅ %s credential created\n", runPhase)

			// Store the first subject for output
			if i == 0 && runPhase == "plan" {
				resources.Subject = subject
			}
		}
	}

	// Assign roles
	fmt.Println("\n🔨 Assigning roles...")
	roles := config.Azure.Roles
	if len(roles) == 0 && config.Azure.Role != "" {
		roles = []RoleAssignment{{Name: config.Azure.Role, Scope: config.Azure.Scope}}
	}

	for _, role := range roles {
		scope := role.Scope
		if scope == "" {
			scope = fmt.Sprintf("/subscriptions/%s", config.Azure.SubscriptionID)
		}

		// Check if role assignment already exists
		existingRole, err := runAzCommand(ctx, "role", "assignment", "list",
			"--assignee", resources.ApplicationID,
			"--role", role.Name,
			"--scope", scope,
			"--query", "[0].id", "-o", "tsv")
		
		existingRole = strings.TrimSpace(existingRole)
		
		if existingRole != "" {
			fmt.Printf("✅ Role already assigned: %s (scope: %s)\n", role.Name, scope)
			continue
		}

		// Role doesn't exist, create it
		_, err = runAzCommand(ctx, "role", "assignment", "create",
			"--assignee", resources.ApplicationID,
			"--role", role.Name,
			"--scope", scope)
		if err != nil {
			// Role assignment creation can fail if it already exists (race condition)
			// Just warn instead of failing
			fmt.Printf("⚠️  Warning: Could not assign role %s: %v\n", role.Name, err)
			continue
		}
		fmt.Printf("✅ Assigned role: %s (scope: %s)\n", role.Name, scope)
	}

	return resources, nil
}

func constructSubjectClaim(organization, project, workspace, runPhase string) string {
	// If project is specified, use project-based format
	if project != "" {
		if workspace == "" || workspace == "*" {
			return fmt.Sprintf("organization:%s:project:%s:workspace:*:run_phase:%s",
				organization, project, runPhase)
		}
		return fmt.Sprintf("organization:%s:project:%s:workspace:%s:run_phase:%s",
			organization, project, workspace, runPhase)
	}

	// No project - organization level
	if workspace == "" || workspace == "*" {
		return fmt.Sprintf("organization:%s:workspace:*:run_phase:%s", organization, runPhase)
	}

	return fmt.Sprintf("organization:%s:workspace:%s:run_phase:%s",
		organization, workspace, runPhase)
}

func checkAzureCLI(ctx context.Context) error {
	cmd := exec.CommandContext(ctx, "az", "--version")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("Azure CLI not found. Please install from https://aka.ms/azure-cli")
	}
	return nil
}

func runAzCommand(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "az", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("command failed: %w\nOutput: %s", err, string(output))
	}
	return string(output), nil
}

func outputResults(resources *AzureResources, format string) {
	fmt.Println("\n======================================================")
	fmt.Println("✅ Setup Complete!")
	fmt.Println("======================================================")

	switch format {
	case "json":
		output, _ := json.MarshalIndent(resources, "", "  ")
		fmt.Println(string(output))

	case "env":
		fmt.Println("\n# Environment Variables for Terraform Cloud")
		fmt.Println("TFC_AZURE_PROVIDER_AUTH=true")
		fmt.Printf("TFC_AZURE_RUN_CLIENT_ID=%s\n", resources.ApplicationID)
		fmt.Printf("ARM_SUBSCRIPTION_ID=%s\n", resources.SubscriptionID)
		fmt.Printf("ARM_TENANT_ID=%s\n", resources.TenantID)

	default: // text
		fmt.Println("\nAdd these variables to your Terraform Cloud workspace:")
		fmt.Println("\nEnvironment Variables:")
		fmt.Println("  TFC_AZURE_PROVIDER_AUTH = true")
		fmt.Printf("  TFC_AZURE_RUN_CLIENT_ID = %s\n", resources.ApplicationID)
		fmt.Printf("  ARM_SUBSCRIPTION_ID     = %s\n", resources.SubscriptionID)
		fmt.Printf("  ARM_TENANT_ID           = %s\n", resources.TenantID)
		fmt.Println("\nThese should be marked as 'Environment Variables' (not Terraform variables)")
		fmt.Println("\nYour Terraform provider configuration should include:")
		fmt.Println("  provider \"azurerm\" {")
		fmt.Println("    features {}")
		fmt.Println("    use_oidc = true")
		fmt.Println("  }")
	}

	fmt.Println("\n======================================================")
}
