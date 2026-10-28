package ckit

import (
	"strings"
	"testing"
)

func TestPortablePublicInterfaceContractUsesOrdinaryChineseComments(t *testing.T) {
	cfg := portableLintConfig(t)
	source := `#ifndef MODULE_H
#define MODULE_H
/* 读取已有电流结果
输入：channelId 通道号，范围0~2；currentA 不得为空
输出：currentA 单位A，仅成功时有效，失败不修改
返回：true 成功，false 参数或数据无效
约束：任务上下文，非阻塞；调用期间 currentA 指向有效存储
*/
bool mod_read(uint8_t channelId, float *currentA);
#endif
`
	if diagnostics := lintContent("module.h", []byte(source), nil, cfg, false); len(diagnostics) != 0 {
		t.Fatalf("ordinary interface contract was rejected: %+v", diagnostics)
	}
	tests := []struct{ line, rule string }{
		{"输入：channelId 通道号，范围0~2；currentA 不得为空\n", "documentation.interface-input"},
		{"返回：true 成功，false 参数或数据无效\n", "documentation.interface-return"},
		{"约束：任务上下文，非阻塞；调用期间 currentA 指向有效存储\n", "documentation.interface-context"},
	}
	for _, test := range tests {
		t.Run(test.rule, func(t *testing.T) {
			changed := strings.Replace(source, test.line, "", 1)
			if diagnostics := lintContent("module.h", []byte(changed), nil, cfg, false); !hasRule(diagnostics, test.rule) {
				t.Fatalf("missing contract field was not reported: %+v", diagnostics)
			}
		})
	}
	changed := strings.Replace(source, "channelId 通道号", "通道号", 1)
	if diagnostics := lintContent("module.h", []byte(changed), nil, cfg, false); !hasRule(diagnostics, "documentation.interface-parameter") {
		t.Fatalf("parameter name coverage was not checked: %+v", diagnostics)
	}
	legacy := focusedLintConfig(t)
	legacy.Docs.RequireInterfaceSections = false
	if diagnostics := lintContent("module.h", []byte(strings.Replace(source, "mod_read", "DEMO_Read", 1)), nil, legacy, false); hasRule(diagnostics, "documentation.interface-input") {
		t.Fatalf("legacy profile unexpectedly adopted the opt-in contract: %+v", diagnostics)
	}
}

func TestPortableContractDoesNotInventSectionsForSimpleHelpers(t *testing.T) {
	cfg := portableLintConfig(t)
	for _, source := range []string{
		"static uint32_t helper(uint32_t value);\n",
		"void mod_reset(void);\n",
	} {
		for _, diagnostic := range lintContent("helper.h", []byte("#ifndef HELPER_H\n#define HELPER_H\n"+source+"#endif\n"), nil, cfg, false) {
			if strings.HasPrefix(diagnostic.Rule, "documentation.interface-") {
				t.Fatalf("simple helper/no-input void interface required empty contract sections: %+v", diagnostic)
			}
		}
	}
}

func TestPortableFileHeaderRequiresPurposeAndBoundary(t *testing.T) {
	cfg := portableLintConfig(t)
	cfg.Docs.FileHeader = true
	for _, source := range []string{
		"/* 用途：保存采样结果\n职责边界：只保存并读取结果，不启动 ADC 或修改 PWM\n*/\n",
		"/*\n用途：保存采样结果\n职责边界：只保存并读取结果，不启动 ADC 或修改 PWM\n*/\n",
	} {
		if diagnostics := lintContent("module.c", []byte(source), nil, cfg, false); len(diagnostics) != 0 {
			t.Fatalf("ordinary file header rejected: %+v", diagnostics)
		}
	}
	if diagnostics := lintContent("module.c", []byte("/* 保存采样结果 */\n"), nil, cfg, false); !hasRule(diagnostics, "documentation.file-purpose") || !hasRule(diagnostics, "documentation.file-boundary") {
		t.Fatalf("missing file contracts were not reported: %+v", diagnostics)
	}
}
