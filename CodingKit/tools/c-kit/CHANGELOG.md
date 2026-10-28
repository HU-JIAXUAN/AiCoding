# Changelog

## Unreleased

### Added

- 新增 `examples/portable-c99.overlay.json`，按有限命名 token 实际检查通用 C99 函数、参数、
  局部变量、字段、typedef 与文件状态，保留 DEMO 默认命名与黄金样例兼容。
- `lint` 与 `contract` 支持可重复 `--overlay`；复杂度诊断可配置为 warning，JSON/退出码和
  外部 verify 仅阻塞 error，诊断数量截断不能隐藏阻塞项。
- 通用覆盖把 50 行、4 层和 5 参数作为设计审查提示，不增加 ISR、寄存器或并发语义的正则判定。
- 通用覆盖显式开启普通块注释的文件用途/职责边界与公共接口输入/返回/约束 presence 检查，
  参数说明覆盖输入/输出中的实际参数名；不推断输出方向，不把标签存在当作契约语义正确。

- `readability.keyFlowComments.reviewTriggerIds` 固定登记
  `CSTYLE-COMMENT-FLOW-001.F01`—`.F07`，使 Agent 可确定性检索阶段、复合条件、状态迁移、
  算法、硬件时序、错误恢复和资源生命周期七类语义复核入口。
- 函数注释方法补充接口合同与实现意图分层、按需 Doxygen 标签、C-FILAS 适配规则、补充资料
  冲突矩阵和三项人工复核问题。
- 新增 `documentation.singleBriefStyle`，默认 `compact`；仅含一个非空 `@brief` 的 Doxygen
  必须使用 `/** @brief ... */`，多标签或带补充正文的文档仍保持多行。
- lint 新增 `documentation.compact-single-brief` 正反例，并让紧凑单行 Doxygen 可作为函数、
  类型和复杂宏的有效前置文档。
- `macros.simpleObjectCommentStyle` 默认改为 `trailing`；简单对象式宏在定义同行右侧使用
  `/**< ... */`，并保留 `block`、`doxygen`、`either` 兼容模式。
- 新增稳定规则 `CSTYLE-COMMENT-FLOW-001`：配置登记华为来源条款和人类文档入口，lint 对复杂
  函数执行最低函数体意图注释门禁，可读性摘要用同一 ID 提醒人或 Agent 复核语义完整性。

### Changed

- 产品名、目录、manifest/registry ID、Go module、CLI 和 JSON schema 由旧名统一更名为
  `c-kit` / `ckit`；历史发布记录仍保留原始名称。
- 宏、结构体和枚举 snippets/template 使用同行尾注释；纯单标签 Doxygen 改为紧凑单行。

## 1.2.0 - 2026-07-15

### Added

- 第 8 章导向的注释方法：复杂函数编号总览、逻辑段、分支、`case` 和贯穿注释规则。
- lint 可读性摘要，包括函数有效行、分支、嵌套、调用扇出和静态 helper 人工评审项。
- `ckit verify` 的 fast/full 外部候选文件门禁、配置 overlay 和 target manifest schema。
- 简单对象宏的 VS Code 片段，总片段数为 9。

### Changed

- 保持自包含 Go module，并通过上层 registry 与 C99 Skill binding 提供快速验证。
- PDF、规范化 Markdown 与 raw 转换件按用户授权作为正式参考资产随受管发行包发布。
- 未提供工号时不再生成 `@employee_id`；源码修改历史默认禁用，由 Git 和本文件记录。
- 源码文件头不再写资产 `@version`；版本仅由 manifest、资产文档、本文件和 Tag/Release 权威面承载。
- 静态函数前置声明保持裸原型，完整函数注释放在定义处。
- 黄金 Demo 增加编号控制流和领域意图注释，高级规则覆盖样例继续对最终用户可见。

### Fixed

- 函数解析器现在识别 `TYPE *Function(...)`、`TYPE **Function(...)` 等指针返回写法，
  同时避免把 `return *Function()` 和 `sizeof *Function()` 表达式误判为函数声明。

### Verified

- 139/139 条华为规范规则均有证据映射，未分类为 0。
- Kit 发布门禁覆盖 Go、JSON、lint、GCC、Clang、独立 C99/C++17 头文件与行为测试。
- 外部 fast/full 验证只使用主机工具链和临时 host harness，不调用 TI/CCS 或固件构建。
- PDO 验收样例识别 19 个函数（15 个 static、4 个公开函数）；full 11 步门禁和
  baseline/candidate stdout 等价比较通过。
