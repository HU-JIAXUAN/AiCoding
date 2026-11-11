# 低侧钳位五段式 SVPWM

[SvpwmFiveSegment.slx](SvpwmFiveSegment.slx) 将三相参考分别减去最小相参考，再除以母线电压。每周期最小相占空比为 0。扇区内部且在线性范围内，第一扇区的理想序列为 `000 → 100 → 110 → 100 → 000`。

[受保护模型](SvpwmFiveSegmentProtected.slxp) · [接口与对照测试](../README.md)
