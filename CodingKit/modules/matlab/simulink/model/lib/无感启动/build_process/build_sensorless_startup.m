function build_sensorless_startup()
%BUILD_SENSORLESS_STARTUP Build a state-explicit startup library and test model.
assert(strcmp(version('-release'),'2026b'));
gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
libraryName='SensorlessStartup';testName='SensorlessStartupTest';
assert(~bdIsLoaded(libraryName) && ~bdIsLoaded(testName));
assert(~isfile(fullfile(module,'src',[libraryName,'.slx'])) && ...
    ~isfile(fullfile(module,'src',[testName,'.slx'])),'Rebuild in an isolated copy.');
new_system(libraryName,'Library');open_system(libraryName);
result=edit(libraryName,'root',{struct('op','create_subsystem','name','Startup', ...
    'ref','startup','interface',struct('inputs',{{}},'outputs',{{}}))},false);
subsystemId=createdId(result,'startup');
subsystemPath=Simulink.ID.getFullName([libraryName,':',extractAfter(subsystemId,'blk_')]);
result=edit(libraryName,subsystemId,{b('MATLAB Function','SequenceStep',struct())},false);
coreId=createdId(result,'SequenceStep');
corePath=Simulink.ID.getFullName([libraryName,':',extractAfter(coreId,'blk_')]);
configuration=get_param(corePath,'MATLABFunctionConfiguration');
configuration.FunctionScript=fileread(fullfile(module,'src','startup_step.m'));
disp(model_read(libraryName,subsystemId,'0'));
inputs={'enable','reset','direction','acquired'};
outputs={'theta_start','omega_start','id_start','iq_start','ready','mode','fault','elapsed'};
operations={};
for index=1:4,operations{end+1}=b('Inport',inputs{index}, ...
        struct('Port',num2str(index),'SampleTime','startupCfg.Ts'));end
for index=1:8,operations{end+1}=b('Outport',outputs{index},struct('Port',num2str(index)));end
operations=[operations,{b('Mux','inputs',struct('Inputs','4')), ...
    b('Constant','parameters',struct('Value','startupCfg.Vector')), ...
    b('UnitDelay','state',struct('InitialCondition','startupCfg.State0','SampleTime','startupCfg.Ts')), ...
    b('Demux','outputs',struct('Outputs','8')), ...
    c('#state.y1',[coreId,'.u1']),c('#inputs.y1',[coreId,'.u2']), ...
    c('#parameters.y1',[coreId,'.u3']),c([coreId,'.y1'],'#state.u1'), ...
    c([coreId,'.y2'],'#outputs.u1')}];
for index=1:4,operations{end+1}=c(['#',inputs{index},'.y1'],sprintf('#inputs.u%d',index));end
for index=1:8,operations{end+1}=c(sprintf('#outputs.y%d',index),['#',outputs{index},'.u1']);end
edit(libraryName,subsystemId,operations,true);
edit(libraryName,'root',{struct('op','configure','target',subsystemId,'params', ...
    struct('Mask','on','MaskVariables','startupCfg=@1;','MaskStyleString','edit', ...
    'MaskPromptString','Startup configuration','MaskValueString','startupCfg')), ...
    struct('op','configure','target',['config:',libraryName],'params',struct('Lock','on'))},false);
save_system(libraryName,fullfile(module,'src',[libraryName,'.slx']));

new_system(testName);open_system(testName);initialize_startup_test(testName);
callback=['addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));', ...
    'initialize_startup_test(bdroot);'];
operations={struct('op','configure','target',['config:',testName],'params', ...
    struct('Solver','FixedStepDiscrete','SolverType','Fixed-step','FixedStep','startupCfg.Ts', ...
    'StopTime','startupTestCfg.Duration','ReturnWorkspaceOutputs','on','PostLoadFcn',callback)), ...
    b('FromWorkspace','stimulus',struct('VariableName','testStim','Interpolate','off', ...
    'SampleTime','startupCfg.Ts','OutputAfterFinalValue','Holding final value')), ...
    b('Demux','inputs',struct('Outputs','4')), ...
    struct('op','add_block','type','Startup','ReferenceBlock',subsystemPath,'name','Startup','ref','startup'), ...
    b('Mux','trace_mux',struct('Inputs','12')), ...
    b('ToWorkspace','trace',struct('VariableName','trace','SaveFormat','Structure With Time','MaxDataPoints','inf')), ...
    c('#stimulus.y1','#inputs.u1'),c('#trace_mux.y1','#trace.u1')};
for index=1:4
    operations=[operations,{c(sprintf('#inputs.y%d',index),sprintf('#startup.u%d',index)), ...
        c(sprintf('#inputs.y%d',index),sprintf('#trace_mux.u%d',index))}];
end
for index=1:8,operations{end+1}=c(sprintf('#startup.y%d',index),sprintf('#trace_mux.u%d',index+4));end
groups={'AngleScope',{'#startup.y1'};'SpeedScope',{'#startup.y2'}; ...
    'CurrentScope',{'#startup.y3','#startup.y4'}; ...
    'StatusScope',{'#inputs.y1','#inputs.y2','#inputs.y3','#inputs.y4','#startup.y5','#startup.y6','#startup.y7'}; ...
    'ElapsedScope',{'#startup.y8'}};
for group=1:size(groups,1)
    name=groups{group,1};sources=groups{group,2};mux=[name,'_channels'];
    operations=[operations,{b('Mux',mux,struct('Inputs',num2str(numel(sources)))), ...
        b('Scope',name,struct('NumInputPorts','1')),c(['#',mux,'.y1'],['#',name,'.u1'])}];
    for index=1:numel(sources),operations{end+1}=c(sources{index},sprintf('#%s.u%d',mux,index));end
end
edit(testName,'root',operations,true);
save_system(testName,fullfile(module,'src',[testName,'.slx']));
print(['-s',subsystemPath],'-dpng',fullfile(module,'build_process','algorithm_diagram.png'));
print(['-s',testName],'-dpng',fullfile(module,'build_process','test_diagram.png'));
end
function operation=b(type,name,parameters)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',parameters);
end
function operation=c(source,destination)
operation=struct('op','connect','target',[source,' -> ',destination]);
end
function id=createdId(result,reference)
match=regexp(char(result),[reference,':\s*(blk_\d+)'],'tokens');
assert(isscalar(match),'Inspect the editor-created map.');id=match{1}{1};
end
function result=edit(model,scope,operations,complete)
disp(model_read(model,scope,'0'));
result=model_edit(model,scope,jsonencode(operations),'full');disp(result);
disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok')
    disp(model_check(model,scope,'["all"]'));error('Inspect the failed or partial edit before continuing.');
end
if complete
    check=model_check(model,scope,'["all"]');disp(check);
    assert(~contains(string(check),'severity: error'));
end
end
