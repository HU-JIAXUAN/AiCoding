package ckit

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func portableOverlayPath() string {
	return filepath.Join("..", "..", "examples", "portable-c99.overlay.json")
}

func portableLintConfig(t *testing.T) Config {
	t.Helper()
	cfg, _, err := LoadConfigWithOverlays(configPath(), []string{portableOverlayPath()})
	if err != nil {
		t.Fatal(err)
	}
	cfg.Docs.FileHeader = false
	cfg.Docs.AllFunctions = false
	cfg.Macro.RequireDocumentation = false
	return cfg
}

func TestPortableNamingAppliesToRecognizableDeclarations(t *testing.T) {
	cfg := portableLintConfig(t)
	source := `#define MOD_COUNT 2
typedef struct {
    uint32_t sampleCount;
} Motor;
typedef void (*Notify)(uint32_t sampleCount);
typedef uint32_t Counter;
typedef enum {
    MOD_STOPPED = 0,
    MOD_RUNNING
} MotorState;
static uint32_t g_cycleCount;
uint32_t g_totalCount;

static void clear_count(uint32_t sampleCount)
{
    Motor currentMotor;
    uint32_t nextCount = sampleCount;
    g_cycleCount = nextCount;
}

void mod_update(uint32_t sampleCount)
{
    clear_count(sampleCount);
}
`
	if diagnostics := lintContent("portable.c", []byte(source), nil, cfg, false); len(diagnostics) != 0 {
		t.Fatalf("portable profile rejected its naming convention: %+v", diagnostics)
	}
	tests := []struct{ old, replacement, rule string }{
		{"mod_update", "DEMO_Update", "naming.public-function"},
		{"clear_count", "ClearCount", "naming.private-function"},
		{"sampleCount", "sample_count", "naming.parameter"},
		{"nextCount", "next_count", "naming.local-variable"},
		{"currentMotor", "current_motor", "naming.local-variable"},
		{"Motor;", "motor_t;", "naming.type"},
		{"Counter;", "counter_t;", "naming.type"},
		{"Notify", "notify_fn", "naming.function-pointer"},
		{"g_cycleCount", "s_cycle_count", "naming.static-variable"},
		{"g_totalCount", "g_total_count", "naming.global-variable"},
		{"MOD_COUNT", "mod_count", "macro.name"},
		{"MOD_STOPPED", "ModStopped", "naming.enum-constant"},
	}
	for _, test := range tests {
		t.Run(test.rule+"/"+test.old, func(t *testing.T) {
			changed := strings.ReplaceAll(source, test.old, test.replacement)
			if diagnostics := lintContent("portable.c", []byte(changed), nil, cfg, false); !hasRule(diagnostics, test.rule) {
				t.Fatalf("configuration did not enforce %s: %+v", test.rule, diagnostics)
			}
		})
	}
	fieldSource := strings.Replace(source, "uint32_t sampleCount;", "uint32_t sample_count;", 1)
	if diagnostics := lintContent("portable.c", []byte(fieldSource), nil, cfg, false); !hasRule(diagnostics, "naming.struct-member") {
		t.Fatalf("struct member pattern was not enforced: %+v", diagnostics)
	}
}

func complexitySource(name string) string {
	var source strings.Builder
	fmt.Fprintf(&source, "void %s(uint32_t first, uint32_t second, uint32_t third, uint32_t fourth, uint32_t fifth, uint32_t sixth)\n{\n", name)
	source.WriteString("    uint32_t value = first;\n\n    /* 逐次推进计数，用于覆盖复杂度阈值 */\n")
	for count := 0; count < 52; count++ {
		source.WriteString("    value = value + 1;\n")
	}
	for count := 0; count < 5; count++ {
		source.WriteString("    if (value != 0) {\n")
	}
	source.WriteString("    value = second;\n")
	for count := 0; count < 5; count++ {
		source.WriteString("    }\n")
	}
	source.WriteString("}\n")
	return source.String()
}

func TestPortableComplexityIsReviewWhileLegacyRemainsBlocking(t *testing.T) {
	cfg := portableLintConfig(t)
	diagnostics := lintContent("complexity.c", []byte(complexitySource("mod_update")), nil, cfg, false)
	for _, rule := range []string{"complexity.parameters", "complexity.function-lines", "complexity.nesting"} {
		found := false
		for _, diagnostic := range diagnostics {
			if diagnostic.Rule == rule {
				found = diagnostic.Severity == "warning"
			}
		}
		if !found {
			t.Fatalf("expected review-level %s: %+v", rule, diagnostics)
		}
	}
	if hasBlockingDiagnostics(diagnostics) {
		t.Fatalf("review-only complexity blocked portable code: %+v", diagnostics)
	}
	legacy := focusedLintConfig(t)
	legacy.Readability.KeyFlowComments.RequiredForComplexFunctions = false
	legacyDiagnostics := lintContent("complexity.c", []byte(complexitySource("DEMO_Update")), nil, legacy, false)
	if !hasBlockingDiagnostics(legacyDiagnostics) || !hasRule(legacyDiagnostics, "complexity.parameters") {
		t.Fatalf("legacy profile lost its blocking thresholds: %+v", legacyDiagnostics)
	}
	if lost := limitDiagnostics(append(diagnostics, diag("complexity.c", 1, "safety", "must block")), 1); !hasBlockingDiagnostics(lost) {
		t.Fatalf("diagnostic limit hid an error behind warnings: %+v", lost)
	}
}

func TestPortableLintCLIEmitsSuccessfulWarnings(t *testing.T) {
	cfg := portableLintConfig(t)
	root := t.TempDir()
	configFile := filepath.Join(root, "c-kit.json")
	data, err := json.Marshal(cfg)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configFile, data, 0o600); err != nil {
		t.Fatal(err)
	}
	sourceFile := filepath.Join(root, "complexity.c")
	if err := os.WriteFile(sourceFile, []byte(complexitySource("mod_update")), 0o600); err != nil {
		t.Fatal(err)
	}
	reader, writer, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	original := os.Stdout
	os.Stdout = writer
	runErr := RunLint([]string{"--config", configFile, "--overlay", portableOverlayPath(), "--scope", "files", "--file", sourceFile, "--json"})
	_ = writer.Close()
	os.Stdout = original
	output, readErr := io.ReadAll(reader)
	_ = reader.Close()
	if readErr != nil || runErr != nil {
		t.Fatalf("warning-only lint failed: %v %v\n%s", runErr, readErr, output)
	}
	var result struct {
		OK          bool         `json:"ok"`
		Diagnostics []Diagnostic `json:"diagnostics"`
	}
	if err := json.Unmarshal(output, &result); err != nil || !result.OK || len(result.Diagnostics) == 0 {
		t.Fatalf("warnings were not represented in JSON: %+v, %v", result, err)
	}
}

func TestNamingAndComplexityConfigRejectUnknownPolicies(t *testing.T) {
	for _, content := range []string{
		`{"naming":{"publicFunction":"${arbitraryRegex}"}}`,
		`{"naming":{"type":"[A-Z].*"}}`,
		`{"naming":{"type":"${PascalCase}.*"}}`,
		`{"readability":{"complexitySeverity":"ignore"}}`,
	} {
		p := filepath.Join(t.TempDir(), "invalid.overlay.json")
		if err := os.WriteFile(p, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, _, err := LoadConfigWithOverlays(configPath(), []string{p}); err == nil {
			t.Fatalf("unsupported policy was silently accepted: %s", content)
		}
	}
}

func TestParameterNamesHandleArraysCallbacksAndUnnamedTypes(t *testing.T) {
	names := parseParameterNames("const Motor *motor, uint8_t values[CAPACITY], void (*notify)(uint32_t), uint32_t")
	if strings.Join(names, ",") != "motor,values,notify" {
		t.Fatalf("parameter names were confused with type/extent tokens: %v", names)
	}
}

func TestLintOverlayDoesNotApplyVerificationCompilerFlagRestrictions(t *testing.T) {
	path := filepath.Join(t.TempDir(), "compiler.overlay.json")
	if err := os.WriteFile(path, []byte(`{"gates":{"gcc":{"flags":["-O2"]}}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, _, err := loadLintConfigWithOverlays(configPath(), []string{path}); err != nil {
		t.Fatalf("read-only lint rejected unrelated compiler metadata: %v", err)
	}
	if _, _, err := LoadConfigWithOverlays(configPath(), []string{path}); err == nil {
		t.Fatal("external verification accepted an unsafe compiler gate override")
	}
}

func TestExternalVerificationDoesNotBlockComplexityWarnings(t *testing.T) {
	cfg := portableLintConfig(t)
	root := t.TempDir()
	config := filepath.Join(root, "c-kit.json")
	configData, _ := json.Marshal(cfg)
	if err := os.WriteFile(config, configData, 0o600); err != nil {
		t.Fatal(err)
	}
	for name, source := range map[string]string{"module.c": complexitySource("mod_update"), "module.h": "#ifndef MODULE_H\n#define MODULE_H\n#endif\n", "test.c": "int main(void) { return 0; }\n"} {
		if err := os.WriteFile(filepath.Join(root, name), []byte(source), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	target := filepath.Join(root, "target.json")
	manifest := `{"schema":"ckit-verify-target-v1","id":"portable-complexity","candidate":{"source":"module.c","header":"module.h"},"host":{"testSource":"test.c"}}`
	if err := os.WriteFile(target, []byte(manifest), 0o600); err != nil {
		t.Fatal(err)
	}
	result, err := executeVerification(context.Background(), verifyOptions{ConfigPath: config, TargetPath: target, Profile: "fast"}, &fakeVerifyRunner{})
	if err != nil || !result.OK || len(result.Diagnostics) == 0 {
		t.Fatalf("complexity review incorrectly blocked compiler/harness verification: %+v %v", result, err)
	}
}
