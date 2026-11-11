# 工具与环境清单

当前开发环境已切到R2026b Update 1。47项原R2026a清单对应产品已重新下载B版本，原47项及依赖登记54项，补装Simulink Coder后共55项；121项基线MIL回归通过。实际安装、Skill、MCP与回归报告见[环境记录](../history/MATLAB_R2026B_MIGRATION.md)。R2026a官方卸载已完成，旧可执行文件与系统登记已移除；约8.6GB残留文件待最终清理，见[卸载记录](../validation/old_release_uninstall.json)。

| 工具 | 作用/何时需要 | 2026-11-09本机核对结果 |
|---|---|---|
| MATLAB / Simulink | 数值分析、基础块、仿真 | 26.2，Update 1；121项实际MIL通过 |
| C2000 Microcontroller Blockset | 目标外设、代码构建、PIL和监控接入 | 26.2；B目录中TIF28P650DLaunchPad.xml、TIF28P65x.xml、TIF2838x.xml均存在；registerTICCS可定位 |
| Embedded Coder | 嵌入式代码接口与目标优化 | 26.2已安装；尚未把本次结果计为生成代码或目标构建 |
| MATLAB Coder | 从MATLAB算法生成代码 | 26.2已安装；MinGW14.2已配置并完成独立MEX编译/运行 |
| Simulink Coder | 从Simulink模型生成代码、SIL | 26.2已补装，官方安装退出码0；CurrentPIProbeTest临时副本已生成GRT/C源码，SIL尚未执行，见[源码生成报告](../validation/code_generation.json) |
| Motor Control Blockset | 官方估计器与电机例程对照 | ver未列出；当前自建lib使用标准块与自有方程，不依赖它运行 |
| Simscape / Simscape Electrical | 物理网络与开关对象 | ver未列出；现有数学Plant不依赖它，第三方powerlib旧模型不在本次回归内 |
| Control System Toolbox | 解析模型、控制与频域对照 | 26.2已安装，PID解析/官方块对照已随回归运行 |
| Simulink Test / Stateflow | 专用测试文件与状态图 | ver未列出；测试使用SimulationInput和断言。MATLAB Function的EMChart代码接口已实际验证，不据此声称完整Stateflow产品已安装 |
| 主机C/C++编译器 | MEX和主机SIL编译 | MinGW14.2.0已选择；官方yprime.c已编译并执行，新建B MCP会话通过编译器环境断言，见[编译器报告](../validation/host_compiler.json) |
| CCS / TI CGT | C2000目标编译与调试 | C:\ti\ccs1281下的TI C2000 CGT 22.6.1.LTS\bin\cl2000.exe存在；尚未完成本次B环境的C2000工具链配置与目标编译 |
| MATLAB / Simulink Agentic Toolkit | Agent工作方法与建模工具 | 已核对MATK-2026.11.a、SATK-2026.11.a；Skill严格审计136个有效入口，无重名、断链或发布包漂移 |
| MATLAB MCP Server | 调用B会话 | v0.16.0；当前聊天实际返回2026b，建块/连线、代码回读、结构检查和仿真均已验证 |

## 验证分开记录

产品存在、函数可定位、生成代码、目标编译和硬件运行分别留证据。当前121项为MIL，不作为SIL、PIL或板上控制结果。R2026a时期的代码配置工具错误保留在[codegen_probe.json](../../model/lib/电流环/waveform_analysis/codegen_probe.json)，该历史失败记录保留；B中实际重跑已通过模型编译分析与源码生成，另存[新报告](../validation/code_generation.json)，未记为可执行程序构建或SIL。

完整产品安装后attachhdlcconfig、registerTICCS均能在B目录定位，部分安装时的缺失告警已解除。原始24个SLX在进入后续模块建设前，SHA-256与初始快照逐项一致。回归在独立临时工程副本中执行，历史源模型和波形没有被覆盖。

## C2000与主机工具链

当前CCS12安装目录不是F:\TI\CCS12工作区；已有F28388D工程生成makefile中的CG_TOOL_ROOT指向C:\ti\ccs1281\ccs\tools\compiler\ti-cgt-c2000_22.6.1.LTS。此处只读取路径并确认文件存在，没有修改固件工程。

MathWorks当前R2026b兼容表列出的已验证组合为CCS20.5.0、C2000Ware26_00_00_00与TI C28x CGT25.11.0；“支持的CCS范围”和“官方已验证组合”分列。后续优先核对现有工具链能否完成实际构建，不把本机旧路径直接当作B环境已经配置成功。

MinGW14.2已部署在用户工具目录C:\Users\24322\AppData\Local\Programs\mingw64，并通过User环境变量及MCP显式环境配置MW_MINGW64_LOC。C/C++均已选择，官方yprime.c的MEX编译与运行通过；Simulink Coder已补装，CurrentPIProbeTest已生成源码，SIL尚未执行。MinGW用于主机代码，TI C28x编译器用于C2000目标。模型代码阶段只编译和比较数值；板卡下载、PIL及真实电机运行分别记录。已有P650 LaunchPad不代表当前已经接好功率级、电机和电流采样。

官方依据：[C2000产品要求](https://www.mathworks.com/support/requirements/c2000-microcontroller-blockset.html)、[TI工具链兼容表](https://www.mathworks.com/help/ti-c2000/gs/CCS-MATLAB-versions.html)、[主机支持编译器](https://www.mathworks.com/support/requirements/supported-compilers.html)、[C2000工作流](C2000_WORKFLOW.md)。
