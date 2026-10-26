package main

import (
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// This adapter describes only the observed driverlib subset. It never supplies
// a default MCU, ADC resolution/latency, clock, ISR overhead or execution time.
type EventLink struct {
	From      string     `json:"from"`
	To        string     `json:"to"`
	Condition string     `json:"condition"`
	Sources   []Location `json:"sources"`
	Status    string     `json:"status"`
}
type PWMCandidate struct {
	Base         string     `json:"base"`
	PeriodCounts *float64   `json:"period_counts,omitempty"`
	Mode         string     `json:"mode"`
	CLKDiv       *float64   `json:"clk_div,omitempty"`
	HSPDiv       *float64   `json:"hspclk_div,omitempty"`
	SOCEvent     string     `json:"soc_event"`
	ShadowEvent  string     `json:"shadow_event"`
	Sources      []Location `json:"sources"`
	Status       string     `json:"status"`
}

func c2000Events(facts []SourceFact) ([]EventLink, []PWMCandidate) {
	links := []EventLink{}
	links = append(links, sysconfigRoutes(facts)...)
	candidates := []PWMCandidate{}
	groups := map[string][]SourceFact{}
	for _, f := range facts {
		if len(f.Arguments) == 0 {
			continue
		}
		base := f.Arguments[0].Expression
		if strings.HasPrefix(base, "EPWM") && strings.HasSuffix(base, "_BASE") {
			groups[base] = append(groups[base], f)
		}
		if f.Symbol == "ADC_setupSOC" && len(f.Arguments) == 5 {
			trigger := f.Arguments[2].Expression
			adc := base + "." + f.Arguments[1].Expression
			links = append(links, EventLink{strings.TrimPrefix(trigger, "ADC_TRIGGER_"), adc, "SOC trigger selection; channel " + f.Arguments[3].Expression + "; acquisition cycles " + f.Arguments[4].Expression, []Location{f.Location}, "CONFIRMED_SOURCE_ONLY"})
			links = append(links, EventLink{adc, adc + ".EOC", "conversion completes after acquisition plus device/mode-dependent latency", []Location{f.Location}, "UNKNOWN_LATENCY"})
		}
		if f.Symbol == "ADC_setInterruptSource" && len(f.Arguments) == 3 {
			links = append(links, EventLink{base + "." + f.Arguments[2].Expression + ".EOC", base + "." + f.Arguments[1].Expression, "ADCINT EOC selection; pulse/enable/overflow/clear still require checking", []Location{f.Location}, "CONFIRMED_SOURCE_ONLY"})
		}
		if f.Symbol == "Interrupt_register" && len(f.Arguments) == 2 {
			links = append(links, EventLink{base, strings.TrimPrefix(f.Arguments[1].Expression, "&"), "vector registration; interrupt enable/priority/nesting require independent evidence", []Location{f.Location}, "STATIC_CALL_PATH_ONLY"})
		}
	}
	bases := []string{}
	for base := range groups {
		bases = append(bases, base)
	}
	sort.Strings(bases)
	for _, base := range bases {
		p := PWMCandidate{Base: base, Mode: "UNKNOWN", SOCEvent: "UNKNOWN", ShadowEvent: "UNKNOWN", Status: "INSUFFICIENT_EVIDENCE", Sources: []Location{}}
		seen := map[string]int{}
		for _, f := range groups[base] {
			seen[f.Symbol]++
			p.Sources = append(p.Sources, f.Location)
			args := f.Arguments
			switch f.Symbol {
			case "EPWM_setTimeBasePeriod":
				if len(args) == 2 {
					p.PeriodCounts = args[1].Value
				}
			case "EPWM_setTimeBaseCounterMode":
				if len(args) == 2 {
					p.Mode = args[1].Expression
				}
			case "EPWM_setClockPrescaler":
				if len(args) == 3 {
					p.CLKDiv = enumDiv(args[1].Expression, "EPWM_CLOCK_DIVIDER_")
					p.HSPDiv = enumDiv(args[2].Expression, "EPWM_HSCLOCK_DIVIDER_")
				}
			case "EPWM_setADCTriggerSource":
				if len(args) == 3 {
					p.SOCEvent = args[2].Expression
					links = append(links, EventLink{base + ".TBCTR", strings.TrimSuffix(base, "_BASE") + "_SOC" + strings.TrimPrefix(args[1].Expression, "EPWM_SOC_"), args[2].Expression + "; event prescale/enable must be resolved", []Location{f.Location}, "CONFIRMED_SOURCE_ONLY"})
				}
			case "EPWM_setCounterCompareShadowLoadMode":
				if len(args) == 3 {
					p.ShadowEvent = args[2].Expression
					links = append(links, EventLink{base + ".shadow_write", base + "." + args[1].Expression + ".active", args[2].Expression + "; global-load/sync/one-shot can alter actual transfer", []Location{f.Location}, "CONFIRMED_SOURCE_ONLY"})
				}
			}
		}
		for symbol, count := range seen {
			if count > 1 && (symbol == "EPWM_setTimeBasePeriod" || symbol == "EPWM_setTimeBaseCounterMode" || symbol == "EPWM_setClockPrescaler" || symbol == "EPWM_setADCTriggerSource" || symbol == "EPWM_setCounterCompareShadowLoadMode") {
				p.Mode = "AMBIGUOUS_WRITES"
				p.PeriodCounts = nil
				p.CLKDiv = nil
				p.HSPDiv = nil
			}
		}
		candidates = append(candidates, p)
	}
	return links, candidates
}

func sysconfigRoutes(facts []SourceFact) []EventLink {
	bindings := map[string][]SourceFact{}
	for _, f := range facts {
		if f.Kind != "sysconfig_assignment" || len(f.Arguments) != 1 {
			continue
		}
		for _, suffix := range []string{".clbBase", ".epwmBase", ".adcBase", ".spiBase", ".eqepBase"} {
			if strings.HasSuffix(f.Symbol, suffix) {
				instance := strings.TrimSuffix(f.Symbol, suffix)
				bindings[instance] = append(bindings[instance], f)
			}
		}
	}
	routePattern := regexp.MustCompile(`^([A-Za-z_]\w*)\.globalConfigCLB_IN([0-9]+)$`)
	pwmPattern := regexp.MustCompile(`^CLB_GLOBAL_IN_MUX_EPWM([0-9]+)_CTR_(ZERO|PRD|PERIOD)$`)
	basePattern := regexp.MustCompile(`^(CLB|EPWM|ADC|SPI|EQEP)[A-Z0-9]*_BASE$`)
	links := []EventLink{}
	for _, f := range facts {
		m := routePattern.FindStringSubmatch(f.Symbol)
		if f.Kind != "sysconfig_assignment" || len(m) != 3 || len(f.Arguments) != 1 {
			continue
		}
		binding := bindings[m[1]]
		if len(binding) != 1 {
			continue
		}
		base, err := strconv.Unquote(binding[0].Arguments[0].Expression)
		if err != nil || !basePattern.MatchString(base) {
			continue
		}
		value, err := strconv.Unquote(f.Arguments[0].Expression)
		if err != nil {
			continue
		}
		pwm := pwmPattern.FindStringSubmatch(value)
		if len(pwm) != 3 {
			continue
		}
		event := pwm[2]
		if event == "PRD" {
			event = "PERIOD"
		}
		links = append(links, EventLink{"EPWM" + pwm[1] + "_BASE.TBCTR." + event, base + ".IN" + m[2], "candidate global route with explicit hardware-base binding; verify GLOBAL/LOCAL selector, generated code and enable state", []Location{binding[0].Location, f.Location}, "CONFIRMED_SOURCE_ONLY"})
	}
	return links
}
func enumDiv(s, prefix string) *float64 {
	if !strings.HasPrefix(s, prefix) {
		return nil
	}
	integer, err := strconv.Atoi(strings.TrimPrefix(s, prefix))
	if err != nil || strconv.Itoa(integer) != strings.TrimPrefix(s, prefix) {
		return nil
	}
	value := float64(integer)
	allowed := []float64{1, 2, 4, 6, 8, 10, 12, 14, 16, 32, 64, 128}
	if prefix == "EPWM_CLOCK_DIVIDER_" {
		allowed = []float64{1, 2, 4, 8, 16, 32, 64, 128}
	} else if prefix == "EPWM_HSCLOCK_DIVIDER_" {
		allowed = []float64{1, 2, 4, 6, 8, 10, 12, 14}
	}
	for _, a := range allowed {
		if value == a {
			return &value
		}
	}
	return nil
}
