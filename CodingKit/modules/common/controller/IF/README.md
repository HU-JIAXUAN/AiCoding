# I-f 开环电流控制

以 ZK 已验证的 I-f 实现为基线：**启动先用 D 轴电流强拉对齐，再切换到软件角度旋转下的 Q 轴电流控制。** 使用 C99、float 和物理单位，不依赖 MCU、编码器、ADC 或 PWM 寄存器。

完整启动流程由 IF 模块逐周期完成，使用者只负责采样、调用、应用占空比及硬件使能。

## 启动流程

```text
使能 → D 轴电流缓升并保持 → 零电压一拍 → 频率爬升 → 连续 I-f
```

1. 固定 `alignAngleRad`，频率为零、Iq 为零，将 Id 从零升到 `alignCurrentA`，然后保持。
2. 清除两轴积分，三相输出 50% duty，保持一个采样周期。
3. 正运行电流时将软件角度减去 90°，负运行电流时加上 90°，再使用 `Id=0、Iq=currentA`。这个偏移保持目标定子电流方向连续。
4. 按 `frequencyRampS` 从零升到给定电频率，随后连续运行。对齐和运行电流分别配置。

D 轴强拉用于建立转子与激励方向的初始关系、改善起转一致性，并不是校正电流采样或永久获得真实转子角度。这里按时间完成对齐，没有编码器确认；进入旋转后仍是角度开环，负载会造成转子跟随误差。

## 接口与参数

只使用 `if_init()`、`if_reset()`、`if_update()` 三个入口，具体声明见[公共头](src/if_controller.h)。初始化一次，之后按固定周期调用；每个实例由一个执行者独占，不并发复位或复制运行对象。

| 内容 | 参数及单位 |
|---|---|
| 基础配置 | `periodS`：s；`currentLimitA`：相电流峰值 A；`voltageLimitV`、`busMinV`：V；`dutyMargin`：占空比两端裕量 |
| 电流 PI | `piD/piQ.kp`：V/A；`piD/piQ.ki`：V/(A*s) |
| 对齐 | `alignAngleRad`：rad；`alignCurrentA`：A；`alignRampS`、`alignHoldS`：s |
| 启动加速 | `frequencyRampS`：s；只在启动阶段组织频率爬升 |
| 周期输入 | `enable`、`sampleValid`、`phaseCurrentA[3]`、`busVoltageV`、`currentA`、`frequencyHz` |
| 周期输出 | `outputValid`、`state`、`duty[3]`、使用角度、频率、电流参考/反馈、电压及受限标记 |

`currentA` 是运行 Q 轴电流，方向由有符号电气频率决定；负电流会改变虚拟坐标关系，不是编码器坐标下的直接转矩指令。机械转速、极对数和减速比换算在调用方完成。

对齐时间按最近控制周期取整，正时间至少一个周期；对齐电流必须为正且不超过电流上限，对齐缓升和保持不能同时为零。零缓升表示立即施加对齐电流，零加速表示直接使用运行频率。

使能为 false 时立即清运行状态，返回无效输出；接入工程必须关闭真实 PWM。再次使能重新从对齐开始。错误锁存到停止或 `if_reset()`，不会因为下一帧采样恢复就自行重新出力。初始化和复位须在实际输出已禁用的独占窗口执行。

## 最小调用

下面的数值来自 ZK 对照配置，不是所有电机通用参数。采样需已完成偏置和单位换算；duty 是 a/b/c 上桥臂导通占比，寄存器比较值和输出极性由接入工程映射。

```c
IfController controller = {0};
IfConfig config = {
    .periodS = 0.0001f,
    .currentLimitA = 6.0f,
    .voltageLimitV = 12.47f,
    .busMinV = 1.0f,
    .dutyMargin = 0.05f,
    .piD = {1.0f, 1000.0f},
    .piQ = {1.0f, 1000.0f},
    .alignAngleRad = 0.0f,
    .alignCurrentA = 4.0f,
    .alignRampS = 0.2f,
    .alignHoldS = 0.5f,
    .frequencyRampS = 2.0f
};
IfInput input = {0};
IfOutput output;

/* 输出关闭时初始化一次；检查返回值。 */
IfStatus status = if_init(&controller, &config);

/* 每个采样周期填入有效电流、母线及 enable，再调用一次。 */
input.currentA = 6.0f;
input.frequencyHz = 58.333333f;
status = if_update(&controller, &input, &output);
/* status == IF_OK && output.outputValid 才应用 duty，否则关闭 PWM。 */
```

生产程序必须处理初始化失败。示例中的 `enable/sampleValid` 默认是 false，不能直接通电；kp/ki 需要按实际电机与采样条件设置，示例没有宣称采用了 ZK 的量化增益。

## 控制方法

每拍先准备启动参考、推进软件角度，再执行 Clarke/Park → 两轴 PI → 统一矢量限压 → 逆 Park → SVPWM。同一拍的所有变换共用一个角度；相位有界累计并保留小增量补偿。零频保持方向；运行中修改电流和频率直接生效，需要平滑反向时先停机再启动，或由调用方组织运行给定。

PI 对齐 ZK 的“先积分、后输出”：积分与各轴输出先限幅，再按合成电压圆盘缩放；发生矢量饱和时让积分跟踪限幅电压。共享 [PID](../pid/README.md) 提供独立的轻量 PI 步，旧 `pid()/pid_eval()/pid_track()`、旧结构布局和 FOC 行为保持兼容。

电压上限同时服从用户配置与 `(1-2*dutyMargin)*Vbus/sqrt(3)`；SVPWM 输入是 `[v_alpha,v_beta]/Vbus`。电流是幅值不变变换下的相电流峰值，正 q 轴超前正 d 轴 90°。输出电压是限幅后的理想指令，不包含实际死区、器件压降或硬件执行确认。

## ZK 基线与参考

本地参考为 `F:\ZK\Work_MOTOR\CT2001_MSDK`，核对提交 `c616916cdd4f75669e8895a8112939f15567e3fa`：

- `sdk_open/user/Contorl/open.c`：`hy_if_ctrl()` 的对齐、零电压交接、90° 偏移和频率爬升；`open_current_step()` 的电流闭环。`Open_Ctrl()` 是直接给电压的另一条路径。
- `sdk_open/user/Contorl/PI_Regulation.c`、`sdk_open/user/Loop_Ctrl/CurrentLoop.c`：先积分的 PI、合成限压与积分跟踪。
- `sdk_open/user/SVPWM/svpwm.c`、`sdk_open/user/Motor_config/config.h`：统一电压限幅与单位换算；当前 `0.45 pu` 基于 `Vb=48/1.732 V`，约 12.47 V。
- ZK 的寄存器写入、死区补偿和设备保护保留在工程接入；float 实现不复制 Q14/Q32 存储或设备对象。定点与 float 对照须分别处理量化和查表误差。

保留这些开源参考作为补充，不继续增加控制框架：

| 来源 | 具体借鉴 |
|---|---|
| [VESC 开环电流](https://github.com/vedderb/bldc/blob/abc9217fb2b7ee3821f1742bc32b269173643319/motor/mcpwm_foc.c#L878) | 转动频率与固定相位的电流激励接口 |
| [VESC 编码器检测](https://github.com/vedderb/bldc/blob/abc9217fb2b7ee3821f1742bc32b269173643319/motor/mcpwm_foc.c#L1518) | D 轴激励、方向/极对数识别、双向采样与圆周偏置求解 |
| [moteus 电流扫描](https://github.com/mjbots/moteus/blob/8f747f4ac448d117c1390b77ca2d80c27e751a56/fw/board_debug.cc#L562)、[校准求解](https://github.com/mjbots/moteus/blob/8f747f4ac448d117c1390b77ca2d80c27e751a56/lib/python/moteus/calibrate_encoder.py) | 将快速电流控制与采样、拟合、质量判断分开 |
| [ODrive 偏置校准](https://github.com/odriverobotics/ODrive/blob/3a2e4dd1bfbda9e4c534d5c7d8428a99c361e783/Firmware/MotorControl/encoder.cpp#L320) | 正反扫描、无响应与结果合理性检查 |
| [SimpleFOC](https://github.com/simplefoc/Arduino-FOC/blob/b3d8f3931342ae68a980d0140e24b9048eba098b/src/common/base_classes/FOCMotor.cpp#L580) | 区分角度来源、真实电流反馈与电压开环 |

以上继续作为行为参考；此前记录的许可证分别为 VESC GPL-3.0-or-later、moteus Apache-2.0、ODrive 历史开源线与 SimpleFOC MIT，不默认复制外部实现。

## 验证与兼容

检查完整启动顺序、对齐电流与保持拍数、零电压一拍、正负方向、停止重启、故障恢复、限压和独立实例。实际 C 测试使用独立公式与最终 duty 驱动的 R-L 模型；模型证明电气链路，不证明真实转子已对齐或同步。

宿主验证已通过：统一控制器 Debug/Release 各 12 项 CTest，IF 独立 Release 3 项。覆盖 9,720 组角度/母线/裕量/电流组合、零频及正负微小频率的百万拍相位累计，以及正反 5 Hz 旋转电流场、降母线、持续限压和撤销电流后的 R-L 恢复；原 FOC/PID 固定参考和六个示例均通过回归。

从 `controller/` 或 `IF/` 目录配置现有 CMake 入口：

```text
cmake -S . -B build-host -DBUILD_TESTING=ON
cmake --build build-host
ctest --test-dir build-host --output-on-failure
```

IF 的旧动作/输入字段已由当前公共头中的简化接口替代；原 FOC/PID 接口和固定参考继续回归，六个 FOC 示例保持兼容。极对数识别、编码器校准和结果保存仍是独立应用，不塞进 IF 对象。
