package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

const fixtureC = `
#define PERIOD (1000U / 2U)
#define BAD (5/0)
// Interrupt_register(INT_BAD, fake_handler);
void update(void) { EPWM_setCounterCompareValue(EPWM1_BASE, EPWM_COUNTER_COMPARE_A, 123U); }
__interrupt void control_isr(void) { sample(); update(); ADC_clearInterruptStatus(ADCA_BASE, ADC_INT_NUMBER1); }
void setup(void) {
 EPWM_setTimeBasePeriod(EPWM1_BASE, PERIOD);
 EPWM_setClockPrescaler(EPWM1_BASE, EPWM_CLOCK_DIVIDER_1, EPWM_HSCLOCK_DIVIDER_2);
 EPWM_setTimeBaseCounterMode(EPWM1_BASE, EPWM_COUNTER_MODE_UP_DOWN);
 EPWM_setADCTriggerSource(EPWM1_BASE, EPWM_SOC_A, EPWM_SOC_TBCTR_PERIOD);
 EPWM_setCounterCompareShadowLoadMode(EPWM1_BASE, EPWM_COUNTER_COMPARE_A, EPWM_COMP_LOAD_ON_CNTR_ZERO);
 ADC_setupSOC(ADCA_BASE, ADC_SOC_NUMBER0, ADC_TRIGGER_EPWM1_SOCA, ADC_CH_ADCIN0, 20U);
 ADC_setInterruptSource(ADCA_BASE, ADC_INT_NUMBER1, ADC_SOC_NUMBER0);
 Interrupt_register(INT_ADCA1, &control_isr);
 const char *text = "ADC_setupSOC(FAKE)";
}
`

func fixture(t testing.TB) (string, []string) {
	t.Helper()
	root := t.TempDir()
	for name, body := range map[string]string{"control.c": fixtureC, ".ccsproject": `<projectOptions><deviceVariant value="TMS320C28XX.TMS320F28388D"/><codegenToolVersion value="22.6.1.LTS"/></projectOptions>`} {
		if err := os.WriteFile(filepath.Join(root, name), []byte(body), 0600); err != nil {
			t.Fatal(err)
		}
	}
	return root, []string{"control.c", ".ccsproject"}
}
func TestSourceGraph(t *testing.T) {
	root, files := fixture(t)
	r, err := inspect(root, files)
	if err != nil {
		t.Fatal(err)
	}
	if r.Status != "CONFIRMED_SOURCE_ONLY" || r.WCETStatus != "NOT_MEASURED" {
		t.Fatal(r.Status)
	}
	if len(r.TargetCandidates) != 1 || len(r.ISRPaths) != 1 {
		t.Fatalf("%+v", r)
	}
	if got := r.ISRPaths[0].Symbols; !contains(got, "control_isr") || !contains(got, "update") || !contains(got, "EPWM_setCounterCompareValue") {
		t.Fatal(got)
	}
	if contains(r.ISRPaths[0].Symbols, "fake_handler") {
		t.Fatal("comment parsed as call")
	}
	if len(r.PWMCandidates) != 1 || r.PWMCandidates[0].PeriodCounts == nil || *r.PWMCandidates[0].PeriodCounts != 500 {
		t.Fatal(r.PWMCandidates)
	}
	if len(r.EventLinks) < 5 {
		t.Fatal(r.EventLinks)
	}
	for _, f := range r.Facts {
		if f.Location.Line < 1 || f.Location.Path == "" {
			t.Fatal(f)
		}
		if strings.Contains(f.Symbol, "FAKE") {
			t.Fatal("string parsed as call")
		}
	}
}
func contains(a []string, s string) bool {
	for _, v := range a {
		if v == s {
			return true
		}
	}
	return false
}
func TestInspectDeterministicAndNoWrites(t *testing.T) {
	root, files := fixture(t)
	first, err := inspect(root, files)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(first)
	for n := 0; n < 15; n++ {
		r, err := inspect(root, []string{"control.c", ".ccsproject", "control.c"})
		if err != nil {
			t.Fatal(err)
		}
		got, _ := json.Marshal(r)
		if string(got) != string(b) {
			t.Fatal("nondeterministic report")
		}
	}
	entries, err := os.ReadDir(root)
	if err != nil || len(entries) != 2 {
		t.Fatal("inspection wrote project artifacts")
	}
}
func TestScopeBoundary(t *testing.T) {
	root, _ := fixture(t)
	for _, files := range [][]string{{"../escape.c"}, {filepath.Join(root, "control.c")}} {
		if _, err := inspect(root, files); err == nil {
			t.Fatal("accepted path escape", files)
		}
	}
	if _, err := inspect(root, make([]string, 129)); err == nil {
		t.Fatal("accepted unbounded input")
	}
}
func TestExpressionSemantics(t *testing.T) {
	constants := map[string][]string{"A": {"(200000000UL / 2U)"}, "MULTI": {"1", "2"}, "SELF": {"SELF"}}
	for _, tc := range []struct {
		expr string
		want float64
		ok   bool
	}{{"A/(2*500U)", 100000, true}, {"5/2", 2, true}, {"5.0/2", 2.5, true}, {"2U<<3", 16, true}, {"MULTI", 0, false}, {"SELF", 0, false}, {"BAD + 1", 0, false}, {"1/0", 0, false}, {"call()", 0, false}} {
		v, ok := evaluate(tc.expr, constants, map[string]bool{}, 0)
		if ok != tc.ok || ok && v.value != tc.want {
			t.Fatalf("%s got %+v,%v", tc.expr, v, ok)
		}
	}
}
func TestDoesNotInferMCUFromComments(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "F28388D_reference.c"), []byte("/* reference F28388D */ void example(void){}"), 0600); err != nil {
		t.Fatal(err)
	}
	r, err := inspect(root, []string{"F28388D_reference.c"})
	if err != nil {
		t.Fatal(err)
	}
	if len(r.TargetCandidates) != 0 {
		t.Fatal("inferred device from reference")
	}
}
func TestAmbiguousWritesStayUnknown(t *testing.T) {
	root, files := fixture(t)
	path := filepath.Join(root, "control.c")
	if err := os.WriteFile(path, []byte(fixtureC+"\nvoid change(void){EPWM_setTimeBasePeriod(EPWM1_BASE, 42U);}"), 0600); err != nil {
		t.Fatal(err)
	}
	r, err := inspect(root, files)
	if err != nil {
		t.Fatal(err)
	}
	if r.PWMCandidates[0].PeriodCounts != nil || r.PWMCandidates[0].Mode != "AMBIGUOUS_WRITES" {
		t.Fatal("guessed final configuration")
	}
}
func TestSchemaUsesActualTypes(t *testing.T) {
	schema := schemaFor(reflect.TypeOf(TimingInput{}))
	props := schema["properties"].(map[string]any)
	if len(props) != reflect.TypeOf(TimingInput{}).NumField() {
		t.Fatal("schema drift")
	}
	in := example(t)
	data, _ := json.Marshal(in)
	var object map[string]any
	_ = json.Unmarshal(data, &object)
	if err := requiredFields(object, reflect.TypeOf(in), "input"); err != nil {
		t.Fatal(err)
	}
	delete(object["adc"].(map[string]any), "trigger_sysclk_cycles")
	if err := requiredFields(object, reflect.TypeOf(in), "input"); err == nil {
		t.Fatal("missing zero-valued timing silently assumed")
	}
}

func TestHexSuffixAndEnumExactness(t *testing.T) {
	if enumDiv("EPWM_CLOCK_DIVIDER_6", "EPWM_CLOCK_DIVIDER_") != nil || enumDiv("EPWM_HSCLOCK_DIVIDER_16", "EPWM_HSCLOCK_DIVIDER_") != nil {
		t.Fatal("unsupported clock-divider enum accepted")
	}
	for _, s := range []string{"0x1FF", "0x1FFU", "0x1FFUL"} {
		v, ok := evaluate(s, nil, map[string]bool{}, 0)
		if !ok || v.value != 511 {
			t.Fatalf("%s -> %+v %v", s, v, ok)
		}
	}
	if enumDiv("EPWM_CLOCK_DIVIDER_2 + 1", "EPWM_CLOCK_DIVIDER_") != nil {
		t.Fatal("enum prefix accepted trailing expression")
	}
}
func TestDeclarationsAndContinuedComments(t *testing.T) {
	root := t.TempDir()
	body := "// disabled \\\nEPWM_setTimeBasePeriod(EPWM1_BASE, 2);\nvoid handler(void){void declared_only(void); real();}\nvoid init(void){Interrupt_register(INT_ADCA1,&handler);}"
	if err := os.WriteFile(filepath.Join(root, "source.c"), []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	r, err := inspect(root, []string{"source.c"})
	if err != nil {
		t.Fatal(err)
	}
	if len(r.PWMCandidates) != 0 || contains(r.ISRPaths[0].Symbols, "declared_only") || !contains(r.ISRPaths[0].Symbols, "real") {
		t.Fatal(r)
	}
}

func TestLiteralCallbackRegistration(t *testing.T) {
	root := t.TempDir()
	body := `void run_motor(void){PI_update();} void set_handler(Handler handler){g_handler=handler;} void adc_isr(void){g_handler();} void init(void){set_handler(run_motor);Interrupt_register(INT_ADCA1,&adc_isr);}`
	if err := os.WriteFile(filepath.Join(root, "source.c"), []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	r, err := inspect(root, []string{"source.c"})
	if err != nil {
		t.Fatal(err)
	}
	if len(r.ISRPaths) != 1 || !contains(r.ISRPaths[0].Symbols, "run_motor") || !contains(r.ISRPaths[0].Symbols, "PI_update") {
		t.Fatal(r.ISRPaths)
	}
	if !contains(r.ISRPaths[0].Unresolved, "g_handler") {
		t.Fatal("callback candidate silently became a proven runtime binding")
	}
}

func TestSysConfigInstanceIsNotHardwareNumber(t *testing.T) {
	root := t.TempDir()
	body := `clb1.clbBase="CLB2_BASE";clb2.clbBase="CLB1_BASE";clb2.globalConfigCLB_IN4="CLB_GLOBAL_IN_MUX_EPWM1_CTR_ZERO";system.clockTree["EPWMCLKDIV"].divideValue=2;`
	if err := os.WriteFile(filepath.Join(root, "c2000.syscfg"), []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	r, err := inspect(root, []string{"c2000.syscfg"})
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, link := range r.EventLinks {
		if link.From == "EPWM1_BASE.TBCTR.ZERO" && link.To == "CLB1_BASE.IN4" && len(link.Sources) == 2 {
			found = true
		}
	}
	if !found {
		t.Fatal(r.EventLinks)
	}
	if len(r.Facts) != 4 {
		t.Fatal(r.Facts)
	}
}

func TestSOCBLink(t *testing.T) {
	root, _ := fixture(t)
	body := strings.ReplaceAll(fixtureC, "EPWM_SOC_A", "EPWM_SOC_B")
	body = strings.ReplaceAll(body, "EPWM1_SOCA", "EPWM1_SOCB")
	if err := os.WriteFile(filepath.Join(root, "control.c"), []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	r, err := inspect(root, []string{"control.c"})
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, e := range r.EventLinks {
		if e.From == "EPWM1_BASE.TBCTR" && e.To == "EPWM1_SOCB" {
			found = true
		}
	}
	if !found {
		t.Fatal(r.EventLinks)
	}
}
func BenchmarkInspect(b *testing.B) {
	root, files := fixture(b)
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		if _, err := inspect(root, files); err != nil {
			b.Fatal(err)
		}
	}
}
