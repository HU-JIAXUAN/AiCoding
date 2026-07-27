# VOFA+ 轻量通用模块

一套**跨平台、解耦、好上手**的 VOFA+ JustFloat 波形上传 + 在线调参核心。
同一份 `vofa.c/.h` 在 **RZ/T2M（Cortex，8 位 char）** 和 **TI C2000/C28x（16 位 char）**
上直接编译，无需改动。

## 只有 4 个文件（外加 README 和 1 个测试）

```
vofa.h / vofa.c        协议核心      —— 直接加入工程，不用改
vofa_cfg.h / vofa_cfg.c 适配层示例   —— 复制过去，只改这一个
README.md              说明
tests/test_vofa.c      宿主机测试（只依赖 vofa.c）
```

心智模型就一句话：**`vofa.*` 不用动；把 `vofa_cfg.c` 复制到你的工程，改三处即可。**

## `vofa_cfg.c` 里要改的三处

```c
// [1] 串口发送：换成你的发送函数（换 MCU/串口只改这一行）
#define VOFA_SERIAL_SEND(data, length)   uart_tx_send((data), (length))

// [2] 串口接收：主循环里把收到的数据喂给核心（字节流 或 DMA 整帧，二选一）
while (Serial_ReadByte(&raw)) { vofa_byte_t b = raw & 0xFF; Vofa_RxFeed(&b, 1); }

// [3] 调参表：一个可调变量一行，加一个变量就加一行
static const vofa_binding_t k_bindings[] = {
    VOFA_BIND("pos_kp", pos_pid.kp),
    VOFA_BIND("pos_ki", pos_pid.ki),
    // ...
};
```

## 最小使用（三步）

```c
#include "vofa_cfg.h"

app_config_t g_cfg;          // 你的控制配置（在线调参改它）

Vofa_CfgInit(&g_cfg);        // 1. 初始化
// 主循环里：
Vofa_CfgProcess();           // 2. 收命令 + 执行调参
VOFA_SEND(pos, vel, cur);    // 3. 发波形（自动计算通道数量）
```

上位机选 VOFA+ 的 `JustFloat` 协议，帧尾固定 `00 00 80 7F`。

## 三种发送方式

- `VOFA_SEND(a, b, c)`：**推荐**。自动数通道数，并把每个实参强制转 `float`，避开可变
  参数里 `int` 不提升为 `double` 的经典陷阱。
- `Vofa_SendFloats(count, ...)`：通道数运行时才确定时用；`float` 会提升为 `double`，
  **整型实参必须显式 `(double)` 转换**。
- `Vofa_SendChannels(arr, n)`：已有数组时用。

## 验证模式：一键发正弦波确认 JustFloat 通不通

调试初期常分不清“是 JustFloat 没通，还是数据本身不对”。打开**验证模式**，
`Vofa_CfgProcess()` 会持续发送 **3 路相位相差 120° 的正弦波**，上位机能看到三条错开的
正弦就说明链路、波特率、通道数都对了。用一个宏开关切换，调完切回标准模式即可：

```c
// 编译选项里加： -DVOFA_APP_MODE=VOFA_APP_MODE_VERIFY
// 或包含 vofa_cfg.h 前： #define VOFA_APP_MODE VOFA_APP_MODE_VERIFY
```

模式开关和波形都在 `vofa_cfg.c` 的 `[3]` 段里（外部 `hal_entry` 之类不用做任何判断），
幅值/周期直接在那段改。

验证模式初始化时不会注册核心业务发送回调，因此外部调用 `VOFA_SEND()`、
`Vofa_SendFloats()` 或 `Vofa_SendChannels()` 会返回 `VOFA_ERROR_NOT_INITIALIZED`，且不会
写入 UART；三路自检正弦由 cfg 层编码后单独发送，不会再与真实业务遥测交替混帧。
默认相位步进为 `0.1 ms`，每周期 `100` 个点，避免十点波形出现明显折线。

> 波特率由你实际的 UART 硬件配置决定，只要够传每帧 16 字节即可，本模块不做规定。
> 发送频率取决于 `Vofa_CfgProcess()` 的调用节奏；要精确定频（如 1kHz），
> 就从对应周期的定时器里调用 `Vofa_CfgProcess()`。

## 在线调参

三种文本命令（`\n` 结尾，或由 UART IDLE 判帧）：

```text
pos_kp:12.5    赋值
pos_kp+0.5     增量
pos_kp+=0.5    增量（更直观写法）
```

接收两个入口：`Vofa_RxFeed(bytes,len)` 喂字节流（核心按 `\n` 组帧）；
`Vofa_RxFrame(frame,len)` 喂一整帧（适合 DMA+IDLE，可不含换行）。命令**只入队**，
`Vofa_Process()`（`Vofa_CfgProcess` 内部会调）才在主循环里应用——中断/DMA 回调绝不
直接改控制参数。

## C2000 / C28x 适配

C28x 的 `char` 是 16 位，没有真正的 8 位类型。核心用 `CHAR_BIT` 自动切换字节类型
（`uint8_t` / `uint16_t`），JustFloat 帧由核心显式生成小端字节序，不发 `float` 内存，
因此两平台结果一致。`vofa_cfg.c` 末尾给了 C2000 的发送宏和临界区示例：发送时只发每个
元素的低 8 位；建议用 `DINT/EINT` 定义 `VOFA_ENTER/EXIT_CRITICAL()` 保护命令队列。

## 编译期可裁剪配置（包含 vofa.h 前 `#define`，都有默认值+静态断言）

| 宏 | 默认 | 说明 |
|---|---:|---|
| `VOFA_MAX_CHANNELS` | `16` | 单帧最大通道数 |
| `VOFA_COMMAND_QUEUE_DEPTH` | `4` | 命令队列深度 |
| `VOFA_COMMAND_NAME_BYTES` | `32` | 命令名缓冲 |
| `VOFA_RX_FRAME_BYTES` | `48` | 单条命令文本上限 |
| `VOFA_ENTER/EXIT_CRITICAL` | 空 | ISR 与主循环并发时的临界区 |

所有缓冲区静态固定，不使用动态内存。

## 验证

```bash
gcc -std=c99 -Wall -Wextra -Werror -I . tests/test_vofa.c vofa.c vofa_cfg.c -o t_vofa -lm && ./t_vofa
gcc -std=c99 -Wall -Wextra -Werror -DVOFA_APP_MODE=VOFA_APP_MODE_VERIFY \
    -DVOFA_TEST_VERIFY_MODE -I . tests/test_vofa.c vofa.c vofa_cfg.c \
    -o t_vofa_verify -lm && ./t_vofa_verify
```

覆盖：JustFloat 小端编码与帧尾、`VOFA_SEND`/变参发送、分片接收、赋值/增量、IDLE 无换行
帧、非法数值、队列满、调参表映射，以及标准/验证模式发送互斥。

## 设计理念

见 [modules/DESIGN.md](../../../DESIGN.md)。
