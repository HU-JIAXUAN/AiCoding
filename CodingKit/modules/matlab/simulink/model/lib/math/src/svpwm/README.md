# SVPWM

| 算法 | 规则 | 模型 |
|---|---|---|
| [七段式](seven_segment/README.md) | 居中 Min–Max 注入，两个零矢量等时 | [SvpwmSevenSegment.slx](seven_segment/SvpwmSevenSegment.slx) |
| [五段式](five_segment/README.md) | 最小相低侧钳位，使用零矢量 `000` | [SvpwmFiveSegment.slx](five_segment/SvpwmFiveSegment.slx) |

两个库均导出 `SVPWM` 块。三个输入为标量 `alpha`、`beta`、`vdc`，单位 V，要求输入有限且 `vdc > 0`。输出依次为 `duty_a`、`duty_b`、`duty_c`、`common_mode`，前 3 个输出为 0～1 的占空比，最后一个为限幅前注入的共同分量，单位 V。库块继承调用采样周期。

[SvpwmComparisonTest.slx](SvpwmComparisonTest.slx) 直接运行两种库块，记录 αβ、母线、两组占空比和共同分量。段数对应周期内占空比保持、三相共用同相中心对齐载波时的理想门极序列。在扇区边界、零指令或占空比饱和时，部分段可退化。

直接打开对照模型并点击 Run。测试周期为 100 μs，使用固定步长离散求解器。`ModulationScope` 和 `trace` 的列顺序相同，1–3 为 αβ 和母线，4–7 为七段式三相占空比和共同分量，8–11 为五段式对应输出。修改测试参数后重新加载模型。

批量核对时，把 Math 的 `waveform_analysis/` 加入 MATLAB 路径并运行 `run_svpwm_validation`。两种库和对照模型的重建入口见 [build_svpwm_models.m](../../build_process/build_svpwm_models.m)。

[公式与模型对应](../../docs/公式推导.md) · [测试参数](../../parameter/svpwm_test_parameters.m) · [对照验证](../../waveform_analysis/run_svpwm_validation.m)
