# C99 Standard C Skill

C/H 风格能力属于 `c99-standard-c` skill，不作为独立 formatting kit 暴露。C Kit
1.2.0 是该 skill 使用的首方外部工具资产，注册为 `c-kit`，但不新增用户命令命名空间。

## 配置边界

- Skill 配置：`config/skills/c99-standard-c/skill.json`
- 机械格式：`config/skills/c99-standard-c/style/clang-format.yaml`
- 注释模板：`config/skills/c99-standard-c/templates/comment-templates.json`
- 嵌入式 C 规则：`config/skills/c99-standard-c/rules/embedded-c-rules.md`
- Go 实现：`internal/cstyle`
- C Kit 根目录：`CodingKit/tools/c-kit`
- C Kit 配置：`CodingKit/tools/c-kit/examples/c-kit.json`
- 通用配置 overlay：`CodingKit/tools/c-kit/examples/portable-c99.overlay.json`
- 用户 snippets：`CodingKit/tools/c-kit/examples/c-snippets.json`
- 快速验证目标：`CodingKit/tools/c-kit/examples/verify-target.json`
- Kit manifest：`config/kits/c-kit.json`

根目录 `.clang-format` 只是工具投影；source of truth 是 skill 配置。`.vscode` 不入仓。

机械格式和模板入口使用仓库级 skill 配置；黄金 Demo、139 条规则目录、注释方法、
高级规则覆盖样例、snippets、lint、主机编译和行为测试由 C Kit 提供。高级样例对最终用户可见，
便于先检查代码与注释表达，再调整 JSON 配置。

## 注释规则与机器检索

- 项目明确规则和现有有效约定优先；新自研文件使用普通中文 `/* ... */`，不默认生成作者、公司或修改历史。
- 文件说明写用途、职责边界和实际使用条件；函数先设计输入、输出、返回、失败和上下文合同，再写实现与说明。
- 接口按实际需要说明参数名、用途、单位、范围、可空性和存储寿命；输出注明何时有效、失败是否保持原值。
- 函数内关键注释解释校验、顺序、算法边界、发布或恢复的原因，不逐句翻译代码。字段和枚举项使用简短同行块注释。
- 多行说明统一为独占 `/*`、正文缩进四空格、独占 `*/`；简单 helper 可以使用一行说明，不机械补空的输入/输出标签。
- 格式器采用 120 列、函数括号独行、控制语句括号同行；`ReflowComments: false` 保留已经组织的注释布局。

`portable-c99.overlay.json` 显式启用普通中文合同存在性检查：文件包含非空“用途”和“职责边界”；
公共头声明有实际参数时检查“输入”及参数名，有非 `void` 返回时检查“返回”，相关接口还需“约束”。
输出方向、单位、可空性、失败不修改和上下文描述不能仅从类型推断，由实现与调用方复核。
旧 profile 的标签配置保持兼容，只有项目显式选择时才要求 Doxygen。

`minimumIntentComments` 只定义复杂函数的最低存在性门禁。人或 Agent 仍须按
`readability.keyFlowComments.reviewTriggerIds` 和
`CodingKit/tools/c-kit/docs/COMMENTING_METHOD.md#cstyle-comment-flow-001` 检查阶段边界、
复合条件、状态迁移、算法、硬件时序、错误收敛和资源生命周期，不能把“lint 通过”解释为语义
已经完整，也不能把 F01—F07 标签机械写入源码。

## Taskfile 入口

```bash
task style:c:status
task style:c:templates
task style:c:verify
task fmt:c
task fmt-check:c
task fmt-check-staged:c
```

## Go CLI 入口

```bash
bin/aicoding.exe skill c99-standard-c status --json
bin/aicoding.exe skill c99-standard-c templates --json
bin/aicoding.exe skill c99-standard-c verify --json
bin/aicoding.exe skill c99-standard-c verify --depth full --timings --json
bin/aicoding.exe skill c99-standard-c fmt --scope changed --json
bin/aicoding.exe skill c99-standard-c check --scope changed --json
bin/aicoding.exe skill c99-standard-c check --scope staged --json
bin/aicoding.exe skill c99-standard-c check --scope paths --path testdata/style-samples/foc_sample.c --json
```

当前用户入口只保留 `skill c99-standard-c` 和 Taskfile 短路由。

## C Kit 验证

`check` 只运行格式检查，不检查命名或接口语义；`staged` 目前按 index 选文件名后读取工作树，
不能据此宣称验证了暂存区快照。业务提交门禁需要检查真实 index 内容或经验证的快照。

`verify` 通过 `skill.json` 的 Kit 元数据定位 C Kit。默认 target 是黄金 Demo；通过只证明该 Demo，
业务代码必须显式提供包含真实候选与主机测试入口的 `--target`。默认 `fast` depth 适合编辑循环，执行配置、
lint、GCC C99、头文件探针和主机行为测试；`full` 在收口时增加 Clang、C++17 头文件探针及
baseline/candidate 行为等价。registry manifest 登记同一资产及其维护命令，两条路径共享相同配置
和快速目标。入口返回统一 JSON envelope，不调用 TI/CCS 或其他固件工具链，也不会把候选文件
加入固件构建。

```bash
# 默认黄金目标的秒级反馈
bin/aicoding.exe skill c99-standard-c verify --depth fast --timings --json

# 默认 Demo 的完整主机门禁
bin/aicoding.exe skill c99-standard-c verify --depth full --timings --json

# 验证项目自有 target；overlay 可重复指定
bin/aicoding.exe skill c99-standard-c verify --depth full \
  --target path/to/verify-target.json \
  --overlay CodingKit/tools/c-kit/examples/portable-c99.overlay.json \
  --overlay path/to/project-overlay.json --timings --json
```

`--target` 和 `--overlay` 的相对路径均以 AiCoding 仓库根解析；不存在的文件、未知参数、错误
schema 或子进程返回的 profile 不匹配都会使命令非零退出。

portable overlay 使用函数 `snake_case`、类型 `PascalCase`、局部变量/参数 `lowerCamelCase`、状态 `g_lowerCamelCase`；
项目 overlay 设置实际 `naming.modulePrefix`。50 行/4 层/5 参数为审查 warning，不是对复杂算法的机械否决。
仅需 Lint 时可使用 C Kit 的显式文件入口；绝对路径指向本次候选，不能用 Kit 的 index 替代业务暂存区：

```bash
go -C CodingKit/tools/c-kit run ./cmd/ckit lint \
  --config ./examples/c-kit.json --overlay ./examples/portable-c99.overlay.json \
  --scope files --file <absolute-c-file> --file <absolute-h-file> --json
```

底层等价命令由 manifest 固定为：

```bash
go -C CodingKit/tools/c-kit run ./cmd/ckit verify \
  --config ./examples/c-kit.json \
  --target ./examples/verify-target.json \
  --profile fast --timings --json
```

底层命令用于 registry/维护验证；日常用户仍应使用 `skill c99-standard-c verify` 路由。

## 范围

- `changed`: modified 和 untracked C/H 文件。
- `staged`: staged C/H 文件。
- `paths`: `--path` 显式路径。
- `all`: 全仓 C/H 文件，但不作为默认 Taskfile 路由。

默认排除项来自 `skill.json`：单个目录名（例如 `vendor`、`generated`）在任意层级匹配；含 `/` 的条目按仓库相对路径前缀匹配。除常规生成目录外，平台格式检查排除自带独立规则与门禁的 `CodingKit/tools/c-kit`，但不排除其他 `CodingKit` 或 `tools` 内容。

## 验证

```bash
go test ./internal/cstyle
go run ./cmd/aicoding skill c99-standard-c status --json
go run ./cmd/aicoding skill c99-standard-c templates --json
go run ./cmd/aicoding skill c99-standard-c verify --json
go run ./cmd/aicoding skill c99-standard-c verify --depth full --timings --json
```
