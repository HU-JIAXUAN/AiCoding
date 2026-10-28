package ckit

import (
	"path/filepath"
	"regexp"
	"strings"
)

var plainSectionRE = regexp.MustCompile(`^(用途|职责边界|输入|输出|返回|约束)[：:]\s*(.*)$`)

func plainCommentSections(comment string) map[string]string {
	sections := map[string]string{}
	current := ""
	for _, line := range strings.Split(comment, "\n") {
		line = strings.TrimSpace(line)
		line = strings.TrimSpace(strings.TrimPrefix(line, "/*"))
		line = strings.TrimSpace(strings.TrimSuffix(line, "*/"))
		line = strings.TrimSpace(strings.TrimPrefix(line, "*"))
		if match := plainSectionRE.FindStringSubmatch(line); match != nil {
			current = match[1]
			sections[current] = strings.TrimSpace(sections[current] + " " + match[2])
		} else if current != "" && line != "" {
			sections[current] += " " + line
		}
	}
	return sections
}

// These opt-in checks establish presence and identifier coverage only. They do
// not prove units, direction, failure guarantees, context safety, or prose truth.
func validatePlainFileContract(path, comment string, cfg Config) []Diagnostic {
	if !cfg.Docs.RequireFileSections {
		return nil
	}
	sections := plainCommentSections(comment)
	var diagnostics []Diagnostic
	for _, item := range []struct{ section, rule string }{
		{"用途", "documentation.file-purpose"},
		{"职责边界", "documentation.file-boundary"},
	} {
		if strings.TrimSpace(sections[item.section]) == "" {
			diagnostics = append(diagnostics, diag(path, 1, item.rule, "文件头缺少非空的“"+item.section+"”说明。"))
		}
	}
	return diagnostics
}

func validatePlainInterfaceContract(path string, lines []string, index int, fn functionInfo, cfg Config) []Diagnostic {
	if !cfg.Docs.RequireInterfaceSections || fn.Static || !fn.Prototype || !strings.EqualFold(filepath.Ext(path), ".h") {
		return nil
	}
	returnsValue := strings.TrimSpace(fn.ReturnType) != "void" &&
		!(strings.HasSuffix(strings.TrimSpace(fn.ReturnType), " void") && !strings.Contains(fn.ReturnType, "*"))
	if len(fn.Parameters) == 0 && !returnsValue {
		return nil
	}
	sections := plainCommentSections(precedingComment(lines, index))
	var diagnostics []Diagnostic
	if len(fn.Parameters) > 0 {
		if strings.TrimSpace(sections["输入"]) == "" {
			diagnostics = append(diagnostics, diag(path, fn.Line, "documentation.interface-input", "有参公共接口缺少非空“输入”说明。"))
		}
		for _, parameter := range fn.Parameters {
			if !regexp.MustCompile(`\b` + regexp.QuoteMeta(parameter) + `\b`).MatchString(sections["输入"] + " " + sections["输出"]) {
				diagnostics = append(diagnostics, diag(path, fn.Line, "documentation.interface-parameter", "输入/输出说明未提及参数 "+parameter+"。"))
			}
		}
	}
	if returnsValue && strings.TrimSpace(sections["返回"]) == "" {
		diagnostics = append(diagnostics, diag(path, fn.Line, "documentation.interface-return", "非 void 公共接口缺少非空“返回”说明。"))
	}
	if strings.TrimSpace(sections["约束"]) == "" {
		diagnostics = append(diagnostics, diag(path, fn.Line, "documentation.interface-context", "公共接口缺少非空“约束”说明；按事实说明上下文、阻塞或资源寿命。"))
	}
	return diagnostics
}
