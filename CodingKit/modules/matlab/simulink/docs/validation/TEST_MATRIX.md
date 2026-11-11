# 测试矩阵与验证方法

无位置传感器首批已完成R2026b独立MIL：[PLL 12项](../../model/lib/相位跟踪/waveform_analysis/ANALYSIS.md)、[SMO 14项](../../model/lib/观测器/滑模/waveform_analysis/ANALYSIS.md)。另有[启动10项](../../model/lib/无感启动/waveform_analysis/ANALYSIS.md)与[切换19项](../../model/lib/无感切换/waveform_analysis/ANALYSIS.md)独立验证，分别记录软件请求时序和合成估算输入下的捕获/退出。[Sensor并行对照8项](../../model/app_models/Sensor/observer_compare/waveform_analysis/ANALYSIS.md)及[坐标PI 10项](../../model/lib/电流环/waveform_analysis/FRAME_TRACKING.md)已通过；SensorlessFOC另已完成8项物理MIL，HFI启动22项、低速FOC24项、双向融合18项物理MIL另计；single/SIL/目标验证未执行，继续按[专项计划](../plans/SENSORLESS_PLAN.md)推进。真实角度只用于评估，不作为SMO输入或在线判锁依据；PLL的输入是待跟踪相位，与转子观测的任务不同。

当前第15步实际结果：[MTPA/弱磁25项MIL](../../model/lib/MTPA弱磁/waveform_analysis/ANALYSIS.md)，细节和实际断言见模块脚本。此前06–14结果见[实施记录](../history/BUILD_06_14.md)。下面保留工程级场景与目标验证范围；未在结果文件中登记的项目仍为待验证。

已实现：[离散 PID 验证](../../model/lib/离散并联PID/waveform_analysis/ANALYSIS.md)，12 项 MIL 工况通过，包含解析积分、双向限幅、复位、官方对照及一阶对象饱和恢复。下列电机系统场景继续作为建设清单，不表示已经执行。

## 层级
- Unit：Clarke/Park 正逆一致性，PI 积分和限幅，转矩电流变换，速度估计，PWM 占空比边界。
- Integration：电流环 -> FOC -> PMSM；外环级联，负载扰动，采样/延迟与速率过渡。
- Regression：同一版本参数与场景输出的指标对比；差异需分类为算法改进/Plant 变更/数值行为。
- Deployment：生成 C、SIL/PIL、P650 LaunchPad 与自制 F28388D 各自的目标时间、数值类型和外设时序检查。

## 首批场景清单
| ID | 场景 | 主要观察 | 通过标准制定方法 |
|---|---|---|---|
| T01 | Clarke/Park 正逆变换 | 变换误差、方向 | 数值误差在浮点/定点合理容差内 |
| T02 | PMSM 无负载阶跃 | Id/Iq、ω、T_e | 与解析/参考数值关系一致 |
| T03 | 电流给定阶跃 | 超调、调节时间、限压 | 依据电机带宽设计/硬件上限确定 |
| T04 | 速度阶跃 | 稳态误差、饱和、稳定性 | 根据任务性能要求确定 |
| T05 | 位置阶跃 | 跟踪、振荡、过冲 | 根据任务需求/机构安全确定 |
| T06 | 负载扰动 | 恢复时间、最大偏差 | 根据目标带宽和任务容差确定 |
| T07 | 正反转与过零 | 坐标一致性、转矩符号 | 没有错误方向或异常积分 |
| T08 | 电压电流限制 | `saturated`、实际输出 | 限制不被突破，积分不持续失控 |
| T09 | ADC/encoder 延迟 | 相位、稳定范围 | 与 F1 基线差异可解释 |
| T10 | 变体替换 | 相同外部接口、状态 | 模型编译/运行，接口契约通过 |
| T11 | F1 vs F2 | 低频响应差异 | 在定义频域内符合等价预期 |
| T12 | 参数扰动 | Rs/Ld/Lq/J 变化 | 可记录失效边界与稳健区间 |

## 指标与报告
指标建议：rise_time_s、settling_time_s、overshoot_pct、steady_state_error、rms_error、peak_i_A、peak_v_V、saturation_ratio、simulation_wall_time_s、controller_exec_time_us。必须记录计算方法、窗口和单位；**计划版不设置凭空假定的合格数值**。

## 复现必要信息
Git commit/tag、MATLAB 版本、许可证/工具箱版本、模型 variant、参数快照、控制 Ts、求解器和步长、随机数种子、报告版本。
