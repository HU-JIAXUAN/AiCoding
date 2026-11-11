# 06–14 实施记录

范围：数学 PMSM 与刚性负载、最小实验、电流环、SVPWM/平均逆变器、采样执行时序、速度/位置环、共同场景、dq 前馈、死区与补偿。现有 math 和离散 PID 保持独立复用。

功能目录：pmsm_plant、current_loop、inverter、timing、motion_loop、feedforward、deadtime、experiment，均直接位于 model 下；五个固定子目录随模块创建。

数据流：位置 P → 限速与速度斜率限制 → 速度 PI → iq 请求 → dq 电流 PI → dq 前馈 → 电压圆限制 → 反 Park → 死区补偿 → SVPWM → 执行保持/延迟 → 平均逆变器 → PMSM。电流、角度和速度经过显式采样/延迟再供控制使用。

参数是自定义教学仿真夹具，尚未绑定实际电机：Rs=0.5 Ω、Ld=1 mH、Lq=1.2 mH、磁链=0.035 Wb、4 极对、J=0.0005 kg·m²、B=0.0001 N·m·s/rad、母线48 V。参数文件归各模块所有，实验只引用。

电流控制100 µs、外环1 ms、Plant固定步长5 µs分别定义。短时单桥臂开关试验使用0.1 µs步长。它们不是C2000实测时序。此阶段不需要MCU引脚、DMA或ISR；后续P650/F28388D目标适配另行绑定。

电流环需要最终限制残差。现有 DiscretePID 只有内部限幅回算；本阶段另建透明的双轴 PI 积分更新块，支持外部电压残差，不改动旧模型接口。速度 PI 复用 DiscretePID 的 Controller，Kd=0。残差评价点为同一拍的等效端电压命令，不拿延迟后的旧命令直接与当前请求相减。

验证顺序：电气 RL/转矩/机械解析解 → 电流闭环 → 调制与限幅 → 整数拍时序 → 速度与位置闭环 → 共同场景 → 前馈开关和参数偏差 → 平均死区补偿及单桥臂开关校验。每个模块保存实际结果后再更新完成状态。

当前状态：八个新模块的MIL实现与文档完成，共45项通过。电机5、电流6、逆变器4、时序3、运动环3、共同实验9、前馈5、死区10。模块各自的waveform_analysis保存MAT、JSON、PNG/SVG与分析；每个模块有独立运行教程和实际Scope通道表。

关键结果：电流饱和恢复IAE由关闭回算的0.545301降至0.0388433 A·s；500rad/s电角速度下前馈将同工况电流IAE由0.0138881降至0.000964101 A·s；1rad加载位置实验1.5s末位置约0.999595rad。死区补偿末段RMS由0.0576382A降至0.0498056A，缩窄平滑区的案例为0.0318012A。这些均为本例参数的模型结果。

小组件探路模型为[current_loop/src/CurrentPIProbeTest.slx](../../model/lib/电流环/src/CurrentPIProbeTest.slx)。GRT/C配置工具返回 `无法解析名称 'simulinkcoder.internal.wizard.ConfigSetManager'。`，success=false且未改配置，已停止该配置尝试，没有生成C或构建。记录在[codegen_probe.json](../../model/lib/电流环/waveform_analysis/codegen_probe.json)。Embedded Coder产品和正确的RTW_Embedded_Coder许可探测均通过，尚未选定C编译器；配置工具错误根因未进一步定位，C2000验证仍属后续工作。

本地参考、官方来源和未证明事项见[REFERENCE_06_14.md](../references/REFERENCE_06_14.md)。全套运行入口是[run_motor_validation.m](../scripts/run_motor_validation.m)，单次实验是[run_motor_case.m](../scripts/run_motor_case.m)。

保存检查：关闭并重载10个新测试/探路模型后均可仿真；普通台架、短时桥臂和整机分别核对记录维数。新增脚本Code Analyzer为0项；全部21个SLX均位于模块src，九个带记录台架的130列均有说明。目录统计与MANIFEST一致，Markdown离线链接0错误，git diff --check通过。

仓库通用检查另记：Full为70通过、1失败、4跳过，失败是HEALTH-001的doctor性能/环境检查，含Visio/PPT同名未托管MCP、runtime Skill漂移和延迟预算；doctor/status/Smoke verify也报告相应环境问题。DocSync、依赖治理、计划路径检查以及安装/更新dry-run通过。没有为模型任务改动这些环境配置，也没有把仓库通用检查标为全绿。
