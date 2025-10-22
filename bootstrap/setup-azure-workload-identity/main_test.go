package main

import (
	"testing"
)

func TestConstructSubjectClaim(t *testing.T) {
	tests := []struct {
		name         string
		organization string
		project      string
		workspace    string
		runPhase     string
		expected     string
	}{
		{
			name:         "specific workspace no project - plan",
			organization: "acme",
			project:      "",
			workspace:    "prod",
			runPhase:     "plan",
			expected:     "organization:acme:workspace:prod:run_phase:plan",
		},
		{
			name:         "specific workspace no project - apply",
			organization: "acme",
			project:      "",
			workspace:    "prod",
			runPhase:     "apply",
			expected:     "organization:acme:workspace:prod:run_phase:apply",
		},
		{
			name:         "all workspaces no project - plan",
			organization: "acme",
			project:      "",
			workspace:    "*",
			runPhase:     "plan",
			expected:     "organization:acme:workspace:*:run_phase:plan",
		},
		{
			name:         "specific workspace with project - plan",
			organization: "acme",
			project:      "infrastructure",
			workspace:    "prod",
			runPhase:     "plan",
			expected:     "organization:acme:project:infrastructure:workspace:prod:run_phase:plan",
		},
		{
			name:         "specific workspace with project - apply",
			organization: "acme",
			project:      "infrastructure",
			workspace:    "prod",
			runPhase:     "apply",
			expected:     "organization:acme:project:infrastructure:workspace:prod:run_phase:apply",
		},
		{
			name:         "all workspaces with project - plan",
			organization: "acme",
			project:      "Default Project",
			workspace:    "*",
			runPhase:     "plan",
			expected:     "organization:acme:project:Default Project:workspace:*:run_phase:plan",
		},
		{
			name:         "project with empty workspace (should default to all) - apply",
			organization: "acme",
			project:      "Default Project",
			workspace:    "",
			runPhase:     "apply",
			expected:     "organization:acme:project:Default Project:workspace:*:run_phase:apply",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := constructSubjectClaim(tt.organization, tt.project, tt.workspace, tt.runPhase)
			if result != tt.expected {
				t.Errorf("constructSubjectClaim() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestValidateConfig(t *testing.T) {
	tests := []struct {
		name    string
		config  Config
		wantErr bool
	}{
		{
			name: "valid minimal config",
			config: Config{
				TerraformCloud: TerraformCloudConfig{
					Organization: "acme",
					Workspace:    "prod",
				},
			},
			wantErr: false,
		},
		{
			name: "missing organization",
			config: Config{
				TerraformCloud: TerraformCloudConfig{
					Workspace: "prod",
				},
			},
			wantErr: true,
		},
		{
			name: "empty config gets defaults",
			config: Config{
				TerraformCloud: TerraformCloudConfig{
					Organization: "acme",
				},
			},
			wantErr: false,
		},
		{
			name: "with project",
			config: Config{
				TerraformCloud: TerraformCloudConfig{
					Organization: "acme",
					Project:      "Default Project",
					Workspace:    "prod",
				},
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateConfig(&tt.config)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateConfig() error = %v, wantErr %v", err, tt.wantErr)
			}

			// Check defaults are set when no error
			if !tt.wantErr {
				if tt.config.Application.Audience == "" {
					t.Error("Audience should have default value")
				}
				if tt.config.TerraformCloud.Workspace == "" {
					t.Error("Workspace should default to '*'")
				}
			}
		})
	}
}
