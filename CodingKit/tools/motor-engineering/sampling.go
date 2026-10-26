package main

import "fmt"

// Windows are actual contiguous candidate windows, not summed split vectors.
type SamplingInput struct {
	Topology                    string    `json:"topology"`
	HardwareTrigger             bool      `json:"hardware_trigger"`
	DeadtimeNS                  float64   `json:"deadtime_ns"`
	DriverDelayNS               float64   `json:"driver_delay_ns"`
	RiseTimeNS                  float64   `json:"rise_time_ns"`
	BlankingNS                  float64   `json:"blanking_ns"`
	AmplifierSettlingNS         float64   `json:"amplifier_settling_ns"`
	GuardNS                     float64   `json:"guard_ns"`
	MeasuredPhases              []int     `json:"measured_phases"`
	PhaseWindowsNS              []float64 `json:"phase_windows_ns"`
	PhaseSampleOffsetsNS        []float64 `json:"phase_sample_offsets_ns"`
	ActiveVectorWindowsNS       []float64 `json:"active_vector_windows_ns"`
	ActiveVectorSampleOffsetsNS []float64 `json:"active_vector_sample_offsets_ns"`
	SwitchStates                []int     `json:"switch_states"`
	MaxSampleSkewNS             float64   `json:"max_sample_skew_ns"`
	AllowedSampleSkewNS         float64   `json:"allowed_sample_skew_ns"`
}
type SamplingPlan struct {
	Topology         string   `json:"topology"`
	RequiredWindowNS float64  `json:"required_window_ns"`
	ValidPhases      []int    `json:"valid_phases"`
	Reconstruction   string   `json:"reconstruction"`
	Recommendation   string   `json:"recommendation"`
	Alternatives     []string `json:"alternatives"`
}

func analyzeSampling(s *SamplingInput, acq float64, r *TimingReport) {
	p := &SamplingPlan{Topology: s.Topology, ValidPhases: []int{}, Reconstruction: "UNAVAILABLE", Recommendation: "Use hardware PWM/timer events for ADC; align encoder latch/start to the same clock when supported, otherwise timestamp physical latch and bound age", Alternatives: []string{}}
	r.Sampling = p
	for _, v := range []float64{s.DeadtimeNS, s.DriverDelayNS, s.RiseTimeNS, s.BlankingNS, s.AmplifierSettlingNS, s.GuardNS, s.MaxSampleSkewNS, s.AllowedSampleSkewNS} {
		if !nonnegative(v) {
			r.issue("SAMPLING_RANGE", "INVALID", "sampling delays and skew limits must be finite and nonnegative")
			return
		}
	}
	settle := s.DeadtimeNS + s.DriverDelayNS + s.RiseTimeNS + s.BlankingNS + s.AmplifierSettlingNS
	p.RequiredWindowNS = settle + acq + s.GuardNS
	if !finite(p.RequiredWindowNS) {
		r.issue("SAMPLING_RANGE", "INVALID", "required sampling window overflow")
		return
	}
	if !s.HardwareTrigger {
		r.issue("SOFTWARE_TRIGGER_JITTER", "INSUFFICIENT_EVIDENCE", "prefer timer/PWM-triggered ADC; software trigger requires independently bounded trigger jitter and sample timestamps")
	}
	if s.MaxSampleSkewNS > s.AllowedSampleSkewNS {
		r.issue("NON_SIMULTANEOUS_CURRENTS", "CONSTRAINT_VIOLATION", "sampling skew exceeds error budget; use parallel ADC/sample-and-hold or validated time alignment")
	}
	if s.Topology == "single_dc_link" {
		if len(s.ActiveVectorWindowsNS) != 2 || len(s.ActiveVectorSampleOffsetsNS) != 2 || len(s.SwitchStates) != 2 {
			r.issue("SINGLE_SHUNT_INPUT", "INVALID", "single_dc_link requires two actual contiguous active-vector windows and two explicit 3-bit high-side states")
			return
		}
		for n, v := range s.ActiveVectorWindowsNS {
			offset := s.ActiveVectorSampleOffsetsNS[n]
			if !nonnegative(v) || !nonnegative(offset) {
				r.issue("SAMPLING_RANGE", "INVALID", "invalid active-vector window")
				return
			}
			if v < p.RequiredWindowNS {
				r.issue("SINGLE_SHUNT_WINDOW", "CONSTRAINT_VIOLATION", "both active-vector windows must contain deadtime, blanking, settling, acquisition and guard")
			}
			if offset < settle || offset+acq+s.GuardNS > v {
				r.issue("SOC_OUTSIDE_VALID_WINDOW", "CONSTRAINT_VIOLATION", "actual acquisition start must follow settling and finish before the vector/window edge")
			}
		}
		rows := [2][3]int{}
		for n, state := range s.SwitchStates {
			if state < 1 || state > 6 {
				r.issue("ZERO_VECTOR_CURRENT", "INVALID", "000/111 zero vectors do not identify phase currents; state must be 1..6")
				return
			}
			for phase := 0; phase < 3; phase++ {
				rows[n][phase] = (state >> phase) & 1
			}
		}
		a, b := rows[0], rows[1]
		det := a[0]*(b[1]-b[2]) - a[1]*(b[0]-b[2]) + a[2]*(b[0]-b[1])
		if det == 0 {
			r.issue("CURRENT_RECONSTRUCTION_RANK", "CONSTRAINT_VIOLATION", "two DC-link measurements plus ia+ib+ic=0 are rank deficient")
			return
		}
		p.Reconstruction = "Solve idc1=s1.i, idc2=s2.i and ia+ib+ic=0; sequential samples also require bounded current slope and age"
		p.Alternatives = []string{"Shift PWM only through a verified modulation adapter preserving requested voltage and protection limits", "Reduce modulation or update rate only after checking torque/current ripple and available ADC windows", "Change sensing topology when two independent settled active vectors cannot be obtained"}
		return
	}
	if s.Topology != "two_low_side" && s.Topology != "three_low_side" && s.Topology != "three_inline" {
		r.issue("CURRENT_TOPOLOGY", "INVALID", "supported: single_dc_link, two_low_side, three_low_side, three_inline")
		return
	}
	if len(s.PhaseWindowsNS) != 3 || len(s.PhaseSampleOffsetsNS) != 3 {
		r.issue("PHASE_WINDOW_INPUT", "INVALID", "phase_windows_ns needs three candidate-window lengths (A,B,C)")
		return
	}
	expected := 3
	if s.Topology == "two_low_side" {
		expected = 2
	}
	if len(s.MeasuredPhases) != expected {
		r.issue("SHUNT_CHANNELS", "INVALID", fmt.Sprintf("topology requires %d installed phase-current channels", expected))
		return
	}
	seen := map[int]bool{}
	for _, phase := range s.MeasuredPhases {
		if phase < 0 || phase > 2 || seen[phase] {
			r.issue("SHUNT_CHANNELS", "INVALID", "measured_phases must be unique A=0,B=1,C=2")
			return
		}
		seen[phase] = true
		window := s.PhaseWindowsNS[phase]
		offset := s.PhaseSampleOffsetsNS[phase]
		if !nonnegative(window) || !nonnegative(offset) {
			r.issue("SAMPLING_RANGE", "INVALID", "phase windows must be finite and nonnegative")
			return
		}
		if window >= p.RequiredWindowNS && offset >= settle && offset+acq+s.GuardNS <= window {
			p.ValidPhases = append(p.ValidPhases, phase)
		}
	}
	if len(p.ValidPhases) < 2 {
		r.issue("PHASE_CURRENT_UNOBSERVABLE", "CONSTRAINT_VIOLATION", "fewer than two installed channels have a settled window at the chosen event")
	}
	if len(p.ValidPhases) == 2 {
		p.Reconstruction = "Reconstruct third current as minus sum of two valid time-aligned phase measurements"
	}
	if len(p.ValidPhases) == 3 {
		p.Reconstruction = "Use three valid time-aligned currents and check ia+ib+ic residual against offset/noise budget"
	}
	if s.Topology == "three_inline" {
		p.Alternatives = []string{"Inline sensing is not restricted to low-side conduction, but common-mode transients and amplifier recovery still constrain windows"}
	} else {
		p.Alternatives = []string{"Choose valley/peak from actual high/low-side polarity and AQ; ZERO is not always quiet", "With three low-side shunts choose any two valid channels; with two shunts both installed channels must remain observable", "Move SOC or reduce modulation only after accepting voltage, torque and current-ripple effects"}
	}
}
