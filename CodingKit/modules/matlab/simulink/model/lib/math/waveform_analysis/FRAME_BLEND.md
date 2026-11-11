# 同坐标参考混合验证

- 模型文件：src/ClarkePark.slx、src/FrameBlendTest.slx。
- 参数文件：parameter/blend_test_parameters.m；第二场景固定局部随机种子42，参数/输入随MAT保存。
- 采样周期：50µs；被测块本身为继承采样周期的无状态运算。
- 求解器/步长：FixedStepDiscrete / 50µs。
- 工况：显式13行和随机500行两个场景，不将513个向量计作513个整机工况。
- 数据文件：waveform_analysis/frame_blend_results.mat、waveform_analysis/frame_blend_metrics.json、waveform_analysis/frame_blend.png与frame_blend.svg。

R2026b Update 1下两个场景通过。显式样例覆盖beta=0/1、±90°坐标差、±π边界、未包角多圈输入、权重越界、禁能与复位。随机场景增加不同方向/幅值、权重和标志组合。输入逐点与请求一致，无非有限输出。

| 场景 | 向量数 | 同一物理alpha/beta坐标的最大误差 |
|---|---|---|
| explicit_examples | 13 | 3.1086e-15 A |
| randomized_vectors | 500 | 3.5527e-15 A |

比较时把实际reference按theta_control旋到物理坐标；预期值分别把start和closed按各自坐标旋到物理坐标后加权。两者在1e-12A容差内。另检查输出范数不超过夹取后权重对应的输入范数加权和，以及禁能/复位输出严格为0。没有要求不同坐标中的d/q分量数字直接相等。

正式src路径重新加载后的两个场景通过。原Clarke/Park正逆变换13项同时回归通过，最大往返误差3.55e-15A、解析对照2.31e-14A；原四个块的接口和行为继续保留。新块的隔离源函数刷新、测试台重建和正式路径加载回调也已实际运行。

[frame_blend.png](frame_blend.png)中每一拍是一组独立代数输入，电流参考的阶跃不是Plant电流响应。AnglesScope可以显示超过±π的原始角度，BlendScope显示夹取前beta；内部fraction没有独立Scope通道。当前没有single、SIL、C2000执行时间或实机电流连续性证据；完整接管过程由App继续验证。

[模块入口](../README.md) · [搭建与运行](../build_process/FRAME_BLEND.md) · [参数/Scope](../parameter/FRAME_BLEND.md)
