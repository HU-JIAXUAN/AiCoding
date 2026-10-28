# I-f 软件电角度

模块只根据电频率积分虚拟电角度。运行状态就是调用方持有的一个 `double` 变量；
定位、频率斜坡、电流给定、电流环和 SVPWM 分别由调用方或现有模块负责。
`if_controller.c` 用显眼的中文分区注释标明定位、斜坡、电流 PI、SVPWM 的接入位置；
这些部分只保留说明，不增加对应算法、状态或空函数。

## 接口与调用

[公共头](src/if_controller.h)只声明两个函数：

```c
void if_init(double *phaseRad, float initialAngleRad);
float if_crtl(double *phaseRad, float frequencyHz, float periodS);
```

```c
double phaseRad;
float frequencyHz = 58.333333f;
float periodS = 0.0001f;
float thetaRad;

if_init(&phaseRad, 0.0f);

/* 每个控制周期调用，thetaRad 交给外部电流环 */
thetaRad = if_crtl(&phaseRad, frequencyHz, periodS);

/* 直接修改 RAM，下一拍使用新频率 */
frequencyHz = -58.333333f;
```

一次调用先积分，再返回归一化的电角度。零频保持角度，正负频率决定相位推进方向。
每台电机各持有自己的相位变量；同一变量由调用方独占访问。

输入频率是电气 Hz。电机轴速度由调用方按 `frequencyHz = motorRpm * polePairs / 60` 换算；
输出轴速度还需先乘减速比。这里不保存电机参数，不确认真实转子是否跟随。

## 数值与边界

- 初始角和返回角为 rad，初始角位于 `[0, 2*pi)`。
- 输入有限，周期大于零，`abs(frequencyHz)*periodS < 0.5`，允许每拍直接更新频率或周期。
  这些调用前提由调用方保证，模块不增加错误处理。
- 内部累计相位使用至少 binary64 精度的 `double`，每拍有界环绕，输出使用 `float`。
  接近整周期时返回值可能舍入到整周期，因此将该输出折回零，内部累计相位仍保留精度。
- 直接改频率会改变下一拍相位增量。需要平滑改速时，外部斜坡先产生实际电频率再调用 IF；
  D 轴定位及 D→Q 交接也由外部启动流程组织。
- 模块只生成虚拟电角度，不接收电流或母线，不计算 PI、调制或占空比，不控制功率启停。

## 构建与验证

生产接入只需 `src/if_controller.c` 和 `src/if_controller.h`，无需其他控制库或数学库函数。
`if_controller` CMake target 保持原名；旧的完整控制器结构体及三参数对象调用已移除。

```text
cmake -S CodingKit/modules/common/controller/IF -B build-host/if -DBUILD_TESTING=ON
cmake --build build-host/if
ctest --test-dir build-host/if --output-on-failure
```

回归覆盖正反环绕、零频、RAM 在线改频率及周期、重新初始化、独立实例，
以及正负微频的长期累计，使用独立高精度参考核对结果。
本轮验证通过：统一控制器 Debug 12 项 CTest、IF 独立 Release 1 项 CTest，
以及严格 C99 的 O0/O2 相位回放。正负 0.0001 Hz、正负 10 Hz 各累计百万拍，
相对独立 long double 参考的内部最大误差小于 `8.8e-11 rad`，float 输出最大误差小于 `2.39e-7 rad`。
构建与测试日志保留在仓库 `test-results/if-phase-20261028/`；不沿用此前完整控制器的测试结论。
目标构建和目标处理器上 double 运算耗时尚未测量。
