# Signal generator

按固定时间间隔计算波形，用于电流、转矩、速度等给定的测试和辨识。模块只计算数值，实际加到哪里、用什么单位，由调用程序决定。

先分清两个结构体：

| 结构体 | 谁来填写 | 用来做什么 |
|---|---|---|
| `SignalGenConfig` | 用户 | 选择波形，设置周期、幅值、频率等参数 |
| `SignalGen` | 模块 | 保存一路波形的运行进度，以及最近一次的输出值、频率和状态；一路使用一个变量 |

**`SignalGen`必须一直保留，不能在每次中断进入时重新定义或初始化。** 两路波形各用一个`SignalGen`变量；不要在不同任务或中断中同时修改同一个变量。

## 源码怎样读

signal_gen_update只按wave选择并调用下面11个函数，计算过程在对应函数里：

| 波形 | 计算函数 |
|---|---|
| 直流、阶跃 | generate_dc、generate_step |
| 正弦、方波、三角、梯形 | generate_sine、generate_square、generate_triangle、generate_trapezoid |
| 线性扫频、对数扫频 | generate_linear_chirp、generate_log_chirp |
| PRBS、噪声、多正弦 | generate_prbs、generate_noise、generate_multisine |

每个函数先算当前输出，再更新本路的相位或随机数。prepare_step只共用暂停/结束和计时，
save_output只共用乘幅值、加偏置、保存结果；没有函数指针表或额外的调用框架。
所有计算都在同一个.c文件里，参数说明在.h文件里。

## 先产生一个正弦波

下面的输出是10Hz、峰值0.2A、偏置0A的正弦。上电时调用一次`current_signal_init()`，返回`true`后，再每隔50μs调用`current_signal_step()`。

```c
#include "signal_gen.h"

static SignalGen currentSignal; /* 这一路波形一直使用同一个变量 */

bool current_signal_init(void)
{
    SignalGenConfig cfg = signal_gen_defaults(0.00005); /* 50 us，20 kHz调用 */
    cfg.wave = SIGNAL_GEN_SINE;
    cfg.frequencyHz = 10.0;
    cfg.amplitude = 0.2; /* 单位由调用者约定；这里是A */
    cfg.offset = 0.0;
    return signal_gen_init(&currentSignal, &cfg) == SIGNAL_GEN_OK;
}

SignalGenReal current_signal_step(bool enable)
{
    return signal_gen_update(&currentSignal, enable);
}
```

默认配置为零幅值DC。先调用`signal_gen_defaults()`，再改需要的参数，可以避免遗漏其他字段。完整CSV例子见[minimal_example.c](examples/minimal_example.c)。

## 公共参数怎样填

| 字段 | 含义与例子 |
|---|---|
| `wave` | 波形类型，见下表 |
| `periodS` | 每次计算间隔，单位s；20kHz填`0.00005`，必须与实际调用周期一致 |
| `amplitude` | 相对偏置的最大变化幅度，必须非负；不是峰峰值，也不是有效值 |
| `offset` | 输出中心值，单位与幅值相同；偏置3、幅值2时，输出范围为1～5 |
| `frequencyHz` | 周期波每秒的完整周期数；PRBS中是码元更新率，噪声中是随机值更新率 |
| `phaseCycles` | 开始时处于周期的哪个位置；一周为1，`0.25`为90° |
| `durationS` | 输出多长时间，单位s；`0`表示一直输出；正数按采样间隔换算为输出次数 |
| `fadeInS / fadeOutS` | 开始时逐渐增加幅值、结束前逐渐减小幅值，单位s；`0`关闭，偏置不变 |

例如`amplitude=0.2, offset=0`表示±0.2；同样的数字可表示A、N·m或rad，模块不会进行单位换算。

渐入渐出使用平滑的半余弦曲线。渐出要求`durationS>0`，两段时间之和不能超过持续时间。例如输出4s，可设置前0.2s渐入、最后0.2s渐出。

## 11类波形与专用参数

只需要填写所选波形的参数，其他波形的参数不会参与计算。

| `wave` | 需要填写什么 |
|---|---|
| `SIGNAL_GEN_DC` | 无额外参数，输出`offset + amplitude`；可加渐入渐出 |
| `SIGNAL_GEN_STEP` | `step.atS`为切换时刻；`step.before/after`为切换前后的幅值比例，范围−1～1 |
| `SIGNAL_GEN_SINE` | `frequencyHz`和`phaseCycles`；初相0时从偏置开始向上 |
| `SIGNAL_GEN_SQUARE` | `frequencyHz`、`duty`；`duty=0.3`表示一个周期内30%为高电平，其余为低电平 |
| `SIGNAL_GEN_TRIANGLE` | `frequencyHz`；初相0时从最低值上升，半周期后到最高值 |
| `SIGNAL_GEN_TRAPEZOID` | `frequencyHz`与`trapezoid.rise/high/fall`：上升、高平台、下降各占周期的比例，剩余部分为低平台 |
| `SIGNAL_GEN_CHIRP_LINEAR` | `chirp.startHz/endHz`和`durationS`；频率随时间均匀变化 |
| `SIGNAL_GEN_CHIRP_LOG` | 同上，但起止频率均须大于0；相同时间内频率按相同比例变化 |
| `SIGNAL_GEN_PRBS` | `frequencyHz`为码元更新率；`seed`为1～32767，输出为高低电平组成的PRBS15序列 |
| `SIGNAL_GEN_NOISE` | `frequencyHz`为随机值更新率；`seed`为非零整数，输出近似均匀噪声，更新之间保持不变 |
| `SIGNAL_GEN_MULTISINE` | `multisine.count`为正弦数量，最多16个；每项填写频率、幅值权重和初相 |

阶跃例子：`offset=3, amplitude=2, step.before=-1, step.after=1, step.atS=0.5`，输出前0.5s为1，之后为5。

梯形例子：`frequencyHz=10`时周期为0.1s；`rise=0.25, high=0.25, fall=0.25`，则上升、高平台、下降、低平台各持续0.025s。升降比例必须大于0，三项之和不超过1。这是周期梯形波，不是点到点运动轨迹。

扫频例子：

```c
cfg.wave = SIGNAL_GEN_CHIRP_LOG;
cfg.chirp = (SignalGenChirp){2.0, 200.0};
cfg.durationS = 5.0; /* 5s内从2Hz扫到200Hz */
```

模块通过积分频率计算相位，支持上扫、下扫和等频。重新扫一次可调用`signal_gen_reset()`。

多正弦例子：

```c
cfg.wave = SIGNAL_GEN_MULTISINE;
cfg.amplitude = 1.0;
cfg.multisine.count = 3;
cfg.multisine.tones[0] = (SignalGenTone){7.0, 1.0, 0.0};
cfg.multisine.tones[1] = (SignalGenTone){11.0, 2.0, 0.25};
cfg.multisine.tones[2] = (SignalGenTone){19.0, 1.0, 0.0};
```

每项依次为频率Hz、权重、初相。权重1、2、1将总幅值分成0.25、0.5、0.25，三项相加的变化幅度不超过1。负权重表示该项反向；所有权重为0或绝对值之和无法计算时，配置会被拒绝。各项初相还会加上公共`phaseCycles`。

PRBS和噪声使用相同种子时，复位后可以重现相同序列。噪声发生器没有频段滤波，需要带限噪声时应另外接滤波器。

## 初始化、暂停与重播

| 操作 | 实际行为 |
|---|---|
| `signal_gen_init(&gen, &cfg)` | 检查参数，然后把参数保存到发生器，从初相和第0次输出开始 |
| 修改原来的`cfg`变量 | 已运行的发生器不会随之改变 |
| `signal_gen_cfg(&gen, &cfg)` | 参数正确才替换原配置并重新开始；参数有错就继续保留原配置 |
| `signal_gen_reset(&gen)` | 使用原参数从头重播，相位、计时和随机序列一并复位 |
| `signal_gen_update(&gen, false)` | 返回偏置，`gen.status`为OK；暂停计时和相位，再次传`true`时继续 |
| 到达`durationS` | 后续返回偏置，`gen.status`为SIGNAL_GEN_DONE；reset或重新配置后才能重播 |

每次计算先给出当前时刻的值，再走到下一个采样时刻；第一次对应`t=0`。暂停期间不计入持续时间。

停止使能会立即回偏置，不会等待渐出完成。重新配置也不保证输出连续。直接用作位置或速度参考时，调用程序需要安排平滑的启停。

## 输出和状态怎么看

`signal_gen_update()`直接返回本次波形值，同时把结果保存在`gen`中，调试时按需读取：

| 字段 | 含义 |
|---|---|
| `gen.output` | 刚才返回的输出值；单位与幅值、偏置相同 |
| `gen.currentFrequencyHz` | 刚才输出点的频率；扫频时变化，DC/阶跃/多正弦为0，PRBS/噪声为换码/刷新率 |
| `gen.phaseCycles` | 刚才输出点的相位，以一周为1；多正弦为0，PRBS/噪声表示当前码元内的位置 |
| `gen.elapsedS` | 刚才输出点对应的运行时间，s；首点为0，不含暂停 |
| `gen.active` | 是否正在产生波形；暂停或结束时为false，输出回偏置 |
| `gen.finished` | 有限时长是否已经结束；仅暂停不会变成true |
| `gen.status` | 最近一次update的状态：OK为正常/暂停，DONE为结束，负值为出错 |

**波形值本来就可以为负数，不能用update返回值小于0判断错误。** 需要区分正常输出和错误时，读取`gen.status`。运行出错时返回偏置；传入空指针或未初始化时返回0。空指针没有可读取的状态，因此使用前必须成功初始化。

`init/cfg/reset`仍返回状态码，应检查其返回值。额外扰动通常设置`offset=0`，暂停或结束时叠加量自然为0；用作绝对给定时，偏置就是暂停/结束值。运行中只通过公开函数修改发生器。

## 移植与检查

复制`signal_gen.c/.h`，按C99编译并链接标准数学库即可。也可以用CMake的`add_subdirectory()`引入，并链接`signal_generator`。

模块不访问硬件、不申请动态内存。C文件、头文件及示例/测试为CP936、LF、无BOM，README、Python与CMake为UTF-8。

### 一处切换float/double

头文件只用下面一个宏选择幅值、频率、比例和输出的类型，默认`float`；需要双精度时把这一行的`float`改为`double`：

```c
#define SIGNAL_GEN_REAL_TYPE float
```

`SignalGenReal`是该宏对应的类型，`signal_gen_update()`直接返回此类型。相位、初相和时间始终保留`double`，避免长时间累加误差与结束时刻偏差。C99的`<tgmath.h>`按参数类型自动选用`sinf/sin`、`cosf/cos`、`expf/exp`等函数，未增加波形函数或精度处理框架。

也可以在整个工程统一加编译选项`-DSIGNAL_GEN_REAL_TYPE=double`；使用CMake时在引入模块后写一行`target_compile_definitions(signal_generator PUBLIC SIGNAL_GEN_REAL_TYPE=double)`。模块与所有调用方必须使用相同设置，修改后全部重新编译，因为结构体布局和返回类型会变化。

单精度FPU上，双精度通常需要软件运算；实际项目的RZ/T2M与F28388D则具备双精度硬件，不能统一认定double很慢。正弦、指数等仍取决于库与编译器；本模块尚无目标芯片耗时测量。[Arm M4浮点说明](https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/10-useful-tips-to-using-the-floating-point-unit-on-the-arm-cortex--m4-processor)、[RZ/T2M数据手册](https://www.renesas.com/en/document/dst/rzt2m-group-datasheet)、[F28388D数据手册](https://www.ti.com/lit/ds/symlink/tms320f28388d.pdf)。

正弦、周期波基频、扫频及多正弦音调必须低于采样频率的一半；PRBS码元和噪声更新率最多为每次调用更新一次。方波、阶跃等还包含高次谐波，基频合格不表示边沿和所有谐波都能准确产生。

在包含`CodingKit`目录的工程根目录，只检查本模块：

```powershell
python -B "CodingKit/modules/common/controller/Signal generator/run_tests.py" --cc gcc --output work/signal-generator-build
```

GCC不在PATH时，将`--cc`换成它的完整路径。脚本编译模块、测试及CSV例子，分别检查`float/double × -O0/-O2`四种配置，输出JSON/CSV和日志。它不运行Hook或全仓测试。

也可独立构建：

```text
cmake -S "CodingKit/modules/common/controller/Signal generator" -B work/signal-build -DSIGNAL_GEN_BUILD_TESTS=ON
cmake --build work/signal-build
ctest --test-dir work/signal-build --output-on-failure
```

这些是宿主检查，实际注入幅值、采样时序、功率级和电机响应仍在使用它的项目中验证。
