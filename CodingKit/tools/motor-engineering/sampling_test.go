package main

import "testing"

func threeShunts() *SamplingInput {
	return &SamplingInput{Topology: "three_low_side", HardwareTrigger: true, DeadtimeNS: 100, BlankingNS: 50, AmplifierSettlingNS: 150, GuardNS: 50, MeasuredPhases: []int{0, 1, 2}, PhaseWindowsNS: []float64{600, 600, 300}, PhaseSampleOffsetsNS: []float64{300, 300, 300}, ActiveVectorWindowsNS: []float64{}, SwitchStates: []int{}, MaxSampleSkewNS: 0, AllowedSampleSkewNS: 20}
}
func TestShuntObservability(t *testing.T) {
	in := example(t)
	in.CurrentSampling = threeShunts()
	r := analyze(in)
	if r.Status != "DERIVED" || len(r.Sampling.ValidPhases) != 2 {
		t.Fatalf("%+v", r)
	}
	closeTo(t, r.Sampling.RequiredWindowNS, 450)
	for _, tc := range []struct {
		code   string
		change func(*SamplingInput)
	}{
		{"PHASE_CURRENT_UNOBSERVABLE", func(s *SamplingInput) { s.Topology = "two_low_side"; s.MeasuredPhases = []int{0, 2} }},
		{"NON_SIMULTANEOUS_CURRENTS", func(s *SamplingInput) { s.MaxSampleSkewNS = 30 }},
		{"SOFTWARE_TRIGGER_JITTER", func(s *SamplingInput) { s.HardwareTrigger = false }},
		{"SHUNT_CHANNELS", func(s *SamplingInput) { s.MeasuredPhases = []int{0, 0, 2} }},
		{"PHASE_CURRENT_UNOBSERVABLE", func(s *SamplingInput) { s.PhaseSampleOffsetsNS = []float64{0, 0, 0} }},
	} {
		s := threeShunts()
		tc.change(s)
		in.CurrentSampling = s
		if r = analyze(in); !has(r, tc.code) {
			t.Fatalf("missing %s: %+v", tc.code, r)
		}
	}
}
func TestSingleShuntRankAndWindows(t *testing.T) {
	for _, tc := range []struct {
		states  []int
		windows []float64
		code    string
	}{{[]int{1, 3}, []float64{500, 500}, ""}, {[]int{1, 6}, []float64{500, 500}, "CURRENT_RECONSTRUCTION_RANK"}, {[]int{0, 3}, []float64{500, 500}, "ZERO_VECTOR_CURRENT"}, {[]int{1, 3}, []float64{500, 100}, "SINGLE_SHUNT_WINDOW"}} {
		in := example(t)
		s := threeShunts()
		s.Topology = "single_dc_link"
		s.SwitchStates = tc.states
		s.ActiveVectorWindowsNS = tc.windows
		s.ActiveVectorSampleOffsetsNS = []float64{300, 300}
		s.PhaseWindowsNS = []float64{}
		s.MeasuredPhases = []int{}
		in.CurrentSampling = s
		r := analyze(in)
		if tc.code == "" && r.Status != "DERIVED" || tc.code != "" && !has(r, tc.code) {
			t.Fatalf("%+v", r)
		}
	}
}
