# VOFA、recorder 与 command 源码包

状态：已完成独立宿主验证的源码资产。接口沿用 CT2001 工程本轮版本；不包含电机 SDK、串口驱动或共享屏障头。目录名按收纳约定保留为 `vofa_recoder_cmd_kit`。

## 文件与职责

| 文件 | 职责 | 移植时是否修改 |
| --- | --- | --- |
| [vofa.c](vofa.c) / [vofa.h](vofa.h) | JustFloat 数据与四字节尾部发送；完整可写文本帧的冒号拆分和空白处理 | 只改头文件注册区的发送绑定，必要时配置端序；两个公开函数不变 |
| [recorder.c](recorder.c) / [recorder.h](recorder.h) | 按信号地址表读取、类型换算、双块发布 | 核心原样使用；不含传输协议或平台头 |
| [command.c](command.c) / [command.h](command.h) | 按名称查表、精确转换整数/浮点、同步提交业务执行 | 只替换现有工程业务绑定区；公共头和解析实现不变 |
| [example_business.c](examples/example_business.c) / [example_business.h](examples/example_business.h) | 可运行的业务 RAM、状态规则、执行入口和动作示例 | 实际工程提供自己的同签名业务实现，不把示例状态当成电机规则 |
| [run_tests.py](run_tests.py)、[test_kit.c](tests/test_kit.c)、[test_endian.c](tests/test_endian.c) | 独立编译真实核心并验证数据、命令和异步借用生命周期 | 不编入固件 |

核心仅公开：

```c
bool vofa_send(const float *values, size_t count);
void vofa_parse(char *frame, size_t length);
void recorder(void);
CommandResult command_parse(const char *name, const char *valueText);
```

recorder 通过头文件内既有的 `g_recorderBlocks[2]` 交付地址、有效 float 数量和 ready 状态，不增加读取、释放或回调函数。`command_execute` 和动作声明归业务头；路由采用链接绑定，不需要初始化或运行期注册。

## 数据与命令调用链

```text
采集上下文 → recorder() → bufferA / bufferB → 完成块 addr/count/ready
主循环 → vofa_send(block.addr + offset, mDecodePtrCount) → VOFA_SEND
       → true 后推进；整块读完清 ready 归还

接收层组好完整可写帧 → vofa_parse(frame, length)
                   → VOFA_COMMAND(name, valueText)
                   → command_parse(name, valueText)
                   → mCommands 名称查找与类型转换
                   → command_execute(command, value)
                   → 写业务 RAM 或调用表中动作
```

这条 `command_parse → command_execute` 链就是当前命令提交与路由关系，没有额外的 command_route 转发层。接收缓冲、组帧、按端口选择协议和同批多帧调度归应用/接收层；VOFA 不读串口、不保存半行，不判断业务状态。其他文本协议可在拆出名称和值后复用 command；二进制协议仍需自己的帧解释及命令定位，不能直接把其线协议等同 VOFA。

## 移植三步

1. 复制六个核心文件，把三份 C 文件加入现有工程；使用 C99 和支持所述编译器内建的 GNU 兼容工具链。
2. 在 `vofa.h` 将 `example_transport_send` 换成真实发送函数，并通过原 `VOFA_SEND` 宏绑定；默认小端，若目标 float 为大端，将 `VOFA_BIG_ENDIAN` 设为 1。`VOFA_COMMAND` 默认绑定 `command_parse`。
3. 替换 `command.c` 标记的工程业务绑定区：业务声明、`mCommands`、`mDecodePtrTbl` 及倍率/权限。实现同签名 `command_execute` 和表中动作；应用负责调用采集、传入完整帧、消费并归还完成块。

每个命令只维护类型、名称、地址/动作和可写状态。范围或限幅由实际业务消费端处理，普通参数直接保存原始请求；不用给每个参数增加 setter。示例命令使用 demo.*，演示 4 种 RW、只读、受限状态和两种动作；它们不是 CT2001 的 axis.* 命令替代品。

整数经 `strtoll` 保持完整 int64 精度，不经过浮点；业务执行器继续核对目标存储宽度。浮点经 `strtof`，拒绝溢出、非有限值和尾随字符。只读拒绝、writeStates 的解释、状态切换和需要的临界区由业务实现负责，示例无硬件临界区。不要把示例执行器直接视为任意产品的并发保护实现。

采集表一行一个类型/地址/倍率，实际表项数用 sizeof 推导。当前示例覆盖 7 种源类型；观测输出统一为 float，int64 观测值转换会有精度舍入，控制命令的 int64 精度不受影响。增加观测变量只需加表项，无需维护另一份通道数。

## 发送合同与最小状态

`VOFA_SEND(addr, len)` 可以绑定同步复制或异步借用的实现，不限定硬件发送方式：

- 返回 false 时不保留本次新指针，不启动本次新段。
- 异步实现一次只借用一段，只有前段不再读取源后才接受下一段；同步实现可在接受时完成复制。
- 内存可见性、设备可读性和硬件长度/对齐等要求由发送适配保证。

`vofa_send` 返回 false 时，可能已经提交本帧的一部分。调用方必须保持同一地址、count 和内容继续重试；帧完成前不插入其他发送，也不切换端口或协议。返回 true 表示尾部已接受、原采集数据不再被读取，可以推进或归还源块；固定静态尾部仍可在发送中。接口当前支持一个在途逻辑帧；应用可在完成后选择下一端口，不预置多口并发对象或队列。

| 内部状态 | 必要用途 |
| --- | --- |
| 小端 `tailPending` | 仅 1 字节，保证数据段被接受后从帧尾继续，不重发数据 |
| 大端 `sentValues` | 记录已接受的值，帧尾接受后清零；槽号由 `sentValues & 1u` 推导 |
| 大端 `convertedWords[2]` | 共 8 字节，一个可被发送接口读取，另一个准备下一值 |

两种端序分支不会同时编译。默认小端直接发送调用方数据，没有完整帧缓冲或转换副本。大端逐值换序后提交；两个槽用于保持源寿命，不能在仍被读取时改写同一个槽。固定尾部线序为 `00 00 80 7F`。

## 采集双缓冲与调用示例

两个私有 float 数组各由 `RECORDER_BUFFER_SIZE` 管理，当前每个 256 个 float（1024 字节），共 2048 字节。完成块的 addr 分别指向 A/B 数组，不是另外的数据副本；count 仅在 ready 为 true 时表示有效 float 数。每块只发布完整采样组，未用尾部不发送。ready 未清时不覆写，两块都占用时忽略新采样组；分频由调用方管理。

采集上下文只在源值更新后调用：

```c
recorder();
```

主循环的块索引和偏移跨循环保存，按当前组格式消费：

```c
unsigned readBlock = 0u;
size_t offset = 0u;

for (;;) {
    RecorderBlock *block = &g_recorderBlocks[readBlock];

    if (block->ready) {
        __atomic_signal_fence(__ATOMIC_ACQ_REL);
        if (vofa_send(block->addr + offset, mDecodePtrCount)) {
            offset += mDecodePtrCount;
            if (offset == block->count) {
                __atomic_signal_fence(__ATOMIC_ACQ_REL);
                block->ready = false;
                offset = 0u;
                readBlock ^= 1u;
            }
        }
    }
}
```

recorder 自身的两个访问顺序约束集中在一行私有 `RECORDER_BARRIER()` 宏，使用 `__atomic_signal_fence(__ATOMIC_ACQ_REL)`；不携带 hal_irq.h，不修改中断状态或新增 CPU 屏障/运行期调用。消费者同样保持“先确认 ready，再读数据；全部读完后才归还”的访问顺序。该方案针对单核 ISR/主循环；没有声明跨核或通用多线程同步。

接收层得到一个完整帧后调用：

```c
char frame[] = "demo.position:9007199254740993";
vofa_parse(frame, sizeof(frame) - 1u);
```

length 不含末尾 NUL，`frame[length]` 必须是缓冲内可写 NUL。解析原地修改并同步提交，不保存输入；同批多行由接收/应用层逐帧调用。业务要求暂停同批命令时，由应用检查自己的状态转换后暂停取帧，VOFA 不参与。

## 独立验证

需要 Python 3 和本机 GNU 兼容 C 编译器，无需任何电机 SDK：

```powershell
python -B -X utf8 ./run_tests.py
# 或显式选择编译器
python -B -X utf8 ./run_tests.py --cc C:/msys64/ucrt64/bin/gcc.exe
```

脚本把完整六文件复制到系统临时目录，分别编译三份核心、业务示例和测试，再链接运行；不提取函数冒充模块编译。全部产物自动清理，目录中不保留可执行文件。

验证使用严格 C99、O3、strict-aliasing、Wall/Wextra/Werror，覆盖完整 int64、类型宽度、RO/状态/动作、所有采集类型倍率、双块发布/归还、原地址异步借用、数据与尾部拒绝重试、大端奇偶帧/在途槽/空帧及源数据保持。大端测试模拟对象字节表示，未声称真实大端硬件验收。

该独立测试尚未登记到上层仓库 Full 自动发现中，收纳或修改后须显式执行本命令。宿主与目标编译通过不代表板上发送时序、缓存行为或采样 WCET 已验收。

## 来源与适用范围

从 CT2001_MSDK 的 user/Wave 与 user/Motor 本轮开发候选收纳（2026-10-29）；保留 HU JIAXUAN 文件头。来源是未提交的已验证工作树，不把 base commit 当成包含本次变更的发布提交。

六个核心按目标仓库的 C99 规则统一排版，核对格式整理前后 C 词法单元一致。`vofa.c`、`recorder.c`、`recorder.h`、`command.h` 的逻辑与来源工程相同；`vofa.h` 仅改发送函数注册，`command.c` 仅替换既有工程业务绑定区，完整命令解析实现保持。没有复制厂商 SDK、底层驱动、Motor 类型或 CAN/EtherCAT 实现。

适用合同为 8 位字节、IEEE754 float32、GNU 兼容编译器及单核生产/消费；其他编译器只在确认内建顺序约束后适配，不声称 ISO C99 任意平台或多核即插即用。源工程未声明统一开源许可，本次保留原作者与来源，不替导入源码重新授予许可。
