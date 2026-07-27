package mcpcontrol

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/JiaxI2/AiCoding/internal/runner"
)

func DoctorComponents(repo string, entries []RegistryEntry) []CommandResult {
	return DoctorComponentsContext(context.Background(), repo, entries)
}

func DoctorComponentsContext(ctx context.Context, repo string, entries []RegistryEntry) []CommandResult {
	inputs := make([]componentInput, 0, len(entries))
	for _, entry := range entries {
		inputs = append(inputs, componentInput{entry: entry})
	}
	return doctorComponentInputs(ctx, repo, inputs)
}

func DoctorCatalogComponentsContext(ctx context.Context, repo string, snapshots []ComponentSnapshot) []CommandResult {
	return doctorComponentInputs(ctx, repo, componentInputs(snapshots))
}

func doctorComponentInputs(ctx context.Context, repo string, inputs []componentInput) []CommandResult {
	return doctorComponentInputsWithStep(ctx, repo, inputs, runPythonStep)
}

func doctorComponentInputsWithStep(
	ctx context.Context,
	repo string,
	inputs []componentInput,
	runStep func(context.Context, string, string, []string) CommandResult,
) []CommandResult {
	tasks := make([]runner.Task, len(inputs))
	for index, input := range inputs {
		index := index
		input := input
		tasks[index] = runner.Task{
			ID:     fmt.Sprintf("mcp.doctor.%d", index),
			Action: "mcp.doctor",
			Run: func(taskContext context.Context) runner.TaskResult {
				component, err := resolvedComponent(repo, input)
				if err != nil {
					result := CommandResult{OK: false, Errors: []string{err.Error()}}
					return runner.TaskResult{OK: false, Errors: append([]string{}, result.Errors...), Data: result}
				}
				root := componentRoot(repo, component)
				result := runStep(taskContext, root, venvPython(root), component.Doctor.Args)
				return runner.TaskResult{OK: result.OK, Errors: append([]string{}, result.Errors...), Data: result}
			},
		}
	}

	taskResults := runner.Run(ctx, tasks, runner.Options{MaxParallel: 4})
	results := make([]CommandResult, len(taskResults))
	for index, taskResult := range taskResults {
		if result, ok := taskResult.Data.(CommandResult); ok {
			results[index] = result
			continue
		}
		errorsFound := append([]string{}, taskResult.Errors...)
		if len(errorsFound) == 0 {
			errorsFound = append(errorsFound, taskResult.Warnings...)
		}
		if len(errorsFound) == 0 {
			errorsFound = []string{"MCP doctor task returned no command result"}
		}
		results[index] = CommandResult{OK: false, Errors: errorsFound}
	}
	return results
}

func Verify(
	ctx context.Context,
	repo string,
	codexPath string,
	entries []RegistryEntry,
	profile string,
	includeConfigured bool,
) VerifyReport {
	inputs := make([]componentInput, 0, len(entries))
	for _, entry := range entries {
		inputs = append(inputs, componentInput{entry: entry})
	}
	return verifyComponentInputs(ctx, repo, codexPath, inputs, profile, includeConfigured)
}

func VerifyCatalog(
	ctx context.Context,
	repo string,
	codexPath string,
	snapshots []ComponentSnapshot,
	profile string,
	includeConfigured bool,
) VerifyReport {
	return verifyComponentInputs(ctx, repo, codexPath, componentInputs(snapshots), profile, includeConfigured)
}

func verifyComponentInputs(
	ctx context.Context,
	repo string,
	codexPath string,
	inputs []componentInput,
	profile string,
	includeConfigured bool,
) VerifyReport {
	normalized := normalizeProfile(profile)
	report := VerifyReport{
		Profile:    normalized,
		OK:         true,
		Managed:    []ComponentVerifyResult{},
		Configured: []ProbeResult{},
	}
	for _, input := range inputs {
		entry := input.entry
		component, err := resolvedComponent(repo, input)
		if err != nil {
			item := ComponentVerifyResult{ID: entry.ID, Profile: normalized, OK: false, Errors: []string{err.Error()}}
			report.Managed = append(report.Managed, item)
			report.Errors = append(report.Errors, entry.ID+": "+err.Error())
			report.OK = false
			continue
		}
		item := verifyComponent(ctx, repo, component, normalized)
		report.Managed = append(report.Managed, item)
		if !item.OK {
			report.OK = false
			for _, issue := range item.Errors {
				report.Errors = append(report.Errors, component.ID+": "+issue)
			}
		}
	}
	if includeConfigured {
		configPath, err := ResolveCodexConfig(codexPath)
		if err != nil {
			report.OK = false
			report.Errors = append(report.Errors, err.Error())
			return report
		}
		endpoints, err := LoadConfigured(configPath)
		if err != nil {
			report.OK = false
			report.Errors = append(report.Errors, err.Error())
			return report
		}
		report.Configured = ProbeAll(ctx, endpoints, 4)
		for _, probe := range report.Configured {
			if !probe.OK {
				report.OK = false
				for _, issue := range probe.Errors {
					report.Errors = append(report.Errors, probe.ID+": "+issue)
				}
			}
		}
		if len(endpoints) == 0 {
			report.Warnings = append(report.Warnings, "no configured Codex MCP servers were found")
		}
	}
	return report
}

func verifyComponent(ctx context.Context, repo string, component Component, profile string) ComponentVerifyResult {
	result := ComponentVerifyResult{
		ID:      component.ID,
		Profile: profile,
		OK:      true,
		Steps:   []CommandResult{},
	}
	steps := component.Verify[profile]
	if len(steps) == 0 {
		result.OK = false
		result.Errors = []string{"verify profile is not defined: " + profile}
		return result
	}
	root := componentRoot(repo, component)
	python := venvPython(root)
	for _, step := range steps {
		commandResult := runPythonStep(ctx, root, python, step)
		result.Steps = append(result.Steps, commandResult)
		if !commandResult.OK {
			result.OK = false
			result.Errors = append(result.Errors, commandResult.Errors...)
			break
		}
	}
	return result
}

func runPythonStep(ctx context.Context, root, python string, args []string) CommandResult {
	started := time.Now()
	result := CommandResult{
		Command: append([]string{python}, args...),
		OK:      false,
	}
	if python == "" {
		result.Errors = []string{"venv Python path is empty"}
		result.ElapsedMS = time.Since(started).Milliseconds()
		return result
	}
	output, err := runNativeContext(ctx, root, python, args...)
	result.ElapsedMS = time.Since(started).Milliseconds()
	if err != nil {
		result.Errors = []string{err.Error()}
		result.RawOutput = output
		return result
	}
	result.OK = true
	if json.Valid([]byte(output)) {
		result.Output = json.RawMessage(output)
	} else {
		result.RawOutput = output
	}
	return result
}

func normalizeProfile(profile string) string {
	switch strings.ToLower(strings.TrimSpace(profile)) {
	case "smoke", "":
		return "Smoke"
	case "full":
		return "Full"
	case "release":
		return "Release"
	default:
		return profile
	}
}

func VerifyErrors(report VerifyReport) error {
	if report.OK {
		return nil
	}
	return fmt.Errorf("MCP verification failed with %d errors", len(report.Errors))
}
