# Sigmoid SMO搭建过程与作用

主要参考《永磁同步电机无位置传感器控制》12.3.3，印刷313/PDF342页式(12.24)。在原observer_smo功能目录新增独立的SigmoidSlidingModeObserver库与SigmoidSlidingModeObserverTest，不改已有基础SMO。改进内容是平滑sigmoid注入、取消显式EMF低通；不把它称为TI eSMO。

1. 新建Library，用model_edit创建SigmoidSMO导出子系统。先建立cfg/trackerCfg两个可求值Mask，再设置7个输入的cfg.Ts。库默认分别调用本地SMO和PLL工厂；Test实例的Mask填写sigmoidCfg、pllCfg。本地PLL入口同步周期和最小幅值，避免直接拖库块时沿用另一套幅值门限。
2. CurrentMemory用4元素Unit Delay保存两轴预测电流、上一方向和故障。没有persistent，也不把配置存入Base Workspace。当前电压只进Predict；Measure不接电压，避免电压→本拍估角→控制电压的直接代数环。
3. Measure用[src/sigmoid_smo_measure.m](../src/sigmoid_smo_measure.m)计算i_hat-i，再用K·tanh(a·error/2)逐轴注入。它等价于书中的logistic表达式，大输入时避免直接exp溢出。输出相位、幅值、残差和复位/故障诊断。
4. Predict用[sigmoid_smo_predict.m](../src/sigmoid_smo_predict.m)实现精确RL离散更新A·i_hat+B·(u-z)，写下一拍。direction=0或变更时先清电流状态；输入/数值故障锁存，只有禁能或复位清除。
5. 链接AngleTracking/PLL，输入方向修正后的相位及注入幅值。没有另加EMF低通和相关相移补偿。valid还检查同方向最低/最高估速和残差；未知方向不发布有效位置。
6. Test从已有smo_fixture取得独立连续SPMSM电压/电流，电压按区间起点采样，真实角/速只送评价。9列输入、14个输出、包角误差组成24列trace，6组Scope逐项接同一来源。
7. model_read在每个作用域编辑前后检查，model_check核对导出子系统内部和Test根层。Library根层的7输入/14输出是供调用方连接的端口，那里没有调用者；不能为消除这些21个外部未连接提示而加假激励。完整连线检查针对SigmoidSMO内部及实际Test实例。
8. 保存库和Test后关闭编辑器。批量验证用SimulationInput，默认Run可从本地M文件加载。源码改变后，在独立副本中重新运行[build_sigmoid_smo.m](build_sigmoid_smo.m)；脚本拒绝覆盖已有SLX。

状态、离散推导及有限斜率残差见[公式文档](../docs/公式推导.md)。M源重新搭建、24列默认波形一致性、实例隔离和正式路径检查结果登记在[分析](../waveform_analysis/SIGMOID_ANALYSIS.md)。

原10mA噪声工况没有达到95%连续资格覆盖，原始数据保留；没有调宽PLL阈值。5mA用作正常噪声工况，10mA单独作为方案限制，不将22项全部通过解释为22个可用运行点。
