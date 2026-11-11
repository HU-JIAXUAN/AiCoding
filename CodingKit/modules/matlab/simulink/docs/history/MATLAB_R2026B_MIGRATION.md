# MATLAB R2026b 产品安装与MCP切换

日期：2026-11-09。R2026b安装目录为C:\Program Files\MATLAB\R2026b，版本26.2.0.3433840（Update 1）。按照R2026a可见产品清单，已从MathWorks重新下载并安装47项R2026b产品及其依赖。原安装包F:\Downloads\matlab_R2026b_Windows.exe保留。

## 当前结果

| 检查 | 实际结果 | 证据 |
|---|---|---|
| 官方产品安装 | MPM退出码0，2026-11-09 03:44:53（本机时间）记录Successful；47项请求全部登记，共54项含依赖 | [environment_installation.json](../validation/environment_installation.json) |
| MATLAB实际产品可见性 | R2026b内ver逐项核对，缺失0项；Simulink及建模函数可调用 | [产品及函数清单](../validation/environment_installation.json) |
| Agentic附加组件 | MATLAB MCP Server Toolbox 0.5.0、Simulink Agentic Toolkit 1.0.33均已启用，新会话可定位 | [附加组件记录](../validation/environment_installation.json) |
| Skill运行入口 | 严格审计通过：136个有效入口，重名、缺失和错链均为0，发布包无漂移 | [Skill审计摘要](../validation/environment_installation.json) |
| MCP重装与冷启动 | 2026-11-10重装官方v0.16.0服务和0.5.0配套包；独立新进程实际返回R2026b，模型读/写/检查及SMO短仿真通过。本聊天旧连接已停止，须重启Codex加载新注册 | [重装记录](../validation/mcp_reinstallation.json)、[原接口验证](../validation/mcp_verification.json) |
| 独立库实例参数 | 两个链接到同一库的实例分别使用K=2和K=5，输入3，输出分别6和15 | [MCP接口测试](../validation/mcp_verification.json) |
| 模型回归 | 121/121项通过：历史基线95项、PLL12项、SMO14项，进程退出码0 | [environment_regression.json](../validation/environment_regression.json) |
| 主机编译器 | MinGW14.2已部署并选为C/C++编译器；官方例程MEX编译、执行及新建MCP环境检查通过 | [host_compiler.json](../validation/host_compiler.json) |
| Simulink Coder | 26.2补装完成，退出码0；CurrentPIProbeTest已在临时副本生成GRT/C源码，未执行SIL | [code_generation.json](../validation/code_generation.json) |
| R2026a卸载 | 08:31:24+01:00官方卸载完成，进度100%、退出码0；10:31:56+01:00复查旧安装目录、exe与卸载登记均不存在，原下载的B安装包仍保留 | [old_release_uninstall.json](../validation/old_release_uninstall.json) |

## 产品、Skill与MCP的处理

47项来自R2026a只读ver清单，剔除MCP附加组件后逐项匹配R2026b官方标识。Lidar Toolbox在R2026b更名为Point Cloud Toolbox，已按官方名称安装。R2026a产品文件没有复制到R2026b。附加组件使用当前发布版mltbx通过R2026b公开mpminstall接口安装，Prompt=false；通过交互-r会话保存安装设置后，再由新会话验证。

已核对的最新发布为MATK-2026.11.a、SATK-2026.11.a和MATLAB MCP Server v0.16.0。MATLAB/Simulink Skill的运行junction继续指向Codex-Skills中受管理的官方external子模块，未创建第二套R2026b专用Skill，也未修改发布的Skill源或插件缓存。

用户MCP配置固定R2026b根目录、matlab-session-mode=new及matlab-display-mode=nodesktop，保留Simulink扩展tools.json、WINDIR传递、MinGW环境及原超时。2026-11-10按用户要求删除旧MCP注册和服务文件，停止14个旧服务/看门狗进程，重新下载官方当前v0.16.0并核对发布SHA-256；仅对MCP配套包执行卸载/重装，Simulink包和其他Codex配置逐项保持一致。136个Skill入口严格审计通过、重名0。

原先通过shareMATLABSession连到B的结果只证明共享会话；关闭MATLAB后的旧聊天冷启动仍指向已卸载的A。本次重装后，独立MCP新进程在无共享会话时启动B，完成模型读/写/检查、3×2=6临时模型仿真及SMO 30ms/601行/22列有限值检查；R2026a路径残留为0，YALMIP新目录仍可用。该结果不表示现有聊天已刷新：直接调用目前返回Transport closed，需完全退出并重新打开Codex后复核。官方安装器state.yaml仍保留历史A条目，未手工改写为当前运行证据；当前版本依据实际注册和新进程报告。

重装与操作记录见[重装报告](../validation/mcp_reinstallation.json)。这是环境冒烟，不增加算法MIL场景计数；未执行SIL或C2000验证。

## 已核对的编辑接口边界

当前model_edit能够建立MATLAB Function块，但不能把Script直接路由到该块的代码属性。独立临时模型中已复现PARAM_VALUE_INVALID；按上游问题记录和MathWorks公开文档，改用MATLABFunctionConfiguration.FunctionScript写入代码，之后由model_read回读，model_check返回healthy，仿真验证3的平方为9。该方法只处理函数代码，块、连线和模型配置仍通过model_edit维护。

库实例参数使用公开的MaskVariables、MaskStyleString、MaskPromptString、MaskValueString设置，已经过两个实例的独立配置测试。独立参数可用于后续不同观测器与HFI双角度PLL的组装，避免同一模型里所有PLL被迫共享一份参数。

## 回归与后续环境项

121项在临时工程副本中运行，实际MATLAB版本和安装路径均记录在报告中。回归包含PID12、Math13、06–14模块45、MTPA/弱磁25、PLL12、SMO14；源模型、历史波形没有被本次环境检查覆盖。进入剩余模块建设前，原有24个SLX的SHA-256与初始快照逐项一致。

完整产品安装后，R2026b的registerTICCS和attachhdlcconfig均能在B目录下定位，之前部分安装时的缺失告警已解除。MinGW14.2已部署至用户工具目录，C/C++均选为默认编译器；官方yprime.c已编译成MEX并运行，输出为[0; -80.41433752482952; 1; 0]。用户环境变量和MCP显式env均配置MW_MINGW64_LOC，新建B MCP会话的版本、路径与编译器断言通过，其余Codex配置语义未改变。Simulink Coder已补装成功，总登记55项；同条件重跑CurrentPIProbeTest的编译分析和GRT/C源码生成通过，原ConfigSetManager错误解除。构建日志提示GRT不能使用RAM efficiency指标，未计为内存优化；尚未构建可执行程序或运行SIL。121项基线回归仍只记为MIL，未记为C2000构建或板测。

卸载器要求关闭所有MATLAB会话，包括B；关闭无未保存模型的B会话后，官方静默卸载完成。随后补装Coder重新登记B的文件关联，并恢复B的共享MCP会话；实际查询仍返回2026b。PLL新增独立实例Mask和测试模型，3项隔离验证通过，原12项PLL/14项SMO重跑通过，见[实例分析](../../model/lib/相位跟踪/waveform_analysis/INSTANCES.md)。

本轮继续执行[无位置传感器建设计划](../plans/SENSORLESS_PLAN.md)的全部lib和App。完成后由[清理脚本](../scripts/clear_sensorless_build_cache.ps1)处理本次登记的临时目录；运行方式和保留范围见[脚本入口](../scripts/README.md)。

## 官方依据

- [MPM向已有版本添加产品](https://www.mathworks.com/help/install/ug/mpminstall.html)
- [Point Cloud Toolbox更名](https://www.mathworks.com/help/pointcloud/release-notes.html)
- [MATLAB Agentic Toolkit发布](https://github.com/matlab/matlab-agentic-toolkit/releases/tag/MATK-2026.11.a)
- [Simulink Agentic Toolkit发布](https://github.com/matlab/simulink-agentic-toolkit/releases/tag/SATK-2026.11.a)
- [MATLAB MCP Server会话配置](https://github.com/matlab/matlab-mcp-server#arguments)
- [MATLAB Function公开配置接口](https://www.mathworks.com/help/simulink/slref/simulink.matlabfunctionconfiguration.html)
- [model_edit的MATLAB Function代码问题](https://github.com/matlab/simulink-agentic-toolkit/issues/87)
- [MathWorks官方卸载方法](https://www.mathworks.com/help/install/ug/uninstall-mathworks-products.html)

[环境清单](../platform/TOOLBOX_MATRIX.md) · [验证说明](../validation/README.md)

## 本轮最终核对

[最终环境记录](../validation/final_environment.json)来自实际R2026b新会话：Update 1、56个ver条目，MATLAB MCP Server Toolbox 0.5.0与Simulink Agentic Toolkit 1.0.33均启用，model_edit/read/check来自同一Toolkit；C编译器MinGW14.2，YALMIP从`bin/YALMIP`加载且sdpvar创建成功。原MATLAB下载安装包保留。

[MRAS主机代码验证](../../model/lib/观测器/模型参考自适应/waveform_analysis/HOST_CODE_ANALYSIS.md)另完成状态更新函数double/single MEX与double SIL；不更改此前CurrentPIProbeTest仅生成源码的历史结果，不表示完整App SIL或C2000验证。
