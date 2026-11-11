# DiscretePID 首版计算定义

模型文件：`src/DiscretePID.slx`（库中的 Controller 子系统）。测试模型：`src/DiscretePIDTest.slx`。参数文件：`parameter/discrete_pid_parameters.m`。本次采用无量纲 double MIL 参数。

采样时刻 k 的状态为 x[k]。只有 enable=true 且 reset=false 时 active=true。

```text
active:
  s[k] = Tf/(Tf+Ts)*s[k-1] + (e[k]-e[k-1])/(Tf+Ts)
  x_d[k] = Kd*s[k]
  v[k] = Kp * e[k] + x[k] + x_d[k]
  u[k] = min(UMax, max(UMin, v[k]))
  x[k+1] = x[k] + Ts * (Ki * e[k] + Kaw * (u[k] - v[k]))
inactive (reset=true 或 enable=false):
  u[k] = 0; v_output[k] = 0; saturated[k] = false
  x_observed[k] = X0; x[k+1] = X0
  s[k] = 0; x_d[k] = 0
every tick:
  previous_error_next = e[k]
```

reset 优先于 enable，均按采样电平处理。重新使能的第一拍使用 X0。限幅只约束 active 输出，禁能/复位强制输出零。Kaw=0 为关闭回算的实验配置；正常参考使用 Kaw=20 1/s。

Unit Delay 显式保存 x[k]，先算输出再写下一状态，避免积分计算形成代数环。输出 x_i 是诊断端口，供观察积分行为。

滤波斜率与上一误差初值均为 0。s[k] 为本拍滤波斜率，不是积分状态。先滤波再乘 Kd，保证 Kd=0 的微分贡献为零。默认 Kd=0、Tf=0.01 s；Kd 的单位为 s。微分作用在误差上，误差阶跃会产生瞬态响应。

验证范围：解析线性积分、正负对称、双向限幅、reset/disable、Kaw 开关、一阶对象饱和恢复、微分阶跃解析响应和 PID 斜坡。Kd=0 时显式与官方 PI 比较，Kd>0 时与官方 PID 比较；积分均为前向欧拉，微分滤波均为后向欧拉，对照限定全程使能、无复位。Simulink Test 当前不可定位，采用 SimulationInput 与断言；不宣称 SIL/PIL 或 MCU 时间验证。
