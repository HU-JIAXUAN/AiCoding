package ckit

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var (
	typeEndRE             = regexp.MustCompile(`}\s*([A-Za-z_][A-Za-z0-9_]*)\s*;`)
	badBaseTypeRE         = regexp.MustCompile(`\b(?:short|long|unsigned int|signed int)\b`)
	vlaRE                 = regexp.MustCompile(`^\s*(?:const\s+)?(?:bool|u?int(?:8|16|32|64)_t|size_t|float|double|[A-Za-z_][A-Za-z0-9_]*_t)\s+[A-Za-z_][A-Za-z0-9_]*\s*\[[a-z][a-z0-9_]*\]`)
	reservedIDRE          = regexp.MustCompile(`(^|[^A-Za-z0-9_])(__[A-Za-z0-9_]*|_[A-Z][A-Za-z0-9_]*)`)
	boolCompareRE         = regexp.MustCompile(`(?:==|!=)\s*(?:true|false)\b`)
	postIncRE             = regexp.MustCompile(`\b[A-Za-z_][A-Za-z0-9_]*\+\+`)
	sizeNameRE            = regexp.MustCompile(`\b(?:int|uint32_t|int32_t)\s+([A-Za-z_][A-Za-z0-9_]*(?:len|length|size|bytes|capacity))\b`)
	lineCommentRE         = regexp.MustCompile(`(^|[^:])//`)
	macroRE               = regexp.MustCompile(`^\s*#define\s+([A-Za-z_][A-Za-z0-9_]*)(?:\(([^)]*)\))?\s+(.+)$`)
	enumItemRE            = regexp.MustCompile(`^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|,|$)`)
	globalVarRE           = regexp.MustCompile(`^(static\s+)?(?:const\s+)?(?:bool|char|int|u?int(?:8|16|32|64)_t|size_t|float|double|[A-Za-z_][A-Za-z0-9_]*_t)\s+\*?\s*([A-Za-z_][A-Za-z0-9_]*)(?:\s*\[[^]]+\])?\s*(?:=|;)`)
	fileTagRE             = regexp.MustCompile(`(?m)^\s*\*\s*@file\s+\S`)
	fileBriefRE           = regexp.MustCompile(`(?m)^\s*\*\s*@brief\s+\S`)
	employeeIDRE          = regexp.MustCompile(`(?m)^\s*\*\s*@employee_id(?:\s+(.*\S))?\s*$`)
	employeePlaceholderRE = regexp.MustCompile(`(?i)not applicable|\bn/?a\b|不适用|未提供|无工号`)
	modificationHistoryRE = regexp.MustCompile(`(?mi)^\s*\*\s*(?:@(?:history|modification)\b|history\s*:|modification(?:\s+history)?\s*:|change\s+history\s*:|修改(?:记录|历史)\s*[：:])`)
	oneLineBlockCommentRE = regexp.MustCompile(`^\s*/\*\s+\S(?:.*\S)?\s+\*/\s*$`)
	gotoRE                = regexp.MustCompile(`\bgoto\b`)
)

func RunLint(args []string) error {
	fs := flag.NewFlagSet("lint", flag.ContinueOnError)
	configPath := fs.String("config", "", "configuration")
	scope := fs.String("scope", "staged", "staged|files")
	jsonOut := fs.Bool("json", false, "JSON output")
	summaryOut := fs.Bool("summary", false, "include readability summary")
	var files multiFlag
	var overlays multiFlag
	fs.Var(&files, "file", "file to check")
	fs.Var(&overlays, "overlay", "partial configuration overlay; may be repeated")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *configPath == "" {
		return fmt.Errorf("--config is required")
	}
	cfg, _, err := loadLintConfigWithOverlays(*configPath, overlays)
	if err != nil {
		return err
	}

	all := make([]Diagnostic, 0)
	summaries := make([]FileReadabilitySummary, 0)
	switch *scope {
	case "staged":
		changed, err := stagedChangedLines()
		if err != nil {
			return err
		}
		if len(changed) == 0 && cfg.Hook.NoCChangeFastExit {
			return emitResult(*jsonOut, nil, nil, *summaryOut)
		}
		for path, ranges := range changed {
			if isExcluded(path, cfg) {
				continue
			}
			data, err := stagedContent(path)
			if err != nil {
				return err
			}
			diagnostics, summary := lintContentWithSummary(path, data, ranges, cfg, cfg.Style.ChangedLinesOnly)
			all = append(all, diagnostics...)
			if *summaryOut {
				summaries = append(summaries, summary)
			}
		}
	case "files":
		for _, path := range files {
			if isExcluded(path, cfg) {
				continue
			}
			data, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			diagnostics, summary := lintContentWithSummary(path, data, nil, cfg, false)
			all = append(all, diagnostics...)
			if *summaryOut {
				summaries = append(summaries, summary)
			}
		}
	default:
		return fmt.Errorf("unsupported scope %q", *scope)
	}
	all = limitDiagnostics(all, cfg.Hook.MaxDiagnostics)
	sort.SliceStable(summaries, func(i, j int) bool { return summaries[i].File < summaries[j].File })
	if err := emitResult(*jsonOut, all, summaries, *summaryOut); err != nil {
		return err
	}
	if hasBlockingDiagnostics(all) {
		return fmt.Errorf("C Kit gate failed with %d diagnostic(s)", len(all))
	}
	return nil
}

type multiFlag []string

func (m *multiFlag) String() string     { return strings.Join(*m, ",") }
func (m *multiFlag) Set(s string) error { *m = append(*m, s); return nil }

func emitResult(jsonOut bool, ds []Diagnostic, summaries []FileReadabilitySummary, includeSummary bool) error {
	if jsonOut {
		result := map[string]any{"ok": !hasBlockingDiagnostics(ds), "diagnostics": ds}
		if includeSummary {
			result["readability"] = map[string]any{"files": summaries}
		}
		return json.NewEncoder(os.Stdout).Encode(result)
	}
	for _, d := range ds {
		fmt.Printf("%s:%d: %s [%s] %s\n", d.File, d.Line, d.Severity, d.Rule, d.Message)
	}
	if len(ds) == 0 {
		fmt.Println("C Kit gate passed")
	}
	if includeSummary {
		for _, summary := range summaries {
			for _, function := range summary.Functions {
				fmt.Printf("readability %s:%d %s loc=%d branches=%d nesting=%d fanout=%d single-call-helper=%v\n",
					summary.File, function.Line, function.Name, function.EffectiveLines,
					function.BranchCount, function.MaxNesting, function.FanOut,
					function.SingleCallStaticHelper)
			}
			for _, review := range summary.ManualReview {
				fmt.Printf("review %s:%d [%s] %s\n", review.File, review.Line, review.Rule, review.Message)
			}
		}
	}
	return nil
}

func lintContent(path string, data []byte, ranges []LineRange, cfg Config, changedOnly bool) []Diagnostic {
	diagnostics, _ := lintContentWithSummary(path, data, ranges, cfg, changedOnly)
	return diagnostics
}

func lintContentWithSummary(path string, data []byte, ranges []LineRange, cfg Config, changedOnly bool) ([]Diagnostic, FileReadabilitySummary) {
	text := strings.ReplaceAll(string(data), "\r\n", "\n")
	lines := strings.Split(text, "\n")
	var ds []Diagnostic
	analysis := analyzeSourceReadability(path, data, cfg)

	ds = append(ds, validateSingleBriefStyle(path, lines, ranges, cfg, changedOnly)...)

	if cfg.Docs.FileHeader {
		head := leadingFileHeader(lines)
		if !commentHasText(head) {
			ds = append(ds, diag(path, 1, "documentation.file", "文件头缺少有效的模块说明。"))
		}
		ds = append(ds, validatePlainFileContract(path, head, cfg)...)
		if cfg.Docs.RequireBrief || cfg.Docs.RequireFileMetadata {
			if !fileTagRE.MatchString(head) {
				ds = append(ds, diag(path, 1, "documentation.file", "文件头缺少非空 @file。"))
			}
			if !fileBriefRE.MatchString(head) {
				ds = append(ds, diag(path, 1, "documentation.file-brief", "文件头缺少非空 @brief。"))
			}
		}
		if cfg.Docs.RequireFileMetadata {
			metadata := []struct {
				token   string
				message string
			}{
				{"@copyright", "文件头缺少版权说明。"},
				{"@date", "文件头缺少生成或修改日期。"},
				{"@author", "文件头缺少作者。"},
				{"文件内容", "文件头缺少内容说明。"},
				{"主要功能", "文件头缺少功能说明。"},
				{"文件关系", "文件头缺少与其他文件的关系说明。"},
			}
			for _, item := range metadata {
				if !strings.Contains(head, item.token) {
					ds = append(ds, diag(path, 1, "documentation.file-metadata", item.message))
				}
			}
		}
		ds = append(ds, validateFileMetadataPolicies(path, head, cfg)...)
	}
	if filepath.Ext(path) == ".h" {
		if !strings.Contains(text, "#ifndef ") || !strings.Contains(text, "#define ") {
			ds = append(ds, diag(path, 1, "file.include-guard", "头文件缺少 include guard。"))
		}
		if cfg.Docs.RequireExternC && (!strings.Contains(text, `extern "C"`) || !strings.Contains(text, "__cplusplus")) {
			ds = append(ds, diag(path, 1, "file.extern-c", "头文件缺少 C++ extern C 兼容保护。"))
		}
	}
	if cfg.Style.RequireEOFNewline && len(data) > 0 && data[len(data)-1] != '\n' {
		ds = append(ds, diag(path, len(lines), "format.eof-newline", "文件末尾缺少换行。"))
	}

	inEnum := false
	for i, line := range lines {
		lineNo := i + 1
		trim := strings.TrimSpace(line)
		selected := !changedOnly || lineSelected(lineNo, ranges)

		if fn, ok := parseFunctionAt(lines, i); ok {
			functionSelected := selected
			functionSummary, analyzed, hasAnalysis := analysis.functionAtStart(i)
			if !fn.Prototype && hasAnalysis && changedOnly {
				functionSelected = spanSelected(analyzed.startLine+1, analyzed.endLine+1, ranges)
			}
			if functionSelected {
				pattern := cfg.Naming.PublicFunction
				if fn.Static {
					pattern = cfg.Naming.PrivateFunction
				}
				if fn.Name != "main" && !matchesNaming(fn.Name, pattern, cfg.Naming) {
					rule := "naming.public-function"
					if fn.Static {
						rule = "naming.private-function"
					}
					ds = append(ds, namingDiagnostic(path, lineNo, rule, fn.Name, pattern))
				}
				for _, parameter := range fn.Parameters {
					if !matchesNaming(parameter, cfg.Naming.Parameter, cfg.Naming) {
						ds = append(ds, namingDiagnostic(path, lineNo, "naming.parameter", parameter, cfg.Naming.Parameter))
					}
				}
				ds = append(ds, validateFunctionDocs(path, lines, i, fn, cfg)...)
				ds = append(ds, validatePlainInterfaceContract(path, lines, i, fn, cfg)...)
				if cfg.Safety.RequireExplicitVoid && strings.Contains(line, "()") {
					ds = append(ds, diag(path, lineNo, "c99.explicit-void", "无参数函数必须显式使用 (void)。"))
				}
				if len(fn.Parameters) > cfg.Safety.MaxParameters {
					ds = append(ds, complexityDiagnostic(path, lineNo, "complexity.parameters", "函数参数数量超过配置上限。", cfg))
				}
				if !fn.Prototype {
					if hasAnalysis && functionSummary.EffectiveLines > 50 {
						ds = append(ds, complexityDiagnostic(path, lineNo, "complexity.function-lines",
							"新增函数有效代码超过 50 行。", cfg))
					}
					if hasAnalysis && functionSummary.MaxNesting > 4 {
						ds = append(ds, complexityDiagnostic(path, lineNo, "complexity.nesting",
							"函数代码块嵌套超过 4 层。", cfg))
					}
				}
			}
		}

		if strings.Contains(trim, "typedef enum") || trim == "enum" || strings.HasPrefix(trim, "enum ") {
			inEnum = true
		} else if inEnum && strings.Contains(trim, "}") {
			inEnum = false
		} else if inEnum && selected {
			if m := enumItemRE.FindStringSubmatch(trim); m != nil && !matchesNaming(m[1], cfg.Naming.EnumConstant, cfg.Naming) {
				ds = append(ds, namingDiagnostic(path, lineNo, "naming.enum-constant", m[1], cfg.Naming.EnumConstant))
			}
		}

		if cfg.Flow.RequireSwitchDefault && selected && isSwitchStatement(trim) &&
			!switchHasDefault(lines, i) {
			ds = append(ds, diag(path, lineNo, "control.switch-default", "switch 缺少 default 分支。"))
		}
		if selected && isCaseLabel(trim) {
			caseInfo := inspectCaseBranch(analysis, i)
			if cfg.Docs.RequireCaseIntentComment && caseInfo.handled && !caseInfo.hasIntent {
				ds = append(ds, diag(path, lineNo, "comment.case-intent",
					"有处理语句的 case/default 必须在首条处理语句前说明意图；连续空标签无需重复注释。"))
			}
			if cfg.Flow.RequireCaseBreak && caseInfo.willFallThrough && !caseInfo.hasFallthroughIntent {
				ds = append(ds, diag(path, lineNo, "comment.case-fallthrough",
					"case 处理后继续进入下一分支时必须明确说明贯穿原因。"))
			}
		}
		if selected && cfg.Docs.RequireGlobalVariableDetail {
			if match := globalVarRE.FindStringSubmatch(line); match != nil {
				ds = append(ds, validateGlobalVariable(path, lines, i)...)
			}
		}

		if !selected {
			continue
		}
		if len([]rune(line)) > cfg.Style.ColumnLimit {
			ds = append(ds, diag(path, lineNo, "format.line-length", "行宽超过配置上限。"))
		}
		if strings.HasSuffix(line, " ") || strings.HasSuffix(line, "\t") {
			ds = append(ds, diag(path, lineNo, "format.trailing-space", "存在行尾空白。"))
		}
		if cfg.Style.ForbidLineComment && lineCommentRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "comment.line-style", "禁止使用 // 注释，使用块注释。"))
		}
		if cfg.Flow.RequireCompoundBraces && isControlStatement(trim) && !hasOpeningBrace(lines, i) {
			ds = append(ds, diag(path, lineNo, "control.compound-braces", "复合语句必须使用花括号。"))
		}
		if cfg.Safety.ForbidDynamicAllocation && containsCall(line, "malloc", "calloc", "realloc", "free") {
			ds = append(ds, diag(path, lineNo, "embedded.dynamic-allocation", "禁止动态内存分配。"))
		}
		if cfg.Safety.ForbidVLA && !strings.HasPrefix(trim, "*") && vlaRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "c99.vla", "禁止变长数组。"))
		}
		if cfg.Safety.RequireStdintTypes && badBaseTypeRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "c99.fixed-width-types", "接口和持久数据应使用固定宽度类型。"))
		}
		if cfg.Naming.ForbidReservedID && !strings.HasPrefix(trim, "#") && reservedIDRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "naming.reserved", "禁止使用语言保留标识符形式。"))
		}
		if cfg.Safety.ForbidBooleanComparison && boolCompareRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "boolean.literal-comparison", "布尔结果不应显式与 true/false 比较。"))
		}
		if cfg.Safety.PreferPreIncrement && postIncRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "operator.pre-increment", "无旧值依赖时使用前置递增。"))
		}
		if cfg.Safety.RequireSizeT && sizeNameRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "type.size-t", "长度、容量和字节数变量应使用 size_t。"))
		}
		if cfg.Safety.ForbidUnboundedLoop &&
			(strings.Contains(trim, "while (true)") || strings.Contains(trim, "while(1)") || strings.Contains(trim, "for (;;)")) {
			ds = append(ds, diag(path, lineNo, "control.unbounded-loop", "禁止无界循环。"))
		}
		if cfg.Safety.ForbidGoto && gotoRE.MatchString(line) {
			ds = append(ds, diag(path, lineNo, "control.goto", "当前配置禁止 goto。"))
		}
		for _, call := range cfg.Safety.ForbiddenCalls {
			if containsCall(line, call) {
				ds = append(ds, diag(path, lineNo, "embedded.forbidden-call", "禁止调用 "+call+"。"))
			}
		}
		ds = append(ds, declarationNamingDiagnostics(path, i, analysis, cfg)...)
		if m := typeEndRE.FindStringSubmatch(line); m != nil && !matchesNaming(m[1], cfg.Naming.Type, cfg.Naming) {
			ds = append(ds, namingDiagnostic(path, lineNo, "naming.type", m[1], cfg.Naming.Type))
		}
		if m := macroRE.FindStringSubmatch(line); m != nil {
			ds = append(ds, validateMacro(path, lineNo, m[1], m[2], m[3], lines, i, cfg)...)
		}
	}
	ds = append(ds, readabilityDiagnostics(path, analysis, ranges, cfg, changedOnly)...)
	return ds, analysis.summary
}

func isControlStatement(trim string) bool {
	return strings.HasPrefix(trim, "if (") || strings.HasPrefix(trim, "if(") ||
		strings.HasPrefix(trim, "else if (") || strings.HasPrefix(trim, "else if(") ||
		strings.HasPrefix(trim, "for (") || strings.HasPrefix(trim, "for(") ||
		strings.HasPrefix(trim, "while (") || strings.HasPrefix(trim, "while(") ||
		trim == "else" || strings.HasPrefix(trim, "switch (") || strings.HasPrefix(trim, "switch(")
}

func isSwitchStatement(trim string) bool {
	return strings.HasPrefix(trim, "switch (") || strings.HasPrefix(trim, "switch(")
}

func isCaseLabel(trim string) bool {
	return strings.HasPrefix(trim, "case ") || strings.HasPrefix(trim, "default:")
}

func caseHasIntentComment(lines []string, index int) bool {
	if strings.Contains(lines[index], "/*") {
		return true
	}
	for i := index + 1; i < len(lines); i++ {
		trim := strings.TrimSpace(lines[i])
		if trim == "" {
			continue
		}
		return strings.HasPrefix(trim, "/*")
	}
	return false
}

func switchHasDefault(lines []string, index int) bool {
	depth := 0
	started := false
	for i := index; i < len(lines); i++ {
		line := lines[i]
		trim := strings.TrimSpace(line)
		if started && depth == 1 && strings.HasPrefix(trim, "default:") {
			return true
		}
		for _, character := range line {
			switch character {
			case '{':
				depth++
				started = true
			case '}':
				depth--
				if started && depth == 0 {
					return false
				}
			}
		}
	}
	return false
}

func functionBodyMetrics(lines []string, index int) (int, int) {
	depth := 0
	maxNesting := 0
	effectiveLines := 0
	started := false
	inComment := false

	for i := index; i < len(lines); i++ {
		code := stripBlockComments(lines[i], &inComment)
		trim := strings.TrimSpace(code)
		if trim == "" {
			continue
		}
		if started && trim != "{" && trim != "}" {
			effectiveLines++
		}
		for _, character := range code {
			switch character {
			case '{':
				depth++
				started = true
				if depth-1 > maxNesting {
					maxNesting = depth - 1
				}
			case '}':
				depth--
				if started && depth == 0 {
					return effectiveLines, maxNesting
				}
			}
		}
	}
	return effectiveLines, maxNesting
}

func stripBlockComments(line string, inComment *bool) string {
	var builder strings.Builder
	for index := 0; index < len(line); {
		if *inComment {
			end := strings.Index(line[index:], "*/")
			if end < 0 {
				return builder.String()
			}
			index += end + 2
			*inComment = false
			continue
		}
		start := strings.Index(line[index:], "/*")
		if start < 0 {
			builder.WriteString(line[index:])
			break
		}
		builder.WriteString(line[index : index+start])
		index += start + 2
		*inComment = true
	}
	return builder.String()
}

func hasOpeningBrace(lines []string, index int) bool {
	if strings.HasSuffix(strings.TrimSpace(lines[index]), "{") {
		return true
	}
	for i := index + 1; i < len(lines); i++ {
		trim := strings.TrimSpace(lines[i])
		if trim == "" {
			continue
		}
		if trim == "{" || strings.HasSuffix(trim, "{") {
			return true
		}
		if strings.HasSuffix(trim, ";") {
			return false
		}
	}
	return false
}

func leadingFileHeader(lines []string) string {
	start := 0
	for start < len(lines) && strings.TrimSpace(strings.TrimPrefix(lines[start], "\ufeff")) == "" {
		start++
	}
	if start >= len(lines) || !strings.HasPrefix(strings.TrimSpace(strings.TrimPrefix(lines[start], "\ufeff")), "/*") {
		return ""
	}
	for end := start; end < len(lines); end++ {
		if strings.Contains(lines[end], "*/") {
			return strings.Join(lines[start:end+1], "\n")
		}
	}
	return strings.Join(lines[start:], "\n")
}

func validateFileMetadataPolicies(path, head string, cfg Config) []Diagnostic {
	var diagnostics []Diagnostic
	employeeMatch := employeeIDRE.FindStringSubmatch(head)
	hasEmployeeID := employeeMatch != nil
	employeeValue := ""
	if len(employeeMatch) > 1 {
		employeeValue = strings.TrimSpace(employeeMatch[1])
	}
	placeholderEmployeeID := hasEmployeeID &&
		(employeeValue == "" || employeePlaceholderRE.MatchString(employeeValue))

	switch cfg.Docs.EmployeeIDPolicy {
	case "omit":
		if hasEmployeeID {
			diagnostics = append(diagnostics, diag(path, 1, "documentation.employee-id.forbidden",
				"employeeIdPolicy=omit 时文件头不得显示 @employee_id。"))
		}
	case "whenProvided":
		if placeholderEmployeeID {
			diagnostics = append(diagnostics, diag(path, 1, "documentation.employee-id.placeholder",
				"未提供工号时应省略 @employee_id，不得写不适用或占位说明。"))
		}
	case "required":
		if !hasEmployeeID {
			diagnostics = append(diagnostics, diag(path, 1, "documentation.employee-id.missing",
				"employeeIdPolicy=required 时文件头必须提供 @employee_id。"))
		} else if placeholderEmployeeID {
			diagnostics = append(diagnostics, diag(path, 1, "documentation.employee-id.placeholder",
				"@employee_id 必须是实际工号，不得使用占位说明。"))
		}
	}

	hasModificationHistory := modificationHistoryRE.MatchString(head)
	switch cfg.Docs.ModificationHistoryPolicy {
	case "disabled":
		if hasModificationHistory {
			diagnostics = append(diagnostics, diag(path, 1,
				"documentation.modification-history.forbidden",
				"源码修改记录应由 Git/CHANGELOG 管理；disabled 模式禁止在文件头记录。"))
		}
	case "required":
		if !hasModificationHistory {
			diagnostics = append(diagnostics, diag(path, 1,
				"documentation.modification-history.missing",
				"modificationHistoryPolicy=required 时文件头必须提供修改记录。"))
		}
	}
	return diagnostics
}

func validateMacro(path string, line int, name, params, body string, lines []string, index int, cfg Config) []Diagnostic {
	var ds []Diagnostic
	if cfg.Macro.RequireUppercase && !matchesNaming(name, cfg.Naming.Macro, cfg.Naming) {
		ds = append(ds, namingDiagnostic(path, line, "macro.name", name, cfg.Naming.Macro))
	}
	if cfg.Macro.RequireDocumentation {
		doxygen := commentHasText(precedingDoxygen(lines, index))
		block := precedingOneLineBlockComment(lines, index)
		trailing := trailingCommentHasText(lines[index])
		if isSimpleObjectMacro(lines[index], name) {
			validComment := false
			switch cfg.Macro.SimpleObjectCommentStyle {
			case "trailing":
				validComment = trailing
			case "block":
				validComment = block
			case "doxygen":
				validComment = doxygen
			case "either":
				validComment = trailing || block || doxygen
			}
			if !validComment {
				ds = append(ds, diag(path, line, "documentation.simple-macro-comment",
					"简单对象宏必须使用配置指定的单行说明；trailing 模式在定义同行右侧使用 /* 中文说明 */。"))
			}
		} else if !commentHasText(precedingComment(lines, index)) ||
			(cfg.Macro.SimpleObjectCommentStyle == "doxygen" && !doxygen) {
			ds = append(ds, diag(path, line, "documentation.macro", "复杂或函数式宏定义前缺少有效说明。"))
		}
	}
	if params != "" && cfg.Macro.ProtectParameters {
		for _, p := range strings.Split(params, ",") {
			p = strings.TrimSpace(p)
			if p != "" && strings.Contains(body, p) && !strings.Contains(body, "("+p+")") {
				ds = append(ds, diag(path, line, "macro.parameter-parentheses", "宏参数 "+p+" 必须使用括号保护。"))
			}
		}
	}
	if params != "" && cfg.Macro.ProtectFinalExpression {
		b := strings.TrimSpace(body)
		if !(strings.HasPrefix(b, "((") && strings.HasSuffix(b, "))")) && !strings.HasPrefix(b, "do {") {
			ds = append(ds, diag(path, line, "macro.final-parentheses", "函数式宏的最终表达式必须使用外层括号保护。"))
		}
	}
	return ds
}

func isSimpleObjectMacro(line, name string) bool {
	trim := strings.TrimSpace(line)
	if !strings.HasPrefix(trim, "#define") {
		return false
	}
	remainder := strings.TrimSpace(strings.TrimPrefix(trim, "#define"))
	if !strings.HasPrefix(remainder, name) {
		return false
	}
	remainder = strings.TrimPrefix(remainder, name)
	return !strings.HasPrefix(remainder, "(") && !strings.HasSuffix(trim, "\\")
}

func precedingOneLineBlockComment(lines []string, index int) bool {
	if index <= 0 {
		return false
	}
	line := lines[index-1]
	return oneLineBlockCommentRE.MatchString(line) && !strings.HasPrefix(strings.TrimSpace(line), "/**") &&
		commentHasText(line)
}

func trailingCommentHasText(line string) bool {
	start := strings.LastIndex(line, "/*")
	if start < 0 {
		return false
	}
	block := strings.TrimSpace(line[start:])
	return strings.HasSuffix(block, "*/") && commentHasText(block)
}

func validateGlobalVariable(path string, lines []string, index int) []Diagnostic {
	var ds []Diagnostic
	block := precedingComment(lines, index)
	if !commentHasText(block) || !strings.Contains(block, "范围") ||
		(!strings.Contains(block, "只读") && !strings.Contains(block, "读写") &&
			!strings.Contains(block, "互斥") && !strings.Contains(block, "访问")) {
		ds = append(ds, diag(path, index+1, "documentation.global-variable",
			"文件作用域变量必须说明功能、取值范围、所有权和访问注意事项。"))
	}
	return ds
}

func containsCall(line string, names ...string) bool {
	for _, n := range names {
		pattern := `\b` + regexp.QuoteMeta(n) + `\s*\(`
		if regexp.MustCompile(pattern).MatchString(line) {
			return true
		}
	}
	return false
}

func diag(path string, line int, rule, msg string) Diagnostic {
	return Diagnostic{File: filepath.ToSlash(path), Line: line, Rule: rule, Severity: "error", Message: msg}
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}
