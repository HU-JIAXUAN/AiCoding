# C99 Standard C Embedded Rules

本目录提供平台格式、注释模板和检查入口的配置。规范语义来自已安装 C99 Skill、当前项目规则与华为条款；项目已确认的接口、归属、编码和工具链优先。

## 生成前的有效约束

- 先识别自研、生成和第三方代码；只改变当前请求涉及的自研内容，保留其他来源的既有约束。
- 自研默认使用 4 空格、120 列；函数左大括号独占一行，控制语句左大括号同行。
- 函数用 `snake_case`，参数和局部变量用 `lowerCamelCase`，类型用 `PascalCase`，文件状态用 `g_` 加 `lowerCamelCase`；稳定公共接口保留项目既有命名。
- 读取和写回前核对实际编码、BOM 与换行。`fmt` 不提供编码转换保护；GBK/CP936 文件先验证字节 round-trip，再选择相容的项目格式工具或仅检查。
- 模块化、平台适配或解耦先使用架构 Skill；C 检查器不能替代职责和生命周期判断。

## 注释

- 普通说明使用 `/* 中文说明 */`，放在目标右侧或紧邻上方，句末不加句号；上方说明与前一段代码留空行，并与目标同缩进。
- 函数说明实际用途，按需要补输入、输出、单位、错误、调用上下文和寿命。简单函数一句即可，不能为数量指标制造重复内部说明。
- 字段说明用途及必要的单位、范围、读写方；枚举逐值说明含义。有意贯穿说明目标和原因。
- 项目明确生成 Doxygen 文档时才选用其标签。模板不默认添加公司、作者、日期、MISRA 合规声明或代码变更历史。
- 模板变量必须用当前代码事实填写；不适用的说明整行删除，不能把模板槽位写进交付源码。

## 现有执行能力

- `skill c99-standard-c check --scope changed|staged|paths` 目前是 `clang-format --dry-run --Werror`，仅证明选中文件满足格式配置。
- `skill c99-standard-c verify --depth fast|full --target <manifest> --overlay <overlay>` 调用 C Kit 验证显式候选。省略 target 时验证的是 Kit 示例，不能当作用户代码通过。
- C Kit 的 `examples/portable-c99.overlay.json` 提供通用命名及复杂度审查级别；叠加项目 overlay 设置实际短模块前缀。原 `examples/c-kit.json` 保持 DEMO 教材样例兼容。
- 50 行、4 层和 5 参数在通用 overlay 中作为 warning 提示设计审查；不为消除指标而机械拆函数。旧 DEMO profile 继续将超限作为 error。
- C Kit lint 是有限词法检查，不能证明未定义行为、所有返回值处理、ISR 阻塞、寄存器副作用、DMA/cache、临界区或最坏执行时间。真实工程仍需其编译、静态分析及行为证据。

## 检查与修改边界

默认先运行只读 `check`，确有授权且编码相容时才执行定向 `fmt`。不把整个 vendor、third_party、generated、Drivers、device、build、out、dist 或 Kit 黄金样例纳入无关格式整改。

提交检查覆盖实际 staged 内容的范围必须明确；目前平台格式入口按 index 选文件名、读取 worktree。需要验证提交快照时使用 C Kit staged lint 或项目现有 index 检查，不能将两者混称。
