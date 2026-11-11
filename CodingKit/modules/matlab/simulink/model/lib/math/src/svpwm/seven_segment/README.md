# 对称七段式 SVPWM

[SvpwmSevenSegment.slx](SvpwmSevenSegment.slx) 使用最大、最小相参考的平均值取负作为共同分量，使占空比绕 0.5 居中。扇区内部且在线性范围内，第一扇区的理想序列为 `000 → 100 → 110 → 111 → 110 → 100 → 000`。

[受保护模型](SvpwmSevenSegmentProtected.slxp) · [接口与对照测试](../README.md)
