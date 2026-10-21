# 修改前实际 C 行为基线

本目录是 S2 在修改 PID 前采集的固定参考，不由 CTest 自动生成或更新。[baseline.json](baseline.json)记录源码提交、原始工作区字节 SHA-256、编译条件和参考文件哈希。原始提交为 a262e484cc33d1da104cae1f14fc47e2cf55f1b8，采集时控制源码没有未提交修改。

## 采集与比较

采集使用 GCC 14.2.0、C99、O0 和严格编译告警，链接修改前真实 PID、FOC、变换及调制源码。运行 [test_legacy.c](../test_legacy.c) 的 pid/foc 采集模式得到以下文件，随后再修改 PID；参考不是 Python 模型结果：

- [legacy_pid.txt](legacy_pid.txt)：8 个场景，每场景实际执行 64 周期，选取 72 行状态。
- [legacy_foc.txt](legacy_foc.txt)：5 个场景，每场景实际执行 128 周期，选取 55 行状态。

正常 CTest 始终传入固定参考路径，逐字段比较，不会把当前输出重写为预期。参考保留 9 位有效数字；绝对容差 1e-6、相对容差 3e-6，按两者较大值判定。NaN 只匹配 NaN，无穷只匹配相同符号；这些规则保留旧入口已有数值行为，不代表新路径接受非有限输入。

每行头两列是场景编号和周期。PID 后接 17 项：setpoint、setpointLimited、feedback、feedbackLimited、error、previousError、derivative、derivativeFiltered、proportional、integral、derivativeTerm、feedforward、rawOutput、output、saturated、initialized、status。FOC 头两列后接驱动中 observations 的 22 项，再依次追加 pid_id、pid_iq、pid_pos、pid_vel 的同一组 17 项。

## 覆盖与边界

PID 包含 P/PI/PD/PID、参考和反馈限制、误差限制、斜坡、微分滤波、积分/输出限制、死区、非法频率、非法上下限、非有限输入及状态清零恢复。FOC 包含 VF/IF、两种角度来源、四环状态、offset、矢量限压、无效母线和非法模式。

工作区原始 C 文件既有 LF 也有 CRLF，哈希按采集机器的实际字节记录；换行不同的 checkout 不一定具有相同字节哈希，但不能因此修改数值参考。五个旧 PID 结构的成员类型/顺序保持不变，FOC 控制、数学、调制和六个示例源码未修改；新两阶段 API 的错误原子性由 pid_runtime 单独检查。

若以后有明确需求改变旧行为，必须审查预期差异并在明确旧版本上重新采集。不能运行当前分支的采集模式来抹掉回归。这里证明的是宿主算法兼容性，不包含硬件运行、机械同步或实时预算。
