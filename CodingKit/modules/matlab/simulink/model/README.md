# 模型目录

模型分为可复用积木、完整应用和学习复现。组件测试台随积木保留，整机模型归 App。

| 目录 | 内容 |
|---|---|
| [lib](lib/README.md) | 按功能维护 PID、PMSM、Clarke/Park、SVPWM、观测器等通用模块。可复用部分提供 Simulink Library `.slx`，由其他模型通过 Library Link 调用；组件测试台以 `Test.slx` 结尾。 |
| [app_models](app_models/README.md) | 可直接运行的完整应用 `.slx`，例如 FOC、MTPA/弱磁和无位置传感器控制。按位置反馈来源分为 `Sensor/` 和 `Sensorless/`，模型名不带 `Test`。 |
| [studies](studies/README.md) | 文章学习、论文复现和第三方示例分析。运行模型使用普通 `.slx`；整理为可复用积木后再纳入 `lib/`。 |

每个功能模块保留自己的 `README.md`、`src/`、`parameter/`、`build_process/`、`waveform_analysis/`、`ref/` 和 `docs/`。模块 README 写清功能、参考来源、运行方法、参数配置和验证状态；模块 `docs/` 只保留 `README.md` 与 `公式推导.md`。

SLX 放在所属功能模块的 `src/`。库模型与验证模型分开保存；App 通过库链接复用通用积木。`.slxp` 受保护引用模型暂不生成，后续模块稳定后再评估。公共脚本入口见 [docs/scripts](../docs/scripts/README.md)。

MATLAB Project（`.prj`）路径及依赖管理列为后续工程配置，当前尚未创建项目文件。目前使用 [initialize_motor_paths.m](../docs/scripts/initialize_motor_paths.m) 初始化通用入口，具体模型由各模块初始化函数加载参数。

[目录规则](../rules.md) · [工程入口](../README.md)

[受保护模型接口](../docs/interfaces/PROTECTED_MODELS.md) · [维护计划](../docs/plans/PROTECTED_MODEL_PLAN.md)
