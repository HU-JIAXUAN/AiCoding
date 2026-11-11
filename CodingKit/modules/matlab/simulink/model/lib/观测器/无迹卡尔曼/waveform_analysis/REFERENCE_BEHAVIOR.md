# 本机官方UKF对象的协方差比较范围

核对环境为numerical_metrics.json登记的MATLAB R2026b安装；所有调用均使用公开unscentedKalmanFilter/predict/correct，没有修改MATLAB安装文件。

## 可手算的案例

令四状态均值为0、P=I、过程Q=0，变换为[x1²,x2,x3,x4]；Alpha=1、Kappa=0。9个sigma点的x1分别为中心0、正负2及其余0；均值权重为0和1/8，故第一状态均值为1。其他点对第一状态的中心化平方和为3，中心点贡献为Beta，所以公开权重公式给出的变换方差为3+Beta。这是所选sigma分布的UT协方差，不把它当作真实高斯变量平方的精确方差。

| Beta | 公开权重计算的方差 | 本机公开对象返回 | 处理 |
|---|---:|---:|---|
| 0 | 3 | 2 | 保存差异，不作本模块通过基准 |
| 1 | 4 | 4 | 两个非对角P案例用于独立公开对象比较 |
| 2 | 5 | 4 | 保存差异，不为匹配它而修改权重公式 |

结果及完整版本保存在[numerical_metrics.json](numerical_metrics.json)。本机源文件核对将差异定位到中央sigma点协方差更新路径：参数计算按公开公式给出权重，平方根更新路径对中央点选择加/减更新；该案例没有体现权重幅值。这里只记录本次安装及参数下的行为，不推断所有版本或工况。

## 本模块如何核对

[run_ukf_numerical_validation.m](run_ukf_numerical_validation.m)为SPMSM轴向sigma分布推导闭式三角矩，包括Alpha/Beta/Kappa项、速度/角交叉协方差与Q，不通过逐点循环复算被测函数。8项解析比较覆盖正反向、跨±π、Alpha=.2、Kappa=2、数值尺度和25 μs。另以Beta=1比较公开对象的两个非对角P预测，其中一个跨π，参考过程保留展开角后再包角比较。

两个非对角P案例还核对默认Beta=2：保持相同sigma点和均值，Beta从1增加到2只使中央协方差权重增加1，故期望P增加`(f(x中心)−均值)·(f(x中心)−均值)ᵀ`，角差按局部包角处理。用这一解析权重差与公开Beta=1结果组合，核对默认Beta=2的非对角预测；不宣称与本机公开Beta=2返回值一致。

线性电流测量还与公开对象correct单独比较，支持复用既有Joseph校正。其余检查针对可修复协方差、不可修复协方差、sigma角范围、合成圆周歧义、无效配置、禁能、非有限电压和single内核。21项为纯M数值检查，不计为Simulink物理MIL、SIL或C2000时间证据。

## 来源

- [MathWorks公开UT算法](https://www.mathworks.com/help/control/ug/extended-and-unscented-kalman-filter-algorithms-for-online-state-estimation.html)：均值/协方差权重和过程噪声。
- [公开对象参考](https://www.mathworks.com/help/control/ref/unscentedkalmanfilter.html)：Alpha/Beta/Kappa与predict/correct接口。
- 本地安装相对MATLAB根目录的toolbox/shared/tracking/trackinglib/+matlabshared/+tracking/+internal/下calcUTParameters.m、UTMeanCovSqrt.m、UKFPredictorAdditive.m只用于本次只读核对；生产模型不调用这些内部函数。
