package mcpcontrol

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"
)

func TestRunPythonStepHonorsCanceledContext(t *testing.T) {
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	result := runPythonStep(ctx, t.TempDir(), executable, []string{"-test.run=TestDoesNotRun"})
	if result.OK || len(result.Errors) == 0 {
		t.Fatalf("canceled command unexpectedly passed: %#v", result)
	}
	if !strings.Contains(strings.ToLower(strings.Join(result.Errors, " ")), "canceled") {
		t.Fatalf("canceled command did not report context cancellation: %#v", result)
	}
}

func TestDoctorComponentInputsRunConcurrentlyAndPreserveOrder(t *testing.T) {
	inputs := []componentInput{
		{resolved: true, component: Component{ID: "first", Runtime: PythonRuntime{Root: "first"}, Doctor: CommandSpec{Args: []string{"first"}}}},
		{resolved: true, component: Component{ID: "second", Runtime: PythonRuntime{Root: "second"}, Doctor: CommandSpec{Args: []string{"second"}}}},
		{resolved: true, component: Component{ID: "third", Runtime: PythonRuntime{Root: "third"}, Doctor: CommandSpec{Args: []string{"third"}}}},
	}
	arrived := make(chan string, len(inputs))
	release := make(chan struct{})
	repo := t.TempDir()
	released := false
	defer func() {
		if !released {
			close(release)
		}
	}()

	done := make(chan []CommandResult, 1)
	go func() {
		done <- doctorComponentInputsWithStep(
			context.Background(),
			repo,
			inputs,
			func(_ context.Context, _, _ string, args []string) CommandResult {
				arrived <- args[0]
				<-release
				return CommandResult{OK: true, RawOutput: args[0]}
			},
		)
	}()

	seen := map[string]bool{}
	for range inputs {
		select {
		case id := <-arrived:
			seen[id] = true
		case <-time.After(2 * time.Second):
			t.Fatal("component doctors did not all start before the first completed")
		}
	}
	close(release)
	released = true

	var results []CommandResult
	select {
	case results = <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("component doctors did not finish after release")
	}
	if len(seen) != len(inputs) {
		t.Fatalf("started component doctors = %v", seen)
	}
	for index, expected := range []string{"first", "second", "third"} {
		if !results[index].OK || results[index].RawOutput != expected {
			t.Fatalf("result %d = %#v, want ordered output %q", index, results[index], expected)
		}
	}
}
