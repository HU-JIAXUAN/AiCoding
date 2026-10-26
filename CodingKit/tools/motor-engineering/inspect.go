package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

type Source struct {
	Path   string `json:"path"`
	SHA256 string `json:"sha256"`
	Bytes  int    `json:"bytes"`
}
type Location struct {
	Path string `json:"path"`
	Line int    `json:"line"`
}
type Argument struct {
	Expression string   `json:"expression"`
	Value      *float64 `json:"value,omitempty"`
	Status     string   `json:"status"`
}
type SourceFact struct {
	Kind      string     `json:"kind"`
	Symbol    string     `json:"symbol"`
	Arguments []Argument `json:"arguments"`
	Location  Location   `json:"source"`
	Status    string     `json:"status"`
	Scope     string     `json:"scope"`
}
type CallEdge struct {
	Caller     string   `json:"caller"`
	Callee     string   `json:"callee"`
	Location   Location `json:"source"`
	Resolution string   `json:"resolution"`
	Arguments  []string `json:"arguments"`
}
type ISRPath struct {
	Vector     string   `json:"vector"`
	Handler    string   `json:"handler"`
	Symbols    []string `json:"reachable_symbols"`
	Unresolved []string `json:"unresolved_symbols"`
	Status     string   `json:"status"`
}
type Inspection struct {
	SchemaVersion    int            `json:"schema_version"`
	Status           string         `json:"status"`
	Evidence         string         `json:"evidence"`
	InputDigest      string         `json:"input_digest"`
	Sources          []Source       `json:"sources"`
	TargetCandidates []SourceFact   `json:"target_candidates"`
	Facts            []SourceFact   `json:"facts"`
	Calls            []CallEdge     `json:"call_edges"`
	ISRPaths         []ISRPath      `json:"isr_paths"`
	EventLinks       []EventLink    `json:"event_links"`
	PWMCandidates    []PWMCandidate `json:"pwm_candidates"`
	Diagnostics      []Diagnostic   `json:"diagnostics"`
	WCETStatus       string         `json:"wcet_status"`
}
type sourceText struct{ path, raw, masked string }
type definition struct {
	name, path string
	start, end int
	params     []string
}

var (
	sysconfigAssignmentPattern = regexp.MustCompile(`\b([A-Za-z_]\w*(?:\.[A-Za-z_]\w*|\["[^"\n]+"\])+)\s*=\s*([^;\r\n]+);`)
	assignmentPattern          = regexp.MustCompile(`\b([A-Za-z_]\w*)\s*=\s*&?([A-Za-z_]\w*)\s*;`)
	parameterPattern           = regexp.MustCompile(`([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?$`)
	declarationPrefix          = regexp.MustCompile(`^[A-Za-z_]\w*(?:[ \t\r\n*]+[A-Za-z_]\w*)*[ \t\r\n*]*$`)
	callPattern                = regexp.MustCompile(`\b([A-Za-z_]\w*)\s*\(`)
	definePattern              = regexp.MustCompile(`(?m)^\s*#\s*define[ \t]+([A-Za-z_]\w*)[ \t]+([^\r\n]+)`)
	functionPattern            = regexp.MustCompile(`\b([A-Za-z_]\w*)\s*\([^;{}()]*\)\s*\{`)
	registerPattern            = regexp.MustCompile(`\b([A-Za-z_]\w*Regs(?:\.[A-Za-z_]\w*)+)\s*=\s*([^;]+);`)
	hexSuffixPattern           = regexp.MustCompile(`(?i)\b(0x[0-9a-f]+)[ul]+\b`)
	suffixPattern              = regexp.MustCompile(`(?i)\b([0-9]+(?:\.[0-9]*)?(?:e[+-]?[0-9]+)?)[ulf]+\b`)
)

func inspect(project string, files []string) (Inspection, error) {
	r := Inspection{SchemaVersion: 1, Status: "CONFIRMED_SOURCE_ONLY", Evidence: "source occurrences and syntactic call paths; not compiled reachability or running configuration", Sources: []Source{}, TargetCandidates: []SourceFact{}, Facts: []SourceFact{}, Calls: []CallEdge{}, ISRPaths: []ISRPath{}, WCETStatus: "NOT_MEASURED", Diagnostics: []Diagnostic{}}
	if len(files) > 128 {
		return r, fmt.Errorf("at most 128 explicit files per inspection")
	}
	root, err := filepath.Abs(project)
	if err != nil {
		return r, err
	}
	root, err = filepath.EvalSymlinks(root)
	if err != nil {
		return r, err
	}
	texts := []sourceText{}
	unique := map[string]bool{}
	sort.Strings(files)
	total := 0
	for _, name := range files {
		if filepath.IsAbs(name) {
			return r, fmt.Errorf("--file must be project-relative: %s", name)
		}
		full, err := filepath.EvalSymlinks(filepath.Join(root, name))
		if err != nil {
			return r, err
		}
		rel, err := filepath.Rel(root, full)
		if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
			return r, fmt.Errorf("file escapes project: %s", name)
		}
		rel = filepath.ToSlash(rel)
		if unique[rel] {
			continue
		}
		unique[rel] = true
		info, err := os.Stat(full)
		if err != nil {
			return r, err
		}
		if !info.Mode().IsRegular() || info.Size() > 2<<20 {
			return r, fmt.Errorf("not a regular file <=2 MiB: %s", rel)
		}
		total += int(info.Size())
		if total > 16<<20 {
			return r, fmt.Errorf("inspection limited to 16 MiB")
		}
		b, err := os.ReadFile(full)
		if err != nil {
			return r, err
		}
		h := sha256.Sum256(b)
		r.Sources = append(r.Sources, Source{rel, hex.EncodeToString(h[:]), len(b)})
		// C comments are masked byte-for-byte; source lines remain valid for GBK.
		texts = append(texts, sourceText{rel, string(b), maskComments(string(b))})
	}
	digest := sha256.New()
	for _, s := range r.Sources {
		fmt.Fprintf(digest, "%s\x00%s\n", s.Path, s.SHA256)
	}
	r.InputDigest = hex.EncodeToString(digest.Sum(nil))
	constants := map[string][]string{}
	for _, s := range texts {
		for _, m := range definePattern.FindAllStringSubmatch(s.masked, -1) {
			constants[m[1]] = append(constants[m[1]], strings.TrimSpace(m[2]))
		}
	}
	defs := []definition{}
	defined := map[string]int{}
	for _, s := range texts {
		masked := maskStrings(s.masked)
		for _, m := range functionPattern.FindAllStringSubmatchIndex(masked, -1) {
			name := masked[m[2]:m[3]]
			if keyword(name) {
				continue
			}
			open := m[1] - 1
			end := matching(masked, open, '{', '}')
			if end < 0 {
				continue
			}
			paren := strings.Index(masked[m[3]:open], "(") + m[3]
			close := matching(masked, paren, '(', ')')
			params := []string{}
			if close > paren {
				for _, param := range splitArgs(masked[paren+1 : close]) {
					part := parameterPattern.FindStringSubmatch(param)
					if len(part) > 1 && part[1] != "void" {
						params = append(params, part[1])
					}
				}
			}
			defs = append(defs, definition{name, s.path, open, end, params})
			defined[name]++
		}
	}
	for _, s := range texts {
		if strings.Contains(s.masked, "#if") {
			r.Diagnostics = append(r.Diagnostics, Diagnostic{"PREPROCESSOR_CONTEXT", "UNKNOWN", s.path + ": conditional compilation is not evaluated; use compiler preprocessed output for configuration proof"})
		}
		metadata(&r, s)
		if strings.HasSuffix(s.path, ".syscfg") {
			for _, m := range sysconfigAssignmentPattern.FindAllStringSubmatchIndex(s.masked, -1) {
				r.Facts = append(r.Facts, SourceFact{"sysconfig_assignment", s.masked[m[2]:m[3]], []Argument{argument(s.masked[m[4]:m[5]], constants)}, loc(s, m[0]), "CONFIRMED_SOURCE_ONLY", "declarative instance property; generated/runtime state not assumed"})
			}
		}
		for _, m := range definePattern.FindAllStringSubmatchIndex(s.masked, -1) {
			name, expr := s.masked[m[2]:m[3]], s.masked[m[4]:m[5]]
			if strings.Contains(name, "CLK") || strings.Contains(name, "PWM") || strings.Contains(name, "ADC") || strings.Contains(name, "BISS") {
				r.Facts = append(r.Facts, SourceFact{"constant", name, []Argument{argument(expr, constants)}, loc(s, m[0]), "CONFIRMED_SOURCE_ONLY", "build context not evaluated"})
			}
		}
		masked := maskStrings(s.masked)
		for _, m := range callPattern.FindAllStringSubmatchIndex(masked, -1) {
			name := masked[m[2]:m[3]]
			if keyword(name) {
				continue
			}
			open := m[1] - 1
			end := matching(s.masked, open, '(', ')')
			if end < 0 {
				continue
			}
			next := strings.TrimSpace(masked[end+1:])
			if strings.HasPrefix(next, "{") {
				continue
			}
			prefix := strings.TrimSpace(masked[strings.LastIndexAny(masked[:m[0]], ";{}")+1 : m[0]])
			if strings.HasPrefix(next, ";") && prefix != "return" && declarationPrefix.MatchString(prefix) {
				continue
			}
			args := splitArgs(s.masked[open+1 : end])
			scope := "translation-unit / initializer"
			for _, d := range defs {
				if d.path == s.path && m[0] > d.start && m[0] < d.end {
					scope = d.name
					break
				}
			}
			if scope != "translation-unit / initializer" {
				resolution := "UNRESOLVED_EXTERNAL_OR_INDIRECT"
				if defined[name] == 1 {
					resolution = "SYNTACTIC_DEFINITION"
				}
				if defined[name] > 1 {
					resolution = "AMBIGUOUS_DEFINITION"
				}
				r.Calls = append(r.Calls, CallEdge{scope, name, loc(s, m[0]), resolution, args})
			}
			if isPeripheral(name) {
				arguments := []Argument{}
				for _, a := range args {
					arguments = append(arguments, argument(a, constants))
				}
				r.Facts = append(r.Facts, SourceFact{"driverlib_call", name, arguments, loc(s, m[0]), "CONFIRMED_SOURCE_ONLY", scope})
			}
		}
		for _, m := range registerPattern.FindAllStringSubmatchIndex(masked, -1) {
			r.Facts = append(r.Facts, SourceFact{"register_write", masked[m[2]:m[3]], []Argument{argument(s.masked[m[4]:m[5]], constants)}, loc(s, m[0]), "CONFIRMED_SOURCE_ONLY", "control flow not evaluated"})
		}
	}
	// Resolve only simple explicit function-pointer assignments and literal
	// callback registration arguments. Candidates remain an overapproximation.
	directCalls := append([]CallEdge(nil), r.Calls...)
	for _, s := range texts {
		for _, m := range assignmentPattern.FindAllStringSubmatchIndex(maskStrings(s.masked), -1) {
			left, right := s.masked[m[2]:m[3]], s.masked[m[4]:m[5]]
			targets := []string{}
			if defined[right] == 1 {
				targets = append(targets, right)
			}
			for _, d := range defs {
				if d.path != s.path || m[0] < d.start || m[0] > d.end {
					continue
				}
				for index, param := range d.params {
					if param != right {
						continue
					}
					for _, call := range directCalls {
						if call.Callee != d.name || len(call.Arguments) <= index {
							continue
						}
						target := strings.TrimSpace(strings.TrimPrefix(call.Arguments[index], "&"))
						if defined[target] == 1 {
							targets = append(targets, target)
						}
					}
				}
			}
			sort.Strings(targets)
			previous := ""
			for _, target := range targets {
				if target == previous {
					continue
				}
				previous = target
				r.Calls = append(r.Calls, CallEdge{left, target, loc(s, m[0]), "SYNTACTIC_CALLBACK_CANDIDATE", []string{}})
			}
		}
	}
	adjacency := map[string][]string{}
	for _, edge := range r.Calls {
		adjacency[edge.Caller] = append(adjacency[edge.Caller], edge.Callee)
	}
	for _, f := range r.Facts {
		if f.Symbol != "Interrupt_register" || len(f.Arguments) < 2 {
			continue
		}
		handler := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(f.Arguments[1].Expression), "&"))
		path := ISRPath{Vector: f.Arguments[0].Expression, Handler: handler, Symbols: []string{}, Unresolved: []string{}, Status: "STATIC_CALL_PATH_ONLY"}
		queue := []string{handler}
		seen := map[string]bool{}
		for len(queue) > 0 && len(seen) < 4096 {
			symbol := queue[0]
			queue = queue[1:]
			if seen[symbol] {
				continue
			}
			seen[symbol] = true
			path.Symbols = append(path.Symbols, symbol)
			if defined[symbol] != 1 {
				path.Unresolved = append(path.Unresolved, symbol)
			}
			queue = append(queue, adjacency[symbol]...)
		}
		sort.Strings(path.Symbols)
		sort.Strings(path.Unresolved)
		r.ISRPaths = append(r.ISRPaths, path)
	}
	r.EventLinks, r.PWMCandidates = c2000Events(r.Facts)
	if len(r.TargetCandidates) == 0 {
		r.Diagnostics = append(r.Diagnostics, Diagnostic{"TARGET_UNKNOWN", "UNKNOWN", "no explicit device metadata in selected inputs; reference code does not select a target"})
	}
	r.Diagnostics = append(r.Diagnostics, Diagnostic{"STATIC_SCOPE", "UNKNOWN", "macro expansion, function pointers, interrupt nesting, Flash wait states, DMA/CLA arbitration, AQ/trip/global-load runtime state require compiler/target evidence"})
	sortDiagnostics(r.Diagnostics)
	return r, nil
}

func loc(s sourceText, offset int) Location {
	return Location{s.path, strings.Count(s.raw[:offset], "\n") + 1}
}
func keyword(s string) bool {
	switch s {
	case "if", "while", "for", "switch", "sizeof", "return", "_Static_assert":
		return true
	}
	return false
}
func isPeripheral(s string) bool {
	for _, p := range []string{"EPWM_", "ADC_", "Interrupt_", "SysCtl_", "DMA_", "CLA_", "EQEP_", "SPI_", "GPIO_"} {
		if strings.HasPrefix(s, p) {
			return true
		}
	}
	return false
}
func matching(s string, start int, open, close byte) int {
	depth := 0
	quote := byte(0)
	for i := start; i < len(s); i++ {
		c := s[i]
		if quote != 0 {
			if c == '\\' {
				i++
				continue
			}
			if c == quote {
				quote = 0
			}
			continue
		}
		if c == '\'' || c == '"' {
			quote = c
			continue
		}
		if c == open {
			depth++
		}
		if c == close {
			depth--
			if depth == 0 {
				return i
			}
		}
	}
	return -1
}
func splitArgs(s string) []string {
	out := []string{}
	start, depth := 0, 0
	quote := byte(0)
	for i := 0; i < len(s); i++ {
		c := s[i]
		if quote != 0 {
			if c == '\\' {
				i++
				continue
			}
			if c == quote {
				quote = 0
			}
			continue
		}
		if c == '\'' || c == '"' {
			quote = c
			continue
		}
		switch c {
		case '(', '[', '{':
			depth++
		case ')', ']', '}':
			depth--
		case ',':
			if depth == 0 {
				out = append(out, strings.TrimSpace(s[start:i]))
				start = i + 1
			}
		}
	}
	if strings.TrimSpace(s[start:]) != "" {
		out = append(out, strings.TrimSpace(s[start:]))
	}
	return out
}
func maskComments(s string) string {
	b := []byte(s)
	quote := byte(0)
	for i := 0; i < len(b); i++ {
		if quote != 0 {
			if b[i] == '\\' {
				i++
				continue
			}
			if b[i] == quote {
				quote = 0
			}
			continue
		}
		if b[i] == '\'' || b[i] == '"' {
			quote = b[i]
			continue
		}
		if i+1 < len(b) && b[i] == '/' && b[i+1] == '/' {
			for i < len(b) && b[i] != '\n' {
				if b[i] == '\\' && i+1 < len(b) && (b[i+1] == '\n' || b[i+1] == '\r' && i+2 < len(b) && b[i+2] == '\n') {
					b[i] = ' '
					i++
					if b[i] == '\r' {
						b[i] = ' '
						i++
					}
					i++
					continue
				}
				b[i] = ' '
				i++
			}
		} else if i+1 < len(b) && b[i] == '/' && b[i+1] == '*' {
			b[i], b[i+1] = ' ', ' '
			i += 2
			for i < len(b) {
				if i+1 < len(b) && b[i] == '*' && b[i+1] == '/' {
					b[i], b[i+1] = ' ', ' '
					i++
					break
				}
				if b[i] != '\n' {
					b[i] = ' '
				}
				i++
			}
		}
	}
	return string(b)
}
func maskStrings(s string) string {
	b := []byte(s)
	for i := 0; i < len(b); i++ {
		if b[i] != '"' && b[i] != '\'' {
			continue
		}
		q := b[i]
		b[i] = ' '
		for i++; i < len(b); i++ {
			c := b[i]
			if c != '\n' {
				b[i] = ' '
			}
			if c == '\\' && i+1 < len(b) {
				i++
				b[i] = ' '
				continue
			}
			if c == q {
				break
			}
		}
	}
	return string(b)
}
func metadata(r *Inspection, s sourceText) {
	// Device identity is accepted only from project metadata, never C comments,
	// filenames or copied vendor headers mentioning a reference device.
	patterns := []struct{ path, key, pattern string }{
		{".cproject", "compiler_option", `<option\b[^>]*(?:FLOAT_SUPPORT|CLA_SUPPORT|OPT_LEVEL|SILICON_VERSION|ABI)[^>]*>`},
		{".ccsproject", "device", `<deviceVariant\s+value="([^"]+)"`},
		{".ccsproject", "compiler", `<codegenToolVersion\s+value="([^"]+)"`},
		{".syscfg", "device", `@cliArgs[^\r\n]*?--device\s+"([^"]+)"`},
		{".syscfg", "core", `@cliArgs[^\r\n]*?--context\s+"([^"]+)"`},
		{".cproject", "build_option", `(?:value|name)="([^"\n]*(?:--float_support|--cla_support|--opt_level|C2000|Cortex|RZ/T)[^"\n]*)"`},
	}
	for _, p := range patterns {
		if !strings.HasSuffix(s.path, p.path) {
			continue
		}
		re := regexp.MustCompile(p.pattern)
		for _, m := range re.FindAllStringSubmatchIndex(s.raw, -1) {
			start, end := m[0], m[1]
			if len(m) >= 4 {
				start, end = m[2], m[3]
			}
			f := SourceFact{"project_metadata", p.key, []Argument{{Expression: s.raw[start:end], Status: "CONFIRMED_SOURCE_ONLY"}}, loc(s, m[0]), "CONFIRMED_SOURCE_ONLY", "selected input; build configuration/scope must be resolved"}
			if p.key == "device" {
				r.TargetCandidates = append(r.TargetCandidates, f)
			} else {
				r.Facts = append(r.Facts, f)
			}
		}
	}
}

type number struct {
	value   float64
	integer bool
}

func argument(s string, constants map[string][]string) Argument {
	a := Argument{Expression: strings.TrimSpace(s), Status: "UNKNOWN"}
	if v, ok := evaluate(a.Expression, constants, map[string]bool{}, 0); ok {
		a.Value = &v.value
		a.Status = "DERIVED_EXPRESSION_ONLY"
	}
	return a
}
func evaluate(s string, constants map[string][]string, seen map[string]bool, depth int) (number, bool) {
	if depth > 64 {
		return number{}, false
	}
	s = hexSuffixPattern.ReplaceAllString(strings.TrimSpace(s), "$1")
	s = suffixPattern.ReplaceAllString(s, "$1")
	expr, err := parser.ParseExpr(s)
	if err != nil {
		return number{}, false
	}
	var eval func(ast.Expr) (number, bool)
	eval = func(e ast.Expr) (number, bool) {
		switch n := e.(type) {
		case *ast.ParenExpr:
			return eval(n.X)
		case *ast.BasicLit:
			if n.Kind == token.INT {
				v, err := strconv.ParseInt(n.Value, 0, 64)
				if err == nil && math.Abs(float64(v)) <= 1<<53 {
					return number{float64(v), true}, true
				}
			}
			if n.Kind == token.FLOAT {
				v, err := strconv.ParseFloat(n.Value, 64)
				return number{v, false}, err == nil && finite(v)
			}
		case *ast.Ident:
			values := constants[n.Name]
			if len(values) == 0 || seen[n.Name] {
				return number{}, false
			}
			for _, v := range values {
				if v != values[0] {
					return number{}, false
				}
			}
			seen[n.Name] = true
			v, ok := evaluate(values[0], constants, seen, depth+1)
			delete(seen, n.Name)
			return v, ok
		case *ast.UnaryExpr:
			v, ok := eval(n.X)
			if !ok {
				return v, false
			}
			if n.Op == token.SUB {
				v.value = -v.value
				return v, true
			}
			if n.Op == token.ADD {
				return v, true
			}
		case *ast.BinaryExpr:
			x, ok := eval(n.X)
			if !ok {
				return x, false
			}
			y, ok := eval(n.Y)
			if !ok {
				return y, false
			}
			v := number{integer: x.integer && y.integer}
			switch n.Op {
			case token.ADD:
				v.value = x.value + y.value
			case token.SUB:
				v.value = x.value - y.value
			case token.MUL:
				v.value = x.value * y.value
			case token.QUO:
				if y.value == 0 {
					return v, false
				}
				v.value = x.value / y.value
				if v.integer {
					v.value = math.Trunc(v.value)
				}
			case token.SHL, token.SHR:
				if !v.integer || y.value < 0 || y.value > 52 {
					return v, false
				}
				if n.Op == token.SHL {
					v.value = float64(int64(x.value) << uint(y.value))
				} else {
					v.value = float64(int64(x.value) >> uint(y.value))
				}
			default:
				return v, false
			}
			return v, finite(v.value) && (!v.integer || math.Abs(v.value) <= 1<<53)
		}
		return number{}, false
	}
	return eval(expr)
}
func sortDiagnostics(d []Diagnostic) {
	sort.SliceStable(d, func(i, j int) bool {
		if d[i].Code == d[j].Code {
			return d[i].Message < d[j].Message
		}
		return d[i].Code < d[j].Code
	})
}
