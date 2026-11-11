function build_pmsm_bridge_plant()
%BUILD_PMSM_BRIDGE_PLANT Create linked physical library and its separate Test.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fileparts(mfilename('fullpath')));
model='PMSMBridgePlant';test='PMSMBridgePlantTest';
assert(~bdIsLoaded(model) && ~bdIsLoaded(test));
assert(~isfile(fullfile(module,'src',[model,'.slx'])) && ~isfile(fullfile(module,'src',[test,'.slx'])));
new_system(model,'Library');
result=edit(model,'root',{struct('op','create_subsystem','name','BridgeMotor','ref','core', ...
    'interface',struct('inputs',{{}},'outputs',{{}}))},false,'full');scope=createdId(result,'core');
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','on', ...
    'MaskVariables','cfg=@1;','MaskStyleString','edit','MaskPromptString','Physical bridge/PMSM configuration', ...
    'MaskValueString','pmsm_bridge_parameters()'))},false,'incremental');
inputs={'duty_abc','mode','load_torque'};
outputs={'current_ab','phase_current','phase_voltage','voltage_ab','speed_mechanical','theta_e', ...
    'torque','dc_current','diode_states','magnetic_energy','kinetic_energy','bridge_loss', ...
    'equation_residual','next_phase_current','neutral_voltage','pole_voltage'};
operations={};
for k=1:3,operations{end+1}=b('Inport',inputs{k},struct('Port',num2str(k),'SampleTime','cfg.Ts'));end
for k=1:numel(outputs),operations{end+1}=b('Outport',outputs{k},struct('Port',num2str(k)));end
operations=[operations,{b('MATLAB Function','Step',struct()),b('MATLAB Function','Measure',struct())}];
result=edit(model,scope,operations,false,'full');known=struct();
for name=[inputs,outputs,{'Step','Measure'}],known.(name{1})=createdId(result,name{1});end
for name={'Step','Measure'}
    block=Simulink.ID.getFullName([model,':',extractAfter(known.(name{1}),'blk_')]);
    configuration=get_param(block,'MATLABFunctionConfiguration');
    if strcmp(name{1},'Step'),source='pmsm_bridge_step.m';else,source='pmsm_bridge_output.m';end
    configuration.FunctionScript=fileread(fullfile(module,'src',source));
end
disp(model_read(model,scope,'0'));
operations={b('UnitDelay','PhysicalState',struct('InitialCondition','cfg.State0','SampleTime','cfg.Ts')), ...
    b('Constant','Settings',struct('Value','cfg.Vector')), ...
    c('#PhysicalState.y1',[known.Step,'.u1']),c('#PhysicalState.y1',[known.Measure,'.u1']), ...
    c('#Settings.y1',[known.Step,'.u5']),c('#Settings.y1',[known.Measure,'.u2']), ...
    c([known.Step,'.y1'],'#PhysicalState.u1')};
for k=1:3,operations{end+1}=c([known.(inputs{k}),'.y1'],sprintf('%s.u%d',known.Step,k+1));end
% Public output number -> actual MATLAB Function output number.
measureMap=[1,1;2,2;5,3;6,4;7,5;10,6;11,7];
stepMap=[3,3;4,2;8,4;9,5;12,6;13,7;14,8;15,9;16,10];
for k=1:size(measureMap,1),operations{end+1}=c(sprintf('%s.y%d',known.Measure,measureMap(k,2)),[known.(outputs{measureMap(k,1)}),'.u1']);end
for k=1:size(stepMap,1),operations{end+1}=c(sprintf('%s.y%d',known.Step,stepMap(k,2)),[known.(outputs{stepMap(k,1)}),'.u1']);end
edit(model,scope,operations,true,'incremental');
corePath=Simulink.ID.getFullName([model,':',extractAfter(scope,'blk_')]);
box=get_param(corePath,'Position');box(3:4)=box(1:2)+[340,480];
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Position',mat2str(box)))},false,'incremental');
save_system(model,fullfile(module,'src',[model,'.slx']));close_system(model,0);

load_system(fullfile(module,'src',[model,'.slx']));disp(model_read(model,'root','0'));
new_system(test);initialize_bridge_test(test);
callback=['addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));initialize_bridge_test(bdroot);'];
definitions=bridge_trace_channels();
operations={struct('op','configure','target',['config:',test],'params',struct('Solver','FixedStepDiscrete', ...
    'SolverType','Fixed-step','FixedStep','bridgeCfg.Ts','StopTime','bridgeTestCfg.Duration', ...
    'ReturnWorkspaceOutputs','on','PostLoadFcn',callback)), ...
    b('FromWorkspace','Stimulus',struct('VariableName','bridgeStim','Interpolate','off', ...
    'SampleTime','bridgeCfg.Ts','OutputAfterFinalValue','Holding final value')), ...
    b('Demux','Inputs',struct('Outputs','5')),b('Mux','Duty',struct('Inputs','3')), ...
    struct('op','add_block','type','BridgeMotor','ReferenceBlock','PMSMBridgePlant/BridgeMotor', ...
    'name','Plant','ref','Plant','params',struct('MaskValueString','bridgeCfg')), ...
    b('Mux','TraceChannels',struct('Inputs',num2str(size(definitions,1)))), ...
    b('ToWorkspace','SaveTrace',struct('VariableName','bridge_trace','SaveFormat','Structure With Time','MaxDataPoints','inf')), ...
    b('Gain','BusPower',struct('Gain','bridgeCfg.Vdc')),b('DotProduct','TerminalPower',struct()), ...
    c('#Stimulus.y1','#Inputs.u1'),c('#Duty.y1','#Plant.u1'),c('#Inputs.y4','#Plant.u2'), ...
    c('#Inputs.y5','#Plant.u3'),c('#TraceChannels.y1','#SaveTrace.u1'), ...
    c('#Plant.y8','#BusPower.u1'),c('#Plant.y3','#TerminalPower.u1'),c('#Plant.y14','#TerminalPower.u2')};
for k=1:3,operations{end+1}=c(sprintf('#Inputs.y%d',k),sprintf('#Duty.u%d',k));end
for k=1:size(definitions,1),operations{end+1}=c(definitions{k,4},sprintf('#TraceChannels.u%d',k));end
groups={'PhaseCurrentScope',{'#Plant.y2'};'PhaseVoltageScope',{'#Plant.y3'}; ...
    'MechanicalSpeedScope',{'#Plant.y5'};'EnergyScope',{'#Plant.y10','#Plant.y11'}; ...
    'PowerScope',{'#BusPower.y1','#TerminalPower.y1','#Plant.y12'}; ...
    'BridgeModeScope',{'#Inputs.y4','#Plant.y9'};'EquationResidualScope',{'#Plant.y13'}};
for k=1:size(groups,1)
    name=groups{k,1};sources=groups{k,2};mux=[name,'Channels'];
    operations=[operations,{b('Mux',mux,struct('Inputs',num2str(numel(sources)))), ...
        b('Scope',name,struct('NumInputPorts','1')),c(['#',mux,'.y1'],['#',name,'.u1'])}];
    for j=1:numel(sources),operations{end+1}=c(sources{j},sprintf('#%s.u%d',mux,j));end
end
result=edit(test,'root',operations,true,'full');plantId=createdId(result,'Plant');
plantPath=Simulink.ID.getFullName([test,':',extractAfter(plantId,'blk_')]);
box=get_param(plantPath,'Position');box(3:4)=box(1:2)+[340,480];
edit(test,'root',{struct('op','configure','target',plantId,'params',struct('Position',mat2str(box)))},true,'incremental');
edit(test,'root',{},true,'full');
save_system(test,fullfile(module,'src',[test,'.slx']));close_system(test,0);
end
function operation=b(type,name,parameters)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',parameters);
end
function operation=c(source,destination)
operation=struct('op','connect','target',[source,' -> ',destination]);
end
function id=createdId(result,reference)
match=regexp(char(result),['(?m)^\s*',reference,':\s*(blk_\d+)\s*$'],'tokens');assert(isscalar(match));id=match{1}{1};
end
function result=edit(model,scope,operations,complete,layout)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(operations),layout);disp(result);
disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok')
    disp(model_check(model,scope,'["all"]'));error('Inspect the partial model before continuing.');
end
if complete
    check=model_check(model,scope,'["all"]');disp(check);assert(~contains(string(check),'severity: error'));
end
end
