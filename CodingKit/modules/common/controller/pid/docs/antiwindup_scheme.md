# 积分抗饱和方案说明

## 参考模型

文件：

```text
simulink/models/reference/antiwindup_complete_reference.slx
```

模型中可识别的关键块：

| 模型块 | 作用 |
|---|---|
| `Sum1` | 计算误差 `e = reference - output` |
| `Integrator` | 积分状态 |
| `Sum` | 组合比例路径和积分路径，得到限幅前输出 `uc` |
| `Saturation` | 将 `uc` 限制为实际输出 `u` |
| `Sum2` | 计算 `uc - u` |
| `Gain2` | anti-windup 反馈增益 |
| `Sum3` | 将 `e - Kaw * (uc - u)` 作为积分输入 |
| `Gain` | 积分增益 `Ki` |

## 控制方程

```text
uc = P/I 组合后的限幅前输出
u  = saturation(uc)
aw = u - uc

I(k+1) = I(k) + Ki * [e(k) + Kaw * aw(k)] * Ts
```

这就是 back-calculation 积分抗饱和。输出没有饱和时，`u - uc = 0`，积分按普通 PI/PID 工作；输出饱和时，`u - uc` 会把积分项向脱离饱和的方向拉回。

## 与 C 实现的对应关系

| Simulink | C 字段 |
|---|---|
| `uc` | `state.rawOutput` |
| `u` | `state.output` / `limitedOutput` |
| `Kaw` | `config.antiWindupGain` |
| `Ki` | `config.ki` |
| `e` | `state.error` |

C 实现保留通用 PID 边界，不绑定参考模型中的具体数值。参考模型用于验证拓扑，工程中可按对象修改 `kp / ki / antiWindupGain / outputLimit`。

## 下游最终输出

常规 `pid()` 以自身输出限幅结果作为 u，行为保持兼容。若下游还有约束，使用 `pid_eval()` 得到不推进积分的 `PidStep.next.rawOutput`，再由 `pid_track(controller, appliedOutput, step)` 把最终施加输出作为 u 回算一次。积分限幅在这一次完整回算之后执行，不能先限幅积分再补一个外部修正量。

`pid_runtime` 的确定算例会区分正确的 0.2375 与错误二次回算的 0.225，并覆盖持续外部饱和和恢复；共享组件测试还从真实最终 duty 重建输出，验证二维矢量约束的回算。原有参考模型及其拓扑没有因接口扩展而修改。
