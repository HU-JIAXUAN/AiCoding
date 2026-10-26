package main

import (
	"fmt"
	"math"
	"strings"
)

// All time values are ns, clock values Hz, angles electrical rad, SI elsewhere.
// Inputs are explicit assertions with provenance, never discovered board facts.
type TimingInput struct {
	SchemaVersion   int               `json:"schema_version"`
	Sources         []string          `json:"sources"`
	Clock           ClockInput        `json:"clock"`
	PWM             PWMInput          `json:"pwm"`
	ADC             ADCInput          `json:"adc"`
	Schedule        ScheduleInput     `json:"schedule"`
	Encoder         *EncoderInput     `json:"encoder,omitempty"`
	Observations    *ObservationInput `json:"observations,omitempty"`
	CurrentSampling *SamplingInput    `json:"current_sampling,omitempty"`
}
type ClockInput struct {
	SYSCLKHz  float64 `json:"sysclk_hz"`
	EPWMDiv   float64 `json:"epwm_div"`
	CLKDiv    float64 `json:"clk_div"`
	HSPCLKDiv float64 `json:"hspclk_div"`
}
type PWMInput struct {
	PeriodCounts   int      `json:"period_counts"`
	Mode           string   `json:"mode"`
	SOCEvent       string   `json:"soc_event"`
	SOCEvery       int      `json:"soc_every"`
	ShadowEvent    string   `json:"shadow_event"`
	SamplePolicy   string   `json:"sample_policy"`
	CompareCounts  *int     `json:"compare_counts,omitempty"`
	SampleWindowNS *float64 `json:"sample_window_ns,omitempty"`
	DeadtimeNS     *float64 `json:"deadtime_ns,omitempty"`
	DriverDelayNS  *float64 `json:"driver_delay_ns,omitempty"`
}
type ADCInput struct {
	AcquisitionRC             *AcquisitionRC `json:"acquisition_rc,omitempty"`
	ClockDiv                  float64        `json:"clock_div"`
	AcquisitionSYSCLKCycles   int            `json:"acquisition_sysclk_cycles"`
	ResultLatencySYSCLKCycles float64        `json:"result_latency_sysclk_cycles"`
	TriggerSYSCLKCycles       float64        `json:"trigger_sysclk_cycles"`
	SerialConversions         int            `json:"serial_conversions"`
	SequenceModel             string         `json:"sequence_model"`
	ArbitrationDelayNS        *float64       `json:"arbitration_delay_ns"`
	InterruptLeadSYSCLKCycles *float64       `json:"interrupt_lead_sysclk_cycles"`
	MinimumAcquisitionNS      *float64       `json:"minimum_acquisition_ns,omitempty"`
}
type ScheduleInput struct {
	ISRSource     string   `json:"isr_source"`
	ISRPhaseNS    *float64 `json:"isr_phase_ns,omitempty"`
	ISREntryNS    *float64 `json:"isr_entry_ns"`
	FixedDelayNS  *float64 `json:"fixed_delay_ns"`
	GuardNS       *float64 `json:"guard_ns"`
	JitterBoundNS *float64 `json:"jitter_bound_ns"`
	FOCBoundNS    *float64 `json:"foc_bound_ns"`
	FOCBoundKind  string   `json:"foc_bound_kind"`
}

// An explicitly justified first-order charging model, not a complete ADC driver
// model: slew/recovery, charge sharing and nonlinear impedances are excluded.
type AcquisitionRC struct {
	ResistanceOhm  float64 `json:"resistance_ohm"`
	CapacitanceF   float64 `json:"capacitance_f"`
	ResolutionBits int     `json:"resolution_bits"`
	MaxErrorLSB    float64 `json:"max_error_lsb"`
	StepFraction   float64 `json:"step_fraction"`
	ModelConfirmed bool    `json:"model_confirmed"`
}
type AcquisitionReport struct {
	RCMinimumNS         float64 `json:"rc_minimum_ns"`
	RequiredMinimumNS   float64 `json:"required_minimum_ns"`
	MinimumSYSCLKCycles float64 `json:"minimum_sysclk_cycles"`
	Status              string  `json:"status"`
	Limit               string  `json:"limit"`
}
type EncoderInput struct {
	UpdateIndex            int      `json:"update_index"`
	LatchNS                float64  `json:"latch_ns"`
	ReceiveNS              float64  `json:"receive_ns"`
	ParkNS                 float64  `json:"park_ns"`
	ApplyNS                float64  `json:"apply_ns"`
	MaxAgeNS               float64  `json:"max_age_ns"`
	OmegaERadS             float64  `json:"omega_e_rad_s"`
	AccelerationBoundRadS2 float64  `json:"acceleration_bound_rad_s2"`
	CompensationOwners     []string `json:"compensation_owners"`
}
type ObservationInput struct {
	Source      string    `json:"source"`
	DurationsNS []float64 `json:"durations_ns"`
}
type Diagnostic struct {
	Code    string `json:"code"`
	Status  string `json:"status"`
	Message string `json:"message"`
}
type Event struct {
	Name      string   `json:"name"`
	Condition string   `json:"condition"`
	TimeNS    float64  `json:"time_ns"`
	Cycle     int      `json:"cycle"`
	Status    string   `json:"status"`
	Sources   []string `json:"sources"`
}
type Budget struct {
	SampleNS            float64  `json:"sample_ns"`
	ADCReadyNS          float64  `json:"adc_ready_ns"`
	ADCReadNS           float64  `json:"adc_read_ns"`
	ISRStartNS          float64  `json:"isr_start_ns"`
	ShadowLoadNS        float64  `json:"shadow_load_ns"`
	DeadlineNS          float64  `json:"t_deadline_ns"`
	FixedDelayNS        float64  `json:"t_fixed_delay_ns"`
	GuardNS             float64  `json:"t_guard_ns"`
	AvailableNS         float64  `json:"t_available_ns"`
	ComputationMarginNS *float64 `json:"computation_margin_ns"`
	SampleCycle         int      `json:"sample_cycle"`
	ReadCycle           int      `json:"read_cycle"`
	ApplyCycle          int      `json:"apply_cycle"`
	SameCycleRead       bool     `json:"same_cycle_read"`
}
type TimingReport struct {
	Acquisition     *AcquisitionReport `json:"acquisition,omitempty"`
	SchemaVersion   int                `json:"schema_version"`
	Status          string             `json:"status"`
	Evidence        string             `json:"evidence"`
	TBCLKHz         float64            `json:"tbclk_hz"`
	PWMHz           float64            `json:"pwm_hz"`
	CurrentUpdateHz float64            `json:"current_update_hz"`
	BandwidthStatus string             `json:"closed_loop_bandwidth_status"`
	CarrierPeriodNS float64            `json:"carrier_period_ns"`
	ADCSequenceNS   float64            `json:"adc_sequence_ns"`
	Budgets         []Budget           `json:"budgets"`
	Events          []Event            `json:"events"`
	Encoder         map[string]float64 `json:"encoder,omitempty"`
	WCETStatus      string             `json:"wcet_status"`
	ObservedMaxNS   *float64           `json:"observed_max_ns,omitempty"`
	Sampling        *SamplingPlan      `json:"sampling,omitempty"`
	Diagnostics     []Diagnostic       `json:"diagnostics"`
}

func finite(x float64) bool      { return !math.IsNaN(x) && !math.IsInf(x, 0) }
func positive(x float64) bool    { return finite(x) && x > 0 }
func nonnegative(x float64) bool { return finite(x) && x >= 0 }
func (r *TimingReport) issue(code, status, message string) {
	r.Diagnostics = append(r.Diagnostics, Diagnostic{code, status, message})
	priority := map[string]int{"DERIVED": 0, "INSUFFICIENT_EVIDENCE": 1, "CONSTRAINT_VIOLATION": 2, "INVALID": 3}
	if priority[status] > priority[r.Status] {
		r.Status = status
	}
}

func analyze(in TimingInput) TimingReport {
	r := TimingReport{SchemaVersion: 1, Status: "DERIVED", Evidence: "Mathematical Reference; conditional on supplied configuration and bounds", WCETStatus: "NOT_MEASURED", BandwidthStatus: "UNKNOWN", Budgets: []Budget{}, Events: []Event{}, Diagnostics: []Diagnostic{}}
	if in.SchemaVersion != 1 {
		r.issue("SCHEMA_VERSION", "INVALID", "schema_version must be 1")
		return r
	}
	if len(in.Sources) == 0 {
		r.issue("MISSING_PROVENANCE", "INSUFFICIENT_EVIDENCE", "supply file:line/hash or measurement references; supplied values are not board facts")
	}
	for _, source := range in.Sources {
		if strings.TrimSpace(source) == "" {
			r.issue("MISSING_PROVENANCE", "INSUFFICIENT_EVIDENCE", "source references must be nonempty")
		}
	}
	c, p, a, s := in.Clock, in.PWM, in.ADC, in.Schedule
	if !positive(c.SYSCLKHz) || !positive(c.EPWMDiv) || !positive(c.CLKDiv) || !positive(c.HSPCLKDiv) || p.PeriodCounts < 1 || p.PeriodCounts > 1<<30 || p.SOCEvery < 1 || p.SOCEvery > 1024 || !positive(a.ClockDiv) || a.AcquisitionSYSCLKCycles < 1 || a.AcquisitionSYSCLKCycles > 1<<30 || !positive(a.ResultLatencySYSCLKCycles) || !nonnegative(a.TriggerSYSCLKCycles) || a.SerialConversions < 1 || a.SerialConversions > 1024 {
		r.issue("RANGE", "INVALID", "invalid clock, period, SOC prescale or bounded ADC sequence parameters")
		return r
	}
	r.TBCLKHz = c.SYSCLKHz / c.EPWMDiv / c.CLKDiv / c.HSPCLKDiv
	counts := float64(p.PeriodCounts + 1)
	if p.Mode == "up_down" {
		counts = 2 * float64(p.PeriodCounts)
	} else if p.Mode != "up" && p.Mode != "down" {
		r.issue("PWM_MODE", "INVALID", "mode must be up, down, up_down")
		return r
	}
	r.CarrierPeriodNS = counts / r.TBCLKHz * 1e9
	if !positive(r.CarrierPeriodNS) {
		r.issue("NUMERIC_RANGE", "INVALID", "clock ratios overflow")
		return r
	}
	r.PWMHz = 1e9 / r.CarrierPeriodNS
	period := r.CarrierPeriodNS
	// In up/down single-slope modes PERIOD and ZERO differ by one TBCLK.
	phases := func(event string) ([]float64, error) {
		zero, peak := 0.0, float64(p.PeriodCounts)/r.TBCLKHz*1e9
		if p.Mode == "down" {
			zero, peak = peak, 0
		}
		switch event {
		case "zero":
			return []float64{zero}, nil
		case "period":
			return []float64{peak}, nil
		case "zero_or_period":
			return []float64{math.Min(zero, peak), math.Max(zero, peak)}, nil
		case "compare_up", "compare_down":
			if p.CompareCounts == nil || *p.CompareCounts <= 0 || *p.CompareCounts >= p.PeriodCounts {
				return nil, fmt.Errorf("compare event needs 0 < compare_counts < period_counts")
			}
			if event == "compare_up" && p.Mode == "down" || event == "compare_down" && p.Mode == "up" {
				return nil, fmt.Errorf("compare slope unavailable")
			}
			t := float64(*p.CompareCounts) / r.TBCLKHz * 1e9
			if event == "compare_down" {
				t = (float64(p.PeriodCounts) - float64(*p.CompareCounts)) / r.TBCLKHz * 1e9
				if p.Mode == "up_down" {
					t += period / 2
				}
			}
			return []float64{t}, nil
		}
		return nil, fmt.Errorf("unsupported event %q", event)
	}
	samples, err := phases(p.SOCEvent)
	if err != nil {
		r.issue("SOC_EVENT", "INVALID", err.Error())
		return r
	}
	loads, err := phases(p.ShadowEvent)
	if err != nil {
		r.issue("SHADOW_EVENT", "INVALID", err.Error())
		return r
	}
	if p.SOCEvery != 1 {
		r.issue("SOC_PRESCALE_PHASE", "INSUFFICIENT_EVIDENCE", "prescale >1 requires event-counter initial phase; no per-cycle deadline derived")
		return r
	}
	switch p.SamplePolicy {
	case "valley":
		if p.SOCEvent != "zero" {
			r.issue("SAMPLING_POLICY", "INVALID", "valley requires zero SOC")
		}
	case "peak":
		if p.SOCEvent != "period" {
			r.issue("SAMPLING_POLICY", "INVALID", "peak requires period SOC")
		}
	case "double_single":
		if p.Mode != "up_down" || len(samples) != 2 || len(loads) != 1 {
			r.issue("SAMPLING_POLICY", "INVALID", "double_single requires center-aligned dual SOC and single shadow load")
		} else {
			// The most recent sample before the next load owns the update.
			selected, best := 0.0, math.Inf(1)
			for _, t := range samples {
				d := loads[0] - t
				if d <= 0 {
					d += period
				}
				if d < best {
					selected, best = t, d
				}
			}
			samples = []float64{selected}
		}
	case "double_double":
		if p.Mode != "up_down" || len(samples) != 2 || len(loads) != 2 {
			r.issue("SAMPLING_POLICY", "INVALID", "double_double requires center-aligned dual SOC and dual shadow load")
		}
	default:
		r.issue("SAMPLING_POLICY", "INVALID", "sample_policy must explicitly state valley, peak, double_single or double_double")
	}
	if r.Status == "INVALID" {
		return r
	}
	r.CurrentUpdateHz = float64(len(samples)) * r.PWMHz
	acq := float64(a.AcquisitionSYSCLKCycles) / c.SYSCLKHz * 1e9
	if a.AcquisitionRC != nil {
		analyzeAcquisition(a.AcquisitionRC, a.MinimumAcquisitionNS, acq, c.SYSCLKHz, &r)
	}
	if in.CurrentSampling != nil {
		analyzeSampling(in.CurrentSampling, acq, &r)
	}
	conversion := a.ResultLatencySYSCLKCycles / c.SYSCLKHz * 1e9
	if a.SequenceModel != "nonoverlap_bound" {
		r.issue("ADC_SEQUENCE_MODEL", "INVALID", "supported sequence_model is nonoverlap_bound; account for all required serial conversions and arbitration")
	}
	if a.ArbitrationDelayNS == nil || a.InterruptLeadSYSCLKCycles == nil {
		r.issue("ADC_READY_EVIDENCE", "INSUFFICIENT_EVIDENCE", "arbitration_delay_ns and interrupt_lead_sysclk_cycles must be explicit; ADCINT can precede result latch")
		return r
	}
	if !nonnegative(*a.ArbitrationDelayNS) || !nonnegative(*a.InterruptLeadSYSCLKCycles) {
		r.issue("ADC_READY_RANGE", "INVALID", "ADC arbitration/interrupt lead must be finite and nonnegative")
		return r
	}
	r.ADCSequenceNS = a.TriggerSYSCLKCycles/c.SYSCLKHz*1e9 + *a.ArbitrationDelayNS + float64(a.SerialConversions)*(acq+conversion)
	if !finite(r.ADCSequenceNS) {
		r.issue("NUMERIC_RANGE", "INVALID", "ADC duration overflow")
		return r
	}
	for name, v := range map[string]*float64{"isr_entry_ns": s.ISREntryNS, "fixed_delay_ns": s.FixedDelayNS, "guard_ns": s.GuardNS, "jitter_bound_ns": s.JitterBoundNS, "foc_bound_ns": s.FOCBoundNS} {
		if v == nil {
			r.issue("MISSING_BOUND", "INSUFFICIENT_EVIDENCE", name+" is unknown")
		} else if !nonnegative(*v) {
			r.issue("RANGE", "INVALID", name+" must be finite and >= 0")
		}
	}
	// Map iteration must never affect the canonical output order.
	sortDiagnostics(r.Diagnostics)
	if s.FOCBoundNS != nil && s.FOCBoundKind != "static_estimate" && s.FOCBoundKind != "proven_bound" {
		r.issue("BOUND_KIND", "INVALID", "foc_bound_kind must be static_estimate or proven_bound; observed maxima are not WCET bounds")
	}
	if a.MinimumAcquisitionNS != nil {
		if !positive(*a.MinimumAcquisitionNS) {
			r.issue("RANGE", "INVALID", "invalid minimum_acquisition_ns")
		} else if acq < *a.MinimumAcquisitionNS {
			r.issue("ACQUISITION_TOO_SHORT", "CONSTRAINT_VIOLATION", "sample-and-hold time is below supplied analog/device minimum")
		}
	}
	if p.SampleWindowNS != nil {
		if !positive(*p.SampleWindowNS) {
			r.issue("RANGE", "INVALID", "invalid sample_window_ns")
		} else if *p.SampleWindowNS < acq {
			r.issue("INVALID_SAMPLE_WINDOW", "CONSTRAINT_VIOLATION", "valid settled window cannot contain sample-and-hold interval")
		}
	}
	for _, v := range []*float64{p.DeadtimeNS, p.DriverDelayNS} {
		if v != nil && !nonnegative(*v) {
			r.issue("RANGE", "INVALID", "power-stage delays must be finite and >=0")
		}
	}
	if s.ISRSource != "adc_eoc" && s.ISRSource != "epwm" {
		r.issue("ISR_SOURCE", "INVALID", "isr_source must be adc_eoc or epwm")
	}
	if s.ISRSource == "epwm" && (s.ISRPhaseNS == nil || !nonnegative(*s.ISRPhaseNS) || *s.ISRPhaseNS >= period) {
		r.issue("ISR_PHASE", "INVALID", "ePWM ISR requires explicit phase within carrier")
	}
	if r.Status == "INVALID" {
		return r
	}
	if s.ISREntryNS == nil || s.FixedDelayNS == nil || s.GuardNS == nil || s.JitterBoundNS == nil {
		return r
	}
	value := func(v *float64) float64 {
		if v == nil {
			return 0
		}
		return *v
	}
	event := func(name, condition string, t float64) {
		r.Events = append(r.Events, Event{name, condition, t, int(math.Floor(t / period)), "DERIVED", in.Sources})
	}
	for _, sample := range samples {
		load := math.Inf(1)
		for _, phase := range loads {
			t := phase
			for t <= sample {
				t += period
			}
			if t < load {
				load = t
			}
		}
		ready := sample + r.ADCSequenceNS
		start := ready - *a.InterruptLeadSYSCLKCycles/c.SYSCLKHz*1e9 + value(s.ISREntryNS)
		if s.ISRSource == "epwm" {
			start = value(s.ISRPhaseNS)
			for start < sample {
				start += period
			}
			start += value(s.ISREntryNS)
			if start+value(s.FixedDelayNS) < ready {
				r.issue("STALE_ADC_RESULT", "CONSTRAINT_VIOLATION", "ISR reads before this SOC sequence completes; a previous-cycle result would be consumed")
			}
		}
		if s.ISRSource == "adc_eoc" && start+value(s.FixedDelayNS) < ready {
			r.issue("ADC_READ_BEFORE_LATCH", "CONSTRAINT_VIOLATION", "ADCINT lead exceeds entry and pre-read delay; conversion result has not latched")
		}
		fixed := start - sample + value(s.FixedDelayNS) + value(s.JitterBoundNS)
		budget := Budget{SampleNS: sample, ADCReadyNS: ready, ADCReadNS: start + value(s.FixedDelayNS), ISRStartNS: start, ShadowLoadNS: load, DeadlineNS: load - sample, FixedDelayNS: fixed, GuardNS: value(s.GuardNS), AvailableNS: load - sample - fixed - value(s.GuardNS), SampleCycle: int(math.Floor(sample / period)), ReadCycle: int(math.Floor((start + value(s.FixedDelayNS)) / period)), ApplyCycle: int(math.Floor(load / period))}
		budget.SameCycleRead = budget.ReadCycle == budget.SampleCycle && start+value(s.FixedDelayNS) >= ready
		event("soc", p.SOCEvent, sample)
		event("adc_acquisition_start", "SOC plus supplied trigger and arbitration latency", sample+a.TriggerSYSCLKCycles/c.SYSCLKHz*1e9+*a.ArbitrationDelayNS)
		event("adc_last_sample_capture", "end of last S/H under the supplied nonoverlap sequence bound", ready-conversion)
		event("adc_sequence_complete", "all required serial conversions complete", ready)
		event("isr_start", s.ISRSource, start)
		if s.FOCBoundNS != nil {
			margin := budget.AvailableNS - *s.FOCBoundNS
			budget.ComputationMarginNS = &margin
			event("shadow_write_complete", "supplied FOC bound plus fixed delay and jitter", start+value(s.FixedDelayNS)+value(s.JitterBoundNS)+*s.FOCBoundNS)
			if margin < 0 {
				r.issue("DEADLINE_MISSED", "CONSTRAINT_VIOLATION", "FOC bound exceeds available shadow-write budget")
			}
		}
		if budget.AvailableNS <= 0 {
			r.issue("NO_COMPUTE_WINDOW", "CONSTRAINT_VIOLATION", "fixed delays and guard consume the update window")
		}
		event("pwm_command_load", p.ShadowEvent, load)
		if p.DeadtimeNS != nil && p.DriverDelayNS != nil {
			event("earliest_gate_effect", "load plus supplied delays; actual AQ/compare edge can occur later", load+*p.DeadtimeNS+*p.DriverDelayNS)
		}
		r.Budgets = append(r.Budgets, budget)
	}
	if in.Encoder != nil {
		analyzeEncoder(in.Encoder, &r)
	}
	if o := in.Observations; o != nil {
		if o.Source == "" || len(o.DurationsNS) == 0 {
			r.issue("MEASUREMENT_SOURCE", "INVALID", "observations require capture source and nonempty durations")
		} else {
			maximum := 0.0
			for _, t := range o.DurationsNS {
				if !positive(t) {
					r.issue("MEASUREMENT_RANGE", "INVALID", "durations must be positive")
				}
				maximum = math.Max(t, maximum)
			}
			r.ObservedMaxNS = &maximum
			r.WCETStatus = "OBSERVED_MAX_ONLY"
			if s.FOCBoundNS != nil && maximum > *s.FOCBoundNS {
				r.issue("OBSERVED_BOUND_EXCEEDED", "CONSTRAINT_VIOLATION", "capture exceeds supplied execution bound")
			}
		}
	}
	if s.FOCBoundNS != nil && s.FOCBoundKind == "static_estimate" {
		r.issue("ESTIMATED_EXECUTION", "DERIVED", "deadline is conditional on a static estimate; target WCET remains unqualified")
	}
	sortDiagnostics(r.Diagnostics)
	return r
}

func analyzeAcquisition(rc *AcquisitionRC, datasheet *float64, actualNS, sysclk float64, r *TimingReport) {
	if !positive(rc.ResistanceOhm) || !positive(rc.CapacitanceF) || rc.ResolutionBits < 1 || rc.ResolutionBits > 32 || !positive(rc.MaxErrorLSB) || rc.MaxErrorLSB >= math.Ldexp(1, rc.ResolutionBits) || !nonnegative(rc.StepFraction) || rc.StepFraction > 1 {
		r.issue("RC_MODEL_RANGE", "INVALID", "require positive effective R/C, 1..32 bits, explicit error in LSB and step fraction 0..1")
		return
	}
	fraction := rc.MaxErrorLSB / math.Ldexp(1, rc.ResolutionBits)
	minimum := 0.0
	if rc.StepFraction > fraction {
		minimum = rc.ResistanceOhm * rc.CapacitanceF * math.Log(rc.StepFraction/fraction) * 1e9
		if minimum == 0 {
			r.issue("RC_MODEL_RANGE", "INVALID", "positive RC settling underflowed the supported numeric range")
			return
		}
	}
	if !nonnegative(minimum) {
		r.issue("RC_MODEL_RANGE", "INVALID", "RC settling calculation overflow")
		return
	}
	required := minimum
	if datasheet != nil {
		required = math.Max(required, *datasheet)
	}
	cycles := math.Ceil(required * sysclk * 1e-9)
	if !nonnegative(cycles) {
		r.issue("RC_MODEL_RANGE", "INVALID", "required acquisition cycles overflow")
		return
	}
	r.Acquisition = &AcquisitionReport{minimum, required, cycles, "DERIVED", "ideal first-order RC lower bound; not a measured ADC accuracy guarantee"}
	if !rc.ModelConfirmed || datasheet == nil {
		r.Acquisition.Status = "INSUFFICIENT_EVIDENCE"
		r.issue("RC_MODEL_EVIDENCE", "INSUFFICIENT_EVIDENCE", "confirm effective R/C and first-order validity, and provide device minimum acquisition; charge sharing/slew/recovery cannot be silently folded into one RC")
	}
	if rc.ModelConfirmed && actualNS < required {
		r.issue("ACQUISITION_RC_TOO_SHORT", "CONSTRAINT_VIOLATION", "S/H interval is below the maximum of declared RC accuracy requirement and device acquisition minimum")
	}
}

func analyzeEncoder(e *EncoderInput, r *TimingReport) {
	if e.UpdateIndex < 0 || e.UpdateIndex >= len(r.Budgets) {
		r.issue("ENCODER_UPDATE_INDEX", "INVALID", "encoder update_index must select a computed budget on the same time epoch")
		return
	}
	budget := r.Budgets[e.UpdateIndex]
	if e.ParkNS < budget.ADCReadNS || e.ParkNS > budget.ShadowLoadNS || e.ApplyNS < budget.ShadowLoadNS {
		r.issue("ENCODER_EVENT_MISMATCH", "CONSTRAINT_VIOLATION", "Park cannot precede this update's ADC read or follow its load; encoder apply time cannot precede the selected ShadowLoad")
		return
	}
	for _, v := range []float64{e.LatchNS, e.ReceiveNS, e.ParkNS, e.ApplyNS, e.MaxAgeNS, e.AccelerationBoundRadS2} {
		if !nonnegative(v) {
			r.issue("ENCODER_RANGE", "INVALID", "encoder times/age/acceleration bound must be finite and >=0")
			return
		}
	}
	if !finite(e.OmegaERadS) || e.LatchNS > e.ReceiveNS || e.ReceiveNS > e.ParkNS || e.ParkNS > e.ApplyNS {
		r.issue("ENCODER_TIME_ORDER", "INVALID", "require physical latch <= receive <= Park <= actuation and finite electrical speed")
		return
	}
	if len(e.CompensationOwners) > 1 {
		r.issue("DUPLICATE_DELAY_COMPENSATION", "CONSTRAINT_VIOLATION", "exactly one module may own angle prediction")
	}
	parkAge, applyAge := e.ParkNS-e.LatchNS, e.ApplyNS-e.LatchNS
	r.Encoder = map[string]float64{"park_age_ns": parkAge, "apply_age_ns": applyAge, "park_prediction_rad": e.OmegaERadS * parkAge * 1e-9, "apply_prediction_rad": e.OmegaERadS * applyAge * 1e-9, "prediction_error_bound_rad": 0.5 * e.AccelerationBoundRadS2 * math.Pow(applyAge*1e-9, 2)}
	if applyAge > e.MaxAgeNS {
		r.issue("STALE_ENCODER", "CONSTRAINT_VIOLATION", "physical angle age exceeds supplied bound; reception timestamp cannot replace latch time")
	}
}
