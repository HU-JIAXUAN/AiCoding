# Clarke/Park 计算定义

本模块采用幅值不变变换、abc 正相序、α 轴沿 a 轴、d 轴在 θ=0 时沿 α 轴。θ 是电角度，单位 rad，正方向从 α 指向 β。全部数值端口先采用 double，变换本身无状态、无采样延迟，继承调用者采样周期。

```text
Clarke:
  alpha = (2*a-b-c)/3
  beta  = (b-c)/sqrt(3)
  zero  = (a+b+c)/3
Park:
  d = alpha*cos(theta_e) + beta*sin(theta_e)
  q = -alpha*sin(theta_e) + beta*cos(theta_e)
InversePark:
  alpha = d*cos(theta_e) - q*sin(theta_e)
  beta  = d*sin(theta_e) + q*cos(theta_e)
InverseClarke:
  a = alpha + zero
  b = -alpha/2 + sqrt(3)*beta/2 + zero
  c = -alpha/2 - sqrt(3)*beta/2 + zero
```

四个函数分别作为 ClarkePark 库的四个子系统，可单独引用。Park 与反 Park 直接接收 θ，在各自子系统中计算 sin/cos；优先保持端口容易理解，目标代码的三角函数复用和 single 数值验证留待 C2000 接入时测量与优化。

零序不参与平面旋转，单独从 Clarke 传至反 Clarke。丢弃它只能重建零和三相分量。测试模型允许选择正向输出回送反变换，或给独立的 d/q/zero 命令，用来分别验证四个积木。Scope 分为正向、反向和往返误差三组。

本次使用标准 Gain、Sum、Product、Trigonometry 块，不依赖 Motor Control Blockset 或旧 powerlib。Simulink Test 当前不可定位，验证用 SimulationInput 与断言。
