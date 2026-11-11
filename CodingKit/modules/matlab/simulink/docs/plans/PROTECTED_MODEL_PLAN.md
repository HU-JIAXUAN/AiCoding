# Protected Model 维护计划

1. **选发布接口。** 按可复用库 SLX 登记至少一个可独立调用的库块及测试装配。需要分开调用的块分别登记。记录输入、输出的顺序、单位、维度、类型、采样和模型配置。
2. **生成。** 在临时工作区从库块实例转换为 Model Reference，固定采样和发布配置，用 Simulink Coder 生成仿真用 SLXP。源码库、原测试台和发布文件各有自己的用途。现有文件采用 R2026b Update 1、Windows x64、MinGW64 仿真目标。
3. **核验。** 将可编辑转换模型移出 MATLAB 路径，在 Model block 里选择 SLXP。用原工况重放各输出，比较时间、维度、类型及数值。记录 SHA-256 和验证结果。契约变动时同步接收端装配。
4. **发布。** 将验证通过的 SLXP 放回库模块的 src，发布时配上接口与环境说明。参数、采样、算法或 MATLAB 发布版本变化后重新打包和重放。将来要分发目标代码时，为对应工具链和芯片建立独立构建验证。

[发布接口与构建入口](../interfaces/PROTECTED_MODELS.md) · [MathWorks 保护模型 API](https://www.mathworks.com/help/rtw/ref/simulink.modelreference.protect.html)
