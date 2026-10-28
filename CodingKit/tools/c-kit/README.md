# C Kit

这是一个独立的嵌入式 C99 规则 Kit：把华为 C 语言编程规范的完整本地参考、简单功能 demo、
公开高级样例、139 条规则目录、VS Code 风格 snippets、lint、可读性摘要、双编译器门禁和行为测试
连成闭环。

当前版本保持为平台无关的确定性外部工具；上层 registry 与 C99 Skill binding 负责选择性集成，
本 Kit 不感知具体平台命令、产品命名空间或运行时安装位置。

## 产物

| 层 | 产物 | 作用 |
| --- | --- | --- |
| 参考 | `references/*.pdf`、规范化 `*.md` | 61 页、0—16 章的本地权威依据 |
| Agent 规则 | `AGENTS.md` | 将规范转为编码和评审时的可执行行为约束 |
| 规则目录 | `docs/RULE_CATALOG.md`、`config/rules/*.json` | 139/139 条款及非编号内容的证据映射 |
| 规则配置 | `examples/c-kit.json`、`examples/portable-c99.overlay.json`、schema | DEMO 基线、通用 C99 覆盖与机器合同 |
| 用户模板 | `examples/c-snippets.json`、schema | 可直接编辑或复制到 VS Code 的代码片段 |
| 黄金代码 | `generated-demo/` | 简单入口与公开高级规则覆盖样例 |
| 门禁 | `scripts/verify.ps1`、`scripts/verify.sh` | PDF、JSON、lint、GCC、Clang、头文件和测试 |
| 外部验证 | `ckit verify`、target schema | 对候选 C/H 执行 fast/full 主机门禁，不接入固件构建 |

生成目录按阅读难度分层：

```text
generated-demo/
├── demo.c / demo.h                       简单采样平均值与等级判定
└── advanced/
    ├── README.md                         高级样例导航
    ├── state_machine.c / state_machine.h 状态机、ISR/DMA 与临界区
    ├── protocol.c / protocol.h           不可信输入、字节序和字符串边界
    ├── fixed_pool.c / fixed_pool.h       固定资源池和代际句柄
    └── tests/advanced_test.c             行为、边界和故障注入
```

`advanced/` 对最终用户完全可见，但不再与入门 demo 平铺混在一起。

## 重点注释契约

- 四个头文件都有独立保护宏和 C++ `extern "C"`。
- 静态函数前置区只有原型，不放 Doxygen。
- 复杂函数在定义上方用编号概述主要控制流，函数体用“空行 + 段前意图注释”对应这些逻辑段。
- `CSTYLE-COMMENT-FLOW-001` 通过配置中的华为条款 ID、稳定文档锚点、lint 诊断和
  `manualReview` 提供机器检索链路；`reviewTriggerIds` 固定列出 F01—F07 七类语义复核入口，
  最低数量门禁不替代语义评审。
- 公开声明记录接口合同，定义记录实现意图；`@pre`、`@retval`、`@note`、`@warning`、`@see`
  等补充标签按实际事实选用，不为凑模板添加空标签。
- 公开声明说明性能/执行上界以及可重入、并发、互斥或中断约束。
- 非显然 `if/else` 说明领域意义和副作用；简单 guard 不为满足形式堆叠注释。
- 每个有实际处理的 `case/default` 都有中文意图注释；连续空标签例外，贯穿必须说明原因。
- 简单对象式宏、结构体成员和枚举项默认使用声明同行右侧的 `/* 中文说明 */`。
- 普通说明不使用 Doxygen 标签；项目明确使用 Doxygen 时，单个 `@brief` 可用紧凑形式，多标签保留多行。
- 未提供工号时省略 `@employee_id`；代码内修改历史默认禁用，由 Git/CHANGELOG 记录。

完整方法、示例和人工评审边界见 [C99 注释方法](docs/COMMENTING_METHOD.md)。

## 使用

生成黄金 demo：

```powershell
go run ./cmd/ckit demo --config ./examples/c-kit.json --out ./generated-demo
```

检查指定文件：

```powershell
go run ./cmd/ckit lint --config ./examples/c-kit.json --scope files `
    --file ./generated-demo/demo.c `
    --file ./generated-demo/demo.h
```

获取 Agent 文件合同：

```powershell
go run ./cmd/ckit contract --config ./examples/c-kit.json `
    --file ./generated-demo/demo.c
```

## 通用 C99 命名与项目覆盖

`examples/c-kit.json` 保留 `DEMO_PascalCase`、snake_case 变量、`_t` 类型和黄金样例的严格阈值。
检查其他项目时，先叠加 `examples/portable-c99.overlay.json`，再叠加项目已有约束：

```powershell
go run ./cmd/ckit lint --config ./examples/c-kit.json `
  --overlay ./examples/portable-c99.overlay.json `
  --overlay ./project.overlay.json --scope files `
  --file C:/project/source/module.c --file C:/project/include/module.h --json
```

项目 overlay 例如 `{"naming":{"modulePrefix":"sensor"}}`。通用覆盖选择公共函数
`${MODULE}_${snake_case}`、私有函数 `${snake_case}`、参数/局部变量/字段 `lowerCamelCase`、
类型和函数指针 typedef `PascalCase`、文件状态 `g_lowerCamelCase`。现有公共接口需要保留时，
用项目策略选择适用范围；不要通过批量改名满足模板。

`lint`、`contract` 和 `verify` 都接受可重复的 `--overlay`。配置中的命名模式使用有限 token：
`${MODULE}`、`${snake_case}`、`${lower_snake_case}`、`${lowerCamelCase}`、`${PascalCase}`、
`${UPPER_SNAKE_CASE}`；每个模式包含一个大小写样式 token，可加固定前后缀。不接受任意正则表达式。
函数、命名参数及可识别的变量/字段/typedef 会按实际模式检查；宏展开、编译器扩展及复杂声明仍需
项目编译器或 AST 工具。命名含义、缩写和职责是否合理仍属人工判断。

通用覆盖把 50 行、4 层和 5 参数的超限诊断设为 `warning`，用于设计审查；仅 warning 时 JSON
`ok=true` 且退出码为零，其他 error 仍阻塞。原 DEMO 配置保持 error。这个覆盖用于检查外部代码，
不会把黄金 demo 自动生成器改成业务项目代码生成器。

通用覆盖显式启用普通中文说明的 presence 检查：文件头必须有非空“用途”和“职责边界”；
头文件里的有参公共声明必须有非空“输入”，参数名应出现在“输入/输出”中；非 void 声明必须有
“返回”，有参或返回值的接口还需要“约束”。简单 static helper 和无参 void 接口不强塞空字段。
这些检查只确认字段存在和参数名覆盖，无法证明单位、可空性、输出成功时有效、失败不修改、
调用上下文或限制的描述真实。非 const 指针也可能是工作上下文，工具不会据此推断输出方向。
复杂函数沿用最低关键意图注释检查，不强制编号或 Doxygen；原因是否准确仍需结合代码复核。

`style.encoding=preserve` 声明保持原文件；lint 不写回文件，但不提供 GBK/CP936 识别和解码证明。
现有 `style.braceStyle=function-allman` 表达函数独行、控制语句同行的风格契约，具体排版仍由项目
formatter 检查。不要把 lint 通过当作实际编码、排版、ISR 时序、DMA/cache 或寄存器行为已验证。

## 用户自定义 snippets

`examples/c-snippets.json` 使用 VS Code snippet 的根对象格式，每个条目包含 `prefix`、`body` 和
`description`。用户可以直接修改默认作者、公司、注释段或新增片段，也可以把文件内容复制到
VS Code 的 `.code-snippets` 文件。

列出片段：

```powershell
go run ./cmd/ckit snippet --snippets ./examples/c-snippets.json --list
```

渲染片段；`${TM_FILENAME}`、当前日期、`${1:默认值}`、`$0` 等常用占位符会展开：

```powershell
go run ./cmd/ckit snippet --snippets ./examples/c-snippets.json `
    --name "C File Header (CN)" --target sensor.c
```

覆盖编号占位符并写入文件：

```powershell
go run ./cmd/ckit snippet --snippets ./examples/c-snippets.json `
    --name "C File Header (CN)" --out ./sensor.c `
    --set 3="HU JIAXUAN" --set 5="YourCompany"
```

`init` 会把 `c-kit.json` 和 `c-snippets.json` 一起安装到 `UserCfg/CKit/`；不使用 `--force`
时不会覆盖已有的用户自定义文件。CLI 只渲染本示例使用的常用占位符子集，完整 VS Code 变量、
choice 和 transform 语法仍由 VS Code 自身处理。

## 外部候选文件验证

`verify` 将候选 C/H、可选 baseline 和 host harness 写成一个可审查的 target manifest。`fast`
用于重构过程中的秒级反馈，`full` 在收口时增加 Clang、C++17 头文件和 baseline/candidate 行为等价：

```powershell
go run ./cmd/ckit verify --config ./examples/c-kit.json `
    --target ./examples/verify-target.json --profile fast --timings --json

go run ./cmd/ckit verify --config ./examples/c-kit.json `
    --target ./examples/verify-target.json --profile full --timings --json
```

该入口只调用主机 `gcc`、`g++`、`clang`、`clang++` 和本次在临时目录生成的测试程序；target
不能提供 shell 命令，也不会调用 TI/CCS、工程 `gmake` 或固件构建。清单格式和 profile 语义见
[外部 C 文件验证](docs/EXTERNAL_VERIFICATION.md)。

## 一键验证

Windows：

```powershell
./scripts/verify.ps1
```

Linux/macOS：

```sh
./scripts/verify.sh
```

门禁依次验证：

1. Go 生成器、lint 正例和负例；
2. PDF 对 Markdown 的 61 页、0—16 章、139 条款与代码示例完整性；
3. 规则目录确定性和 0 条未分类；
4. `c-kit.json`、`c-snippets.json` 与规则目录各自的 JSON Schema；
5. 简单入口和公开高级样例的确定性生成与完整 lint；
6. GCC 严格 C99 零告警并运行行为测试；
7. Clang 严格 C99 零告警；
8. 四个头文件分别通过 GCC/Clang C99 和 G++/Clang++ C++17。

编译选项从 `examples/c-kit.json` 读取，包含 `-Wvla`、`-Wconversion`、
`-Wsign-conversion`、`-Wshadow`、`-Wmissing-prototypes`、`-Wstrict-prototypes`、
`-Wformat=2` 和 `-Werror`。

## 参考资料

- [参考资料索引](references/README.md)
- [PDF 转换与完整性报告](references/CONVERSION_REPORT.md)
- [完整规则目录](docs/RULE_CATALOG.md)
- [架构](docs/ARCHITECTURE.md)
- [C99 注释方法](docs/COMMENTING_METHOD.md)
- [外部 C 文件验证](docs/EXTERNAL_VERIFICATION.md)
- [需求追踪](docs/spec/TRACEABILITY.md)
- [验证报告](docs/VERIFICATION_REPORT.md)

原 PDF、规范化 Markdown 与 raw 转换件按用户授权作为 C Kit 的正式参考资产随受管发行包发布。
