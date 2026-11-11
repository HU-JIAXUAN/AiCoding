# 控制器 Variant 政策

1. 默认在仿真配置阶段选择 Variant；不承诺运行时任意切换。
2. 每个 Variant 说明输入 Adapter、输出、采样时间、状态、初始化和故障处理。
3. Controller 的对外控制职责不可随算法改变，例如 SpeedLoop 输出 TorqueRef。
4. PI 与 ADRC/MPC 的内部状态/估计输入可以不同，但必须通过 Adapter 满足公共 Loop 契约。
5. 运行时切换必须另做无扰切换机制和状态转移测试。
