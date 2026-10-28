package ckit

import (
	"fmt"
	"regexp"
	"strings"
)

var namingTokenRE = regexp.MustCompile(`\$\{([^}]+)\}`)
var namingIdentifierRE = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9_]*$`)
var namingLiteralRE = regexp.MustCompile(`^[A-Za-z0-9_]*$`)
var declarationNameRE = regexp.MustCompile(`^\s*(?:(?:static|extern|const|volatile|register)\s+)*(?:(?:signed|unsigned|long|short)\s+)*(?:(?:struct|union|enum)\s+)?[A-Za-z_][A-Za-z0-9_]*\s+\**\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:[;=:\[,])`)
var functionPointerNameRE = regexp.MustCompile(`\(\s*\*\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)`)
var simpleTypedefNameRE = regexp.MustCompile(`^\s*typedef\s+[^(){};]+[\s*]([A-Za-z_][A-Za-z0-9_]*)\s*;`)

// Naming patterns are a small identifier vocabulary, never executable regular expressions.
var namingTokenPatterns = map[string]string{
	"snake_case":       `[a-z][a-z0-9_]*`,
	"lower_snake_case": `[a-z][a-z0-9_]*`,
	"lowerCamelCase":   `[a-z][A-Za-z0-9]*`,
	"PascalCase":       `[A-Z][A-Za-z0-9]*`,
	"UPPER_SNAKE_CASE": `[A-Z][A-Z0-9_]*`,
}

func compileNamingPattern(pattern, module string) (*regexp.Regexp, error) {
	if !namingIdentifierRE.MatchString(module) {
		return nil, fmt.Errorf("naming modulePrefix must be a C identifier")
	}
	var expression strings.Builder
	expression.WriteByte('^')
	position := 0
	styles := 0
	for _, match := range namingTokenRE.FindAllStringSubmatchIndex(pattern, -1) {
		literal := pattern[position:match[0]]
		if !namingLiteralRE.MatchString(literal) {
			return nil, fmt.Errorf("invalid naming pattern %q", pattern)
		}
		expression.WriteString(regexp.QuoteMeta(literal))
		token := pattern[match[2]:match[3]]
		if token == "MODULE" {
			expression.WriteString(regexp.QuoteMeta(module))
		} else if rule, exists := namingTokenPatterns[token]; exists {
			expression.WriteString(rule)
			styles++
		} else {
			return nil, fmt.Errorf("unsupported naming token %q", token)
		}
		position = match[1]
	}
	literal := pattern[position:]
	if styles != 1 || !namingLiteralRE.MatchString(literal) {
		return nil, fmt.Errorf("naming pattern %q must contain one identifier style token", pattern)
	}
	expression.WriteString(regexp.QuoteMeta(literal))
	expression.WriteByte('$')
	return regexp.Compile(expression.String())
}

func validateNaming(naming Naming) error {
	fields := []struct{ name, pattern string }{
		{"publicFunction", naming.PublicFunction}, {"privateFunction", naming.PrivateFunction},
		{"type", naming.Type}, {"functionPointer", naming.FunctionPointer},
		{"macro", naming.Macro}, {"enumConstant", naming.EnumConstant},
		{"globalVariable", naming.GlobalVariable}, {"staticVariable", naming.StaticVariable},
		{"localVariable", naming.LocalVariable}, {"parameter", naming.Parameter},
		{"structMember", naming.StructMember},
	}
	for _, field := range fields {
		if _, err := compileNamingPattern(field.pattern, naming.ModulePrefix); err != nil {
			return fmt.Errorf("naming.%s: %w", field.name, err)
		}
	}
	return nil
}

func matchesNaming(name, pattern string, naming Naming) bool {
	rule, err := compileNamingPattern(pattern, naming.ModulePrefix)
	return err == nil && rule.MatchString(name)
}

func namingDiagnostic(path string, line int, rule, name, pattern string) Diagnostic {
	return diag(path, line, rule, fmt.Sprintf("标识符 %s 必须符合配置模式 %s。", name, pattern))
}

func complexityDiagnostic(path string, line int, rule, message string, cfg Config) Diagnostic {
	result := diag(path, line, rule, message)
	if cfg.Readability.ComplexitySeverity == "warning" {
		result.Severity = "warning"
	}
	return result
}

// Declaration checks cover recognizable declarations only; macro-expanded and
// compiler-extension forms still require the project's compiler or AST checks.
func declarationNamingDiagnostics(path string, index int, analysis sourceReadabilityAnalysis, cfg Config) []Diagnostic {
	line := analysis.cleanLines[index]
	trim := strings.TrimSpace(line)
	if strings.HasPrefix(trim, "typedef ") {
		if match := functionPointerNameRE.FindStringSubmatch(line); match != nil {
			if !matchesNaming(match[1], cfg.Naming.FunctionPointer, cfg.Naming) {
				return []Diagnostic{namingDiagnostic(path, index+1, "naming.function-pointer", match[1], cfg.Naming.FunctionPointer)}
			}
		} else if match := simpleTypedefNameRE.FindStringSubmatch(line); match != nil {
			if !matchesNaming(match[1], cfg.Naming.Type, cfg.Naming) {
				return []Diagnostic{namingDiagnostic(path, index+1, "naming.type", match[1], cfg.Naming.Type)}
			}
		}
		return nil
	}
	for _, keyword := range []string{"return", "goto", "case", "break", "continue"} {
		if trim == keyword || strings.HasPrefix(trim, keyword+" ") {
			return nil
		}
	}
	for _, function := range analysis.functions {
		if index >= function.startLine && index <= function.openLine {
			return nil
		}
	}
	for start := max(0, index-7); start <= index; start++ {
		if function, ok := parseFunctionAt(analysis.cleanLines, start); ok && function.Prototype {
			for end := start; end < len(analysis.cleanLines) && end < start+8; end++ {
				if strings.HasSuffix(strings.TrimSpace(analysis.cleanLines[end]), ";") {
					if index <= end {
						return nil
					}
					break
				}
			}
		}
	}
	match := declarationNameRE.FindStringSubmatch(line)
	if match == nil {
		return nil
	}
	pattern, rule := cfg.Naming.GlobalVariable, "naming.global-variable"
	insideFunction := false
	for _, function := range analysis.functions {
		if index > function.openLine && index < function.endLine {
			insideFunction = true
			break
		}
	}
	if insideFunction {
		pattern, rule = cfg.Naming.LocalVariable, "naming.local-variable"
	} else if analysis.lineDepth[index] > 0 {
		pattern, rule = cfg.Naming.StructMember, "naming.struct-member"
	} else if strings.HasPrefix(trim, "static ") {
		pattern, rule = cfg.Naming.StaticVariable, "naming.static-variable"
	}
	if !matchesNaming(match[1], pattern, cfg.Naming) {
		return []Diagnostic{namingDiagnostic(path, index+1, rule, match[1], pattern)}
	}
	return nil
}

func hasBlockingDiagnostics(diagnostics []Diagnostic) bool {
	for _, diagnostic := range diagnostics {
		if diagnostic.Severity != "warning" {
			return true
		}
	}
	return false
}

func limitDiagnostics(diagnostics []Diagnostic, maximum int) []Diagnostic {
	if len(diagnostics) <= maximum {
		return diagnostics
	}
	limited := append([]Diagnostic(nil), diagnostics[:maximum]...)
	if !hasBlockingDiagnostics(limited) {
		for _, diagnostic := range diagnostics[maximum:] {
			if diagnostic.Severity != "warning" {
				limited[maximum-1] = diagnostic
				break
			}
		}
	}
	return limited
}
