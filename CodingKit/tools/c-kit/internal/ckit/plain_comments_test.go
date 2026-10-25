package ckit

import (
	"strings"
	"testing"
)

func TestDefaultCommentsDoNotRequireDoxygenTags(t *testing.T) {
	cfg, err := LoadConfig(configPath())
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.Docs.FileHeader || !cfg.Docs.AllFunctions || !cfg.Macro.RequireDocumentation {
		t.Fatal("plain comments must retain file, function and macro documentation checks")
	}
	if cfg.Docs.RequireFileMetadata || cfg.Docs.RequireBrief || cfg.Docs.RequireParamTags ||
		cfg.Docs.RequireParamDirection || cfg.Docs.RequireReturnTag || cfg.Docs.RequireDefinitionDetails {
		t.Fatalf("default configuration still requires Doxygen tags: %+v", cfg.Docs)
	}
}

func TestPlainFunctionCommentsPass(t *testing.T) {
	cfg := focusedLintConfig(t)
	cfg.Docs.FileHeader = true
	cfg.Docs.AllFunctions = true
	source := `/*
    计算电流给定，数值单位为A
*/

/* 保持输入电流不变 */
int32_t DEMO_KeepCurrent(int32_t value)
{
    return value;
}

/*
    将输入电流增加1A
    value 输入电流，单位A
    返回增加后的电流
*/
int32_t DEMO_AddCurrent(int32_t value)
{
    return value + 1;
}
`
	if ds := lintContent("current.c", []byte(source), nil, cfg, false); len(ds) != 0 {
		t.Fatalf("ordinary comments without tags or line-leading stars must pass: %+v", ds)
	}
}

func TestFunctionCommentsNeedActualText(t *testing.T) {
	cfg := focusedLintConfig(t)
	cfg.Docs.AllFunctions = true
	for _, comment := range []string{"", "/* */", "/************/", "/* ** */", "/* 。 */", "/** @brief */"} {
		t.Run(comment, func(t *testing.T) {
			source := comment + "\nint32_t DEMO_Current(void)\n{\n    return 0;\n}\n"
			if ds := lintContent("current.c", []byte(source), nil, cfg, false); !hasRule(ds, "documentation.function") {
				t.Fatalf("missing or decorative-only comment must not count as documentation: %+v", ds)
			}
		})
	}
}

func TestPlainFileHeaderNeedsActualText(t *testing.T) {
	cfg := focusedLintConfig(t)
	cfg.Docs.FileHeader = true
	for _, comment := range []string{"/* */", "/************/", "/* ***\n***\n*/"} {
		if ds := lintContent("current.c", []byte(comment+"\n"), nil, cfg, false); !hasRule(ds, "documentation.file") {
			t.Fatalf("empty file header must be rejected: %q: %+v", comment, ds)
		}
	}
}

func TestStarSectionWithTextDoesNotRequireDoxygen(t *testing.T) {
	cfg := focusedLintConfig(t)
	cfg.Docs.AllFunctions = true
	source := `/******** 电流换算 ********/
int32_t DEMO_Current(int32_t value)
{
    return value;
}
`
	if ds := lintContent("current.c", []byte(source), nil, cfg, false); len(ds) != 0 {
		t.Fatalf("meaningful section markers must not imply Doxygen tags: %+v", ds)
	}
}

func TestPreviousDeclarationTrailingCommentDoesNotDocumentNextFunction(t *testing.T) {
	cfg := focusedLintConfig(t)
	cfg.Docs.AllFunctions = true
	lines := strings.Split("int32_t DEMO_First(void); /* 第一个函数的说明 */\nint32_t DEMO_Second(void);", "\n")
	fn := functionInfo{Name: "DEMO_Second", ReturnType: "int32_t", Prototype: true, Line: 2}
	if ds := validateFunctionDocs("api.h", lines, 1, fn, cfg); !hasRule(ds, "documentation.function") {
		t.Fatalf("a trailing comment belongs to the previous declaration: %+v", ds)
	}
}

func TestExplicitDoxygenRequirementsRemainAvailable(t *testing.T) {
	cfg := focusedLintConfig(t)
	cfg.Docs.AllFunctions = true
	cfg.Docs.RequireBrief = true
	cfg.Docs.RequireParamTags = true
	cfg.Docs.RequireReturnTag = true
	cfg.Docs.RequireDefinitionDetails = true
	source := `/*
    返回输入电流
    value 输入电流，单位A
    返回电流值
*/
int32_t DEMO_Current(int32_t value)
{
    return value;
}
`
	ds := lintContent("current.c", []byte(source), nil, cfg, false)
	for _, rule := range []string{
		"documentation.brief", "documentation.param", "documentation.return", "documentation.definition-details",
	} {
		if !hasRule(ds, rule) {
			t.Fatalf("explicit Doxygen option must still enforce %s: %+v", rule, ds)
		}
	}
}

func TestPlainMacroCommentsPassAndEmptyCommentsFail(t *testing.T) {
	cfg := focusedLintConfig(t)
	cfg.Macro.RequireDocumentation = true
	cfg.Macro.SimpleObjectCommentStyle = "trailing"
	for _, source := range []string{
		"#define DEMO_CAPACITY 8U /* 缓冲区最多保存8条命令 */\n",
		"/* 将输入值加倍 */\n#define DEMO_DOUBLE(value) ((value) + (value))\n",
	} {
		if ds := lintContent("macro.c", []byte(source), nil, cfg, false); len(ds) != 0 {
			t.Fatalf("plain macro comment must pass: %+v", ds)
		}
	}
	for _, comment := range []string{"/* */", "/******/", "/**< */"} {
		source := "#define DEMO_CAPACITY 8U " + comment + "\n"
		if ds := lintContent("macro.c", []byte(source), nil, cfg, false); !hasRule(ds, "documentation.simple-macro-comment") {
			t.Fatalf("empty macro comment must be rejected: %+v", ds)
		}
	}
}

func TestPlainGlobalVariableCommentsKeepRangeAndAccessChecks(t *testing.T) {
	lines := []string{
		"/* 当前命令数量，范围0~8，由通信任务读写 */",
		"static uint32_t s_command_count;",
	}
	if ds := validateGlobalVariable("state.c", lines, 1, true, "s_command_count"); len(ds) != 0 {
		t.Fatalf("plain variable comment with actual constraints must pass: %+v", ds)
	}
	lines[0] = "/* 当前命令数量 */"
	if ds := validateGlobalVariable("state.c", lines, 1, true, "s_command_count"); !hasRule(ds, "documentation.global-variable") {
		t.Fatalf("removing range and access constraints must still fail: %+v", ds)
	}
}

func TestPlainNumberedFlowWithoutDetailsTag(t *testing.T) {
	for _, block := range []string{
		"/*\n    1. 检查输入\n    2. 发布结果\n*/",
		"/******** 处理步骤 ********\n    1. 检查输入\n    2. 发布结果\n*************************/",
	} {
		if !hasSequentialNumberedFlow(block) {
			t.Fatalf("plain numbered flow must pass without @details: %q", block)
		}
	}
	if hasSequentialNumberedFlow("/*\n1. 检查输入\n3. 发布结果\n*/") {
		t.Fatal("plain comments must still reject a broken numbered sequence")
	}
}
