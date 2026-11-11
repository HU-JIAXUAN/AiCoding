# 公共接口

公共语义见 [INTERFACE_CONTRACT.md](INTERFACE_CONTRACT.md)，包括单位、周期、状态和限制反馈。

单个模块的具体输入、过程变量、输出和Scope通道放在该模块parameter/README.md。入口见[模型目录](../../model/README.md)，整机52列见[experiment参数](../../model/app_models/Sensor/experiment/parameter/README.md)。当前使用标量和定长向量，没有公共Bus对象；目标语义与当前速度PI直接输出iq的差别在接口正文明确记录。

[返回 docs](../README.md) · [返回工程入口](../../README.md)

[受保护模型发布接口](PROTECTED_MODELS.md)维护实际模型文件、端口顺序、维度、类型、采样及固定配置。
