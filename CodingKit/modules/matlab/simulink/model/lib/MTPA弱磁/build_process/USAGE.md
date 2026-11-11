# 运行、调参和观察波形

## 直接打开Simulink运行

打开本模块src/CurrentReferenceTest.slx后点击Run，双击Currents、Torques、Voltages、ElectricalSpeed、State查看波形。PostLoadFcn调用initialize_mtpa_fw_model，加入旧模块依赖并将默认配置/testStim放入本模型Model Workspace；不依赖手工预先准备Base Workspace。

打开src/MTPAFWMotor.slx，默认速度模式、218rad/s给定、48V母线、0.05N·m负载、仿真2s。重点看Speed、WeakeningCurrents、WeakeningVoltages、AllocationTorque和AllocationState。Scope顺序、单位、源块及数据列见[参数页](../parameter/README.md)。Library CurrentReference.slx用于查看算法内部，不能点击Run做整机仿真。

组件为100µs离散固定步长；整机为ode4固定步长5µs，电流/数据100µs、外环/弱磁1ms。Stop time可以在模型工具栏修改，修改输入矩阵时需覆盖完整仿真时段。

## 用脚本做一次可复现实验

```matlab
module = 'F:\Study\AI\AiCoding\CodingKit\modules\matlab\simulink\model\lib\MTPA弱磁';
addpath(fullfile(module,'build_process'));
r = run_mtpa_fw_case('MTPAFWMotor');  % 默认，覆盖只用于本次仿真
t = r.trace.time;
plot(t,r.trace.signals.values(:,[30,31,32])); grid on
legend('speed request','speed truth','speed feedback');
```

返回r.parameters是本次实际参数快照，r.inputs为组件激励，r.trace为Structure With Time。使用SimulationInput，不把覆盖参数写回保存的模型。

比较弱磁关闭/开启：

```matlab
off = run_mtpa_fw_case('MTPAFWMotor',struct('refCfg',struct('FwEnable',0)));
on  = run_mtpa_fw_case('MTPAFWMotor');
plot(off.trace.time,off.trace.signals.values(:,31), ...
     on.trace.time,on.trace.signals.values(:,31)); grid on
legend('FW off','FW on');
```

转速给定覆盖使用experimentCfg，不是refTestCfg：

```matlab
o = struct('experimentCfg',struct('SpeedReference',190,'LoadTorque',0.03), ...
           'inverterCfg',struct('Vdc',42), ...
           'refCfg',struct('FwKi',40,'FwVoltageMargin',0.2));
r = run_mtpa_fw_case('MTPAFWMotor',o,[],2);
```

## 先单独理解MTPA

```matlab
t = (0:1e-4:0.1)'; z = zeros(size(t));
u = [linspace(-1.5,1.5,numel(t))', z, 48+z, z, 1+z, z];
o = struct('pmsmCfg',struct('Lq',6e-3), ...
           'refCfg',struct('FwEnable',0));
a = run_mtpa_fw_case('CurrentReferenceTest',o,u,0.1);
o.refCfg.MtpaEnable = 0;
b = run_mtpa_fw_case('CurrentReferenceTest',o,u,0.1);
plot(a.trace.signals.values(:,1),hypot(a.trace.signals.values(:,7),a.trace.signals.values(:,8)), ...
     b.trace.signals.values(:,1),hypot(b.trace.signals.values(:,7),b.trace.signals.values(:,8)));
grid on; xlabel('Torque / N m'); ylabel('Current magnitude / A');
legend('MTPA','id=0');
```

u每行是一拍，间隔currentCfg.Ts，六列依次T、we、Vdc、Uprev、enable、reset；本接口不接受时间列。转矩N·m，we为电角rad/s。需至少提供duration/Ts+1行以覆盖时段；外部Uprev≥0且已表示上一完整拍，enable/reset用0或1。

测试弱磁时把we提高到800、T设0.2、Uprev设0，即可观察模型需求分支使id_fw变负。要单独检查实际电压反馈分支，用we=500并给Uprev加28V短脉冲。不要把机械速度直接接到we端口。

## 参数在哪里改

[mtpa_fw_parameters.m](../parameter/mtpa_fw_parameters.m)维护本模块默认值；[reference_case_parameters.m](../parameter/reference_case_parameters.m)引用旧模块参数并定义新整机工况。脚本覆盖电机Lq、磁链、极对数、CurrentMax、IdMin或MTPA开关后，run_mtpa_fw_case自动调用refresh_mtpa_tables重建派生表，不用手工编辑IdTable。

GUI临时改变模型工作区参数可用Model Explorer；改变refCfg的基础值后，必须重新生成派生值，例如：

```matlab
w = get_param('CurrentReferenceTest','ModelWorkspace');
cfg = getVariable(w,'refCfg'); motor = getVariable(w,'pmsmCfg');
cfg.CurrentMax = 7; cfg.IdMin = -6;
cfg = refresh_mtpa_tables(cfg,motor);
assignin(w,'refCfg',cfg);
```

点击Run使用当前工作区。重新打开模型会由PostLoadFcn重载默认值；需要长期保留的默认值应修改参数定义文件。跨模块改变周期、Plant参数、PI增益时应明确一起覆盖哪些配置，不假设所有调参依赖都会自动重整定。FwTs必须是电流Ts的整数倍，SpeedTs必须与motionCfg.Ts一致。

## 整套验证、看数据与导出图

```matlab
addpath(fullfile(module,'waveform_analysis'));
summary = run_mtpa_fw_validation();         % 25项，整机组较慢
% 也可分别运行 'mtpa'、'fw'、'motor'；覆盖该组并保留已有其他组结果
export_mtpa_fw_plots();                      % 从results.mat生成PNG与SVG
s = load(fullfile(module,'waveform_analysis','results.mat'),'records');
r = s.records.motor.fw_on;
k = find(strcmp(r.channels,'id_fw'));
plot(r.trace.time,r.trace.signals.values(:,k)); grid on
```

results.mat中records.<组>.<工况>包含实际参数、激励、时间、数据、通道名和指标；metrics.json是简要指标。部分组结果会标为partial，三组均存在才标passed，最终完整结果共25项。测试脚本失败会停止并保留上一次已完成组，不把失败组登记为通过。

Scope看实时叠图，trace用于数值复查。读取本模块电机数据时用74列说明，旧MotorExperiment仍是52列，不能混用两个表。
