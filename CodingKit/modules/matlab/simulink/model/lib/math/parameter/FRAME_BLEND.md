# BlendDQ 参数、信号和 Scope

## 配置参数

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| blendTestCfg.Ts | 50e-6 | s | 测试台步长；库块本身继承调用周期，[blend_test_parameters.m](blend_test_parameters.m) |
| blendTestCfg.Inputs | 13×9显式表 | 逐列SI | 两组参考、角度、权重与标志，定义文件同上 |
| blendTestCfg.Duration | 0.0006 | s | (行数-1)*Ts，定义文件同上 |
| randomized_vectors局部种子 | 42 | 1 | 500行批量夹具，由[验证脚本](../waveform_analysis/run_frame_blend_validation.m)创建，不修改全局随机流 |

BlendDQ不依赖配置Mask或模型工作区变量。测试模型的配置与输入由加载回调写入自身工作区，不需要base workspace。

## 输入信号

| 端口/名称 | 单位 | 类型 | 来源/计算或用途 |
|---|---|---|---|
| 1 start_current | A，2元素[d;q] | double[2] | 输入表1:2列，属于theta_start坐标 |
| 2 closed_current | A，2元素[d;q] | double[2] | 输入表3:4列，属于theta_control坐标 |
| 3 theta_start | 电角rad | double | 输入表5列，启动电流向量坐标 |
| 4 theta_control | 电角rad | double | 输入表6列，输出所用坐标 |
| 5 beta | 1 | double | 输入表7列，内部夹到[0,1] |
| 6 enable / 7 reset | 1 | double | 输入表8/9列；enable<0.5或reset>0.5时输出0 |

输入为有限数值，两组向量使用相同单位。角度可以已包角或未包角。所有输入应属于同一控制拍，调用方处理数据年龄。首版实测类型double；源码like-cast不记为single验证。

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| delta | rad，无状态 | Blend函数 | theta_start-theta_control |
| fraction | 1，无状态 | Blend函数 | min(max(beta,0),1) |
| rotation | 2×2，无状态 | Blend函数 | 从启动坐标转到控制坐标 |
| transformed_start | A，无状态 | rotation*start_current | 与closed_current在同一坐标中才可加权 |

没有积分器、滤波器或复位记忆。

## 输出信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| reference | A，2元素[d;q]列向量 | double[2] | Blend函数唯一输出，控制坐标中的电流参考 |

记录trace列1:9为输入原表，10/11为reference_d/reference_q，时间在trace.time。MAT保存后的records.<case>.trace为N×11。

## Scope 通道

FrameBlendTest实际有以下3组Scope，Mux按表顺序展开。

| Scope | 序号 | 名称 | 来源 | 单位/记录类型 | trace列 / 观察内容 |
|---|---|---|---|---|---|
| ReferenceScope | 1、2 | reference_d、reference_q | BlendDQ输出1元素1、2 | A / double | 10、11；输出参考，不是测量电流 |
| AnglesScope | 1、2 | theta_start、theta_control | inputs输出3、4 | rad / double | 5、6；两组坐标方向 |
| BlendScope | 1 | beta_raw | inputs输出5 | 1 / double | 7；夹取前权重，不是内部fraction |
| BlendScope | 2、3 | enable、reset | inputs输出6、7 | 1 / double | 8、9；门控条件 |

输入两组电流列1:4仅进入ToWorkspace，没有独立Scope；内部delta/fraction/rotation未送Scope，不能把它们列为已有通道。批量执行后Scope显示随机场景，显式案例图另保存在waveform_analysis。

[模块入口](../README.md)
