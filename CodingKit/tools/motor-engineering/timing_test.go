package main

import (
	"bytes"
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func pointer(v float64) *float64 { return &v }
func example(t testing.TB) TimingInput {
	t.Helper()
	data, err := os.ReadFile("example.json")
	if err != nil {
		t.Fatal(err)
	}
	var in TimingInput
	if err = json.Unmarshal(data, &in); err != nil {
		t.Fatal(err)
	}
	return in
}
func has(r TimingReport, code string) bool {
	for _, d := range r.Diagnostics {
		if d.Code == code {
			return true
		}
	}
	return false
}
func closeTo(t testing.TB, got, want float64) {
	t.Helper()
	if math.Abs(got-want) > 1e-7 {
		t.Fatalf("got %.12g, want %.12g", got, want)
	}
}

func TestHalfCycleBudget(t *testing.T) {
	r := analyze(example(t))
	if r.Status != "DERIVED" {
		t.Fatalf("%+v", r)
	}
	closeTo(t, r.PWMHz, 100000)
	closeTo(t, r.CurrentUpdateHz, 100000)
	closeTo(t, r.ADCSequenceNS, 330)
	b := r.Budgets[0]
	closeTo(t, b.DeadlineNS, 5000)
	closeTo(t, b.AvailableNS, 4285)
	closeTo(t, *b.ComputationMarginNS, 785)
	if r.WCETStatus != "NOT_MEASURED" || r.BandwidthStatus != "UNKNOWN" {
		t.Fatal("fabricated measurement or bandwidth")
	}
	closeTo(t, r.Encoder["apply_prediction_rad"], -0.01)
}
func TestTimingFaults(t *testing.T) {
	for _, tc := range []struct {
		name, code string
		change     func(*TimingInput)
	}{
		{"overrun", "DEADLINE_MISSED", func(i *TimingInput) { i.Schedule.FOCBoundNS = pointer(4500) }},
		{"adc_isr_before_latch", "ADC_READ_BEFORE_LATCH", func(i *TimingInput) { i.Schedule.ISREntryNS = pointer(0); i.Schedule.FixedDelayNS = pointer(0) }},
		{"epwm_stale_read", "STALE_ADC_RESULT", func(i *TimingInput) { i.Schedule.ISRSource = "epwm"; i.Schedule.ISRPhaseNS = pointer(5000) }},
		{"short_hold", "ACQUISITION_TOO_SHORT", func(i *TimingInput) { i.ADC.AcquisitionSYSCLKCycles = 5 }},
		{"bad_window", "INVALID_SAMPLE_WINDOW", func(i *TimingInput) { i.PWM.SampleWindowNS = pointer(50) }},
		{"lost_encoder", "STALE_ENCODER", func(i *TimingInput) { i.Encoder.MaxAgeNS = 2000 }},
		{"double_compensation", "DUPLICATE_DELAY_COMPENSATION", func(i *TimingInput) { i.Encoder.CompensationOwners = append(i.Encoder.CompensationOwners, "svpwm") }},
		{"wrong_time", "ENCODER_TIME_ORDER", func(i *TimingInput) { i.Encoder.LatchNS = 2000 }},
		{"missing_jitter", "MISSING_BOUND", func(i *TimingInput) { i.Schedule.JitterBoundNS = nil }},
		{"missing_latency", "ADC_READY_EVIDENCE", func(i *TimingInput) { i.ADC.InterruptLeadSYSCLKCycles = nil }},
		{"prescale_phase", "SOC_PRESCALE_PHASE", func(i *TimingInput) { i.PWM.SOCEvery = 2 }},
		{"invalid_clock", "RANGE", func(i *TimingInput) { i.Clock.EPWMDiv = 0 }},
		{"invalid_schema", "SCHEMA_VERSION", func(i *TimingInput) { i.SchemaVersion = 0 }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			in := example(t)
			tc.change(&in)
			r := analyze(in)
			if !has(r, tc.code) {
				t.Fatalf("missing %s: %+v", tc.code, r)
			}
			if tc.name == "missing_jitter" && len(r.Budgets) != 0 {
				t.Fatal("unknown jitter silently became zero")
			}
		})
	}
}
func TestSamplePolicies(t *testing.T) {
	for _, tc := range []struct {
		policy, soc, load string
		updates           int
		deadline          float64
	}{
		{"valley", "zero", "zero", 1, 10000},
		{"peak", "period", "zero", 1, 5000},
		{"double_single", "zero_or_period", "zero", 1, 5000},
		{"double_double", "zero_or_period", "zero_or_period", 2, 5000},
	} {
		t.Run(tc.policy, func(t *testing.T) {
			in := example(t)
			in.PWM.SamplePolicy = tc.policy
			in.PWM.SOCEvent = tc.soc
			in.PWM.ShadowEvent = tc.load
			if tc.policy == "double_double" {
				in.Encoder.UpdateIndex = 1
			}
			r := analyze(in)
			if r.Status != "DERIVED" {
				t.Fatalf("%+v", r)
			}
			if len(r.Budgets) != tc.updates {
				t.Fatal(r.Budgets)
			}
			closeTo(t, r.CurrentUpdateHz, float64(tc.updates)*100000)
			for _, b := range r.Budgets {
				closeTo(t, b.DeadlineNS, tc.deadline)
			}
		})
	}
}
func TestSingleSlopeCounts(t *testing.T) {
	for _, mode := range []string{"up", "down"} {
		in := example(t)
		in.PWM.Mode = mode
		in.PWM.PeriodCounts = 999
		in.PWM.SOCEvent = "zero"
		in.PWM.SamplePolicy = "valley"
		r := analyze(in)
		closeTo(t, r.CarrierPeriodNS, 10000)
	}
}
func TestObservedMaxDoesNotCertifyWCET(t *testing.T) {
	in := example(t)
	in.Observations = &ObservationInput{"synthetic GPIO pulse samples", []float64{2000, 3700}}
	r := analyze(in)
	if r.WCETStatus != "OBSERVED_MAX_ONLY" || !has(r, "OBSERVED_BOUND_EXCEEDED") {
		t.Fatalf("%+v", r)
	}
}
func TestUnknownExecution(t *testing.T) {
	in := example(t)
	in.Schedule.FOCBoundNS = nil
	r := analyze(in)
	if r.Status != "INSUFFICIENT_EVIDENCE" || r.Budgets[0].ComputationMarginNS != nil || r.WCETStatus != "NOT_MEASURED" {
		t.Fatalf("%+v", r)
	}
}
func TestDeterministicJSON(t *testing.T) {
	in := example(t)
	in.Schedule.FOCBoundNS = nil
	in.Schedule.GuardNS = nil
	var expected []byte
	for n := 0; n < 40; n++ {
		got, err := json.Marshal(analyze(in))
		if err != nil {
			t.Fatal(err)
		}
		if n == 0 {
			expected = got
		} else if !bytes.Equal(got, expected) {
			t.Fatal("output depends on map iteration")
		}
	}
}
func TestCLI(t *testing.T) {
	var out bytes.Buffer
	if code := run([]string{"analyze", "--input", "example.json"}, &out); code != 0 {
		t.Fatalf("%d %s", code, &out)
	}
	for _, data := range []string{`{"schema_version":1,"typo":4}`, `{} {}`, `{"schema_version":1,"clock":{"sysclk_hz":1e999}}`} {
		file := filepath.Join(t.TempDir(), "bad.json")
		if err := os.WriteFile(file, []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
		out.Reset()
		if code := run([]string{"analyze", "--input", file}, &out); code != 4 {
			t.Fatalf("code %d, %s", code, &out)
		}
	}
}
func BenchmarkAnalyze(b *testing.B) {
	in := example(b)
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		_ = analyze(in)
	}
}

func TestEncoderBoundToUpdate(t *testing.T) {
	in := example(t)
	in.Encoder.ParkNS = 5400
	in.Encoder.ApplyNS = 9000
	in.Encoder.MaxAgeNS = 9500
	r := analyze(in)
	if !has(r, "ENCODER_EVENT_MISMATCH") {
		t.Fatal(r)
	}
	in = example(t)
	in.Encoder.UpdateIndex = 5
	r = analyze(in)
	if !has(r, "ENCODER_UPDATE_INDEX") {
		t.Fatal(r)
	}
}

func TestRCAcquisitionErrorCriterion(t *testing.T) {
	// Independent Decimal(65-digit precision) ln reference, R*C=100ns.
	for _, tc := range []struct {
		bits            int
		lsb, step, want float64
	}{{12, .5, 1, 901.0913347279289022424}, {12, 1, 1, 831.7766166719343713007}, {12, .5, .25, 762.461898615939840359}, {16, 1, 1, 1109.035488895912495068}} {
		r := TimingReport{Status: "DERIVED"}
		analyzeAcquisition(&AcquisitionRC{10000, 1e-11, tc.bits, tc.lsb, tc.step, true}, pointer(75), 2000, 200000000, &r)
		if r.Status != "DERIVED" {
			t.Fatal(r)
		}
		closeTo(t, r.Acquisition.RCMinimumNS, tc.want)
	}
	in := example(t)
	in.ADC.AcquisitionRC = &AcquisitionRC{10000, 1e-11, 12, .5, 1, true}
	r := analyze(in)
	if !has(r, "ACQUISITION_RC_TOO_SHORT") {
		t.Fatal(r)
	}
	in.ADC.AcquisitionRC.ModelConfirmed = false
	r = analyze(in)
	if !has(r, "RC_MODEL_EVIDENCE") || r.Acquisition.Status != "INSUFFICIENT_EVIDENCE" {
		t.Fatal(r)
	}
	in.ADC.AcquisitionRC.ResistanceOhm = 0
	r = analyze(in)
	if !has(r, "RC_MODEL_RANGE") {
		t.Fatal(r)
	}
}
func TestDuplicateJSONAndNullArrays(t *testing.T) {
	if err := rejectDuplicateKeys([]byte(`{"a":1,"a":2}`)); err == nil {
		t.Fatal("duplicate key accepted")
	}
	in := example(t)
	data, _ := json.Marshal(in)
	var object map[string]any
	_ = json.Unmarshal(data, &object)
	object["sources"] = nil
	if err := requiredFields(object, reflect.TypeOf(in), "input"); err == nil {
		t.Fatal("null array accepted")
	}
}

func TestArbitrationMovesAcquisition(t *testing.T) {
	in := example(t)
	in.ADC.ArbitrationDelayNS = pointer(1000)
	r := analyze(in)
	for _, e := range r.Events {
		if e.Name == "adc_acquisition_start" {
			closeTo(t, e.TimeNS, 6010)
			return
		}
	}
	t.Fatal("missing acquisition event")
}
