# 带使能、复位的离散速度给定

HFI闭环重启试验暴露了具体问题：原RateLimiter在位置获取期间仍保留8 rad/s给定；位置重新有效时速度PI立即产生约.665 A的q轴参考，扰动HFI资格。这里补充可复用`MotionControl/SpeedProfile`，调用方在控制未接通时清除其状态，接通后重新按斜率建立给定。

搭建脚本为[build_speed_profile.m](build_speed_profile.m)。它向现有MotionControl库追加新块，原Position、Speed范围的读取快照保持一致。

1. 建立reference、enable、reset三个输入，limited、held_state两个输出；Mask配置引用实例的profileCfg。
2. 先对请求限速，再与UnitDelay旧参考相减，得到请求增量。
3. 对增量按`[−FallingRate·Ts,RisingRate·Ts]`限幅，与旧参考相加。
4. 用`enable&&!reset`选择新参考或明确的0；这个输出同时写回UnitDelay。禁能期间每拍写0，所以任意时刻重新使能都从0按固定每拍增量爬升。
5. 另一路输出本拍旧状态用于观察，禁能/复位时也显示0。所有状态、输出及时间含义见[参数说明](../parameter/PROFILE_PARAMETERS.md)。

这是标准块组成的离散给定积木，不包含速度PI或电机，也不代替实际运动轨迹。下降斜率和上升斜率可以分别配置。清零状态时的瞬时给定变化与有效运行时的斜率限制分别验收。

在R2026b中，从本模块目录运行：

```matlab
addpath('build_process','parameter','waveform_analysis');
open_system(fullfile('src','SpeedProfileTest.slx'));
initialize_speed_profile_test('SpeedProfileTest');
out=sim(Simulink.SimulationInput('SpeedProfileTest'));
```

修改M文件默认值后重新初始化；一次试验通过SimulationInput覆盖profileCfg、profileTestCfg、testStim。后台批量入口为[run_speed_profile_validation.m](../waveform_analysis/run_speed_profile_validation.m)，结束后关闭测试模型。只打开当前需要看的Scope，用完关闭编辑器。
