# UKF参考来源

| 资料 | 来源 |
|---|---|
| MathWorks：UKF算法、2n+1点及权重 | https://www.mathworks.com/help/control/ug/extended-and-unscented-kalman-filter-algorithms-for-online-state-estimation.html |
| MathWorks：unscentedKalmanFilter参考及Alpha/Beta/Kappa范围 | https://www.mathworks.com/help/control/ref/unscentedkalmanfilter.html；本地R2026b help已核对，作为纯M数值比较参考 |
| 四状态SPMSM及电流测量 | [共用过程](../../../永磁同步电机/parameter/SENSORLESS_PARAMETERS.md)，主要书籍12.4式12.38–12.44；本书未单列UKF |
| 共享线性校正和资格 | [EKF搭建](../../扩展卡尔曼/build_process/STEPS.md)，Joseph协方差、方向/角变化率、NIS与复位 |

本实现使用显式协方差UT；MathWorks对象内部采用平方根方法改善数值性，两者在适当输入下核对结果，不宣称内部算法逐行等同。圆周角统计、局部角范围、有界归一化jitter与故障锁存为工程选择。没有复制官方对象实现，也没有将本模块记为平方根UKF。

[模块入口](../README.md)
