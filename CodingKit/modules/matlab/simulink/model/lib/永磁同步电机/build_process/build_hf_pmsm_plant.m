function build_hf_pmsm_plant()
%BUILD_HF_PMSM_PLANT Build the nonlinear physical PMSM library and pulse bench.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
model='PMSMHighFrequencyPlant';test='PMSMHighFrequencyPlantTest';
assert(~bdIsLoaded(model) && ~bdIsLoaded(test));
assert(~isfile(fullfile(module,'src',[model,'.slx'])) && ~isfile(fullfile(module,'src',[test,'.slx'])), ...
    'Build in an isolated copy when source models already exist.');
new_system(model,'Library');open_system(model);
result=edit(model,'root',{struct('op','create_subsystem','name','HFPMSM','ref','core', ...
    'interface',struct('inputs',{{}},'outputs',{{}}))},false,'full');scope=id(result,'core');
inputs={'u_alpha','u_beta','load_torque'};
outputs={'i_alpha','i_beta','theta_e','omega_e','torque','id','iq','incremental_ld','psi_d','psi_q'};
operations={};
for k=1:numel(inputs),operations{end+1}=b('Inport',inputs{k},struct('Port',num2str(k)));end
for k=1:numel(outputs),operations{end+1}=b('Outport',outputs{k},struct('Port',num2str(k)));end
operations=[operations,{b('MATLAB Function','Dynamics',struct()),b('MATLAB Function','Measurements',struct())}];
result=edit(model,scope,operations,false,'full');ports=struct();names=[inputs,outputs,{'Dynamics','Measurements'}];
for k=1:numel(names),ports.(names{k})=id(result,names{k});end
path=Simulink.ID.getFullName([model,':',extractAfter(ports.Dynamics,'blk_')]);
configuration=get_param(path,'MATLABFunctionConfiguration');
configuration.FunctionScript=fileread(fullfile(module,'src','pmsm_hf_dynamics.m'));
path=Simulink.ID.getFullName([model,':',extractAfter(ports.Measurements,'blk_')]);
configuration=get_param(path,'MATLABFunctionConfiguration');
configuration.FunctionScript=fileread(fullfile(module,'src','pmsm_hf_output.m'));
disp(model_read(model,scope,'0'));
operations={b('Mux','VoltageAB',struct('Inputs','2')),b('Constant','Settings',struct('Value','cfg.Settings')), ...
    b('Integrator','PhysicalStates',struct('InitialCondition','cfg.InitialState')), ...
    b('Demux','PhysicalOutputs',struct('Outputs','10')),b('Terminator','UnusedDynamicsOutput',struct()), ...
    c('#u_alpha.y1','#VoltageAB.u1'),c('#u_beta.y1','#VoltageAB.u2'), ...
    c('#PhysicalStates.y1','#Dynamics.u1'),c('#VoltageAB.y1','#Dynamics.u2'), ...
    c('#load_torque.y1','#Dynamics.u3'),c('#Settings.y1','#Dynamics.u4'), ...
    c('#Dynamics.y1','#PhysicalStates.u1'),c('#Dynamics.y2','#UnusedDynamicsOutput.u1'), ...
    c('#PhysicalStates.y1','#Measurements.u1'),c('#Settings.y1','#Measurements.u2'),c('#Measurements.y1','#PhysicalOutputs.u1')};
for k=1:numel(outputs),operations{end+1}=c(sprintf('#PhysicalOutputs.y%d',k),['#',outputs{k},'.u1']);end
for k=1:numel(operations)
    if isfield(operations{k},'target')
        for name=names,operations{k}.target=strrep(operations{k}.target,['#',name{1},'.'],[ports.(name{1}),'.']);end
    end
end
edit(model,scope,operations,true,'incremental');
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','on', ...
    'MaskVariables','cfg=@1;','MaskStyleString','edit','MaskPromptString','PMSM physical configuration', ...
    'MaskValueString','hfPlantCfg','Position','[200 100 540 420]'))},false,'incremental');
save_system(model,fullfile(module,'src',[model,'.slx']));

new_system(test);open_system(test);initialize_hf_plant_test(test);
callback=['addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));initialize_hf_plant_test(bdroot);'];
operations={struct('op','configure','target',['config:',test],'params',struct('Solver','ode4', ...
    'SolverType','Fixed-step','FixedStep','hfPlantTestCfg.PlantStep','StopTime','hfPlantTestCfg.Duration', ...
    'ReturnWorkspaceOutputs','on','PostLoadFcn',callback)), ...
    b('FromWorkspace','VoltageStimulus',struct('VariableName','testStim','Interpolate','off', ...
        'SampleTime','hfPlantTestCfg.Ts','OutputAfterFinalValue','Holding final value')), ...
    b('Demux','Inputs',struct('Outputs','3')), ...
    struct('op','add_block','type','HFPMSM','ReferenceBlock','PMSMHighFrequencyPlant/HFPMSM', ...
        'name','Plant','ref','Plant','params',struct('MaskValueString','hfPlantCfg','Position','[300 200 640 520]')), ...
    b('Mux','PhysicalSignals',struct('Inputs','10')), ...
    b('ZeroOrderHold','SampledSignals',struct('SampleTime','hfPlantTestCfg.Ts')), ...
    b('Demux','Outputs',struct('Outputs','10')),b('Mux','TraceChannels',struct('Inputs','13')), ...
    b('ToWorkspace','SaveTrace',struct('VariableName','trace','SaveFormat','Structure With Time','MaxDataPoints','inf')), ...
    c('#VoltageStimulus.y1','#Inputs.u1'),c('#PhysicalSignals.y1','#SampledSignals.u1'), ...
    c('#SampledSignals.y1','#Outputs.u1'),c('#TraceChannels.y1','#SaveTrace.u1')};
for k=1:3
    operations=[operations,{c(sprintf('#Inputs.y%d',k),sprintf('#Plant.u%d',k)), ...
        c(sprintf('#Inputs.y%d',k),sprintf('#TraceChannels.u%d',k))}];
end
for k=1:10
    operations=[operations,{c(sprintf('#Plant.y%d',k),sprintf('#PhysicalSignals.u%d',k)), ...
        c(sprintf('#Outputs.y%d',k),sprintf('#TraceChannels.u%d',k+3))}];
end
groups={'HfCurrents',[1,2,6,7];'HfAngle',3;'HfSpeed',4;'HfTorque',5;'HfFlux',[9,10];'HfInductance',8};
for group=1:size(groups,1)
    name=groups{group,1};channels=groups{group,2};mux=[name,'Channels'];
    operations=[operations,{b('Mux',mux,struct('Inputs',num2str(numel(channels)))), ...
        b('Scope',name,struct('NumInputPorts','1')),c(['#',mux,'.y1'],['#',name,'.u1'])}];
    for k=1:numel(channels),operations{end+1}=c(sprintf('#Outputs.y%d',channels(k)),sprintf('#%s.u%d',mux,k));end
end
edit(test,'root',operations,true,'full');save_system(test,fullfile(module,'src',[test,'.slx']));
end
function operation=b(type,name,parameters)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',parameters);
end
function operation=c(source,destination)
operation=struct('op','connect','target',[source,' -> ',destination]);
end
function result=edit(model,scope,operations,complete,layout)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(operations),layout);disp(result);
disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok')
    disp(model_check(model,scope,'["all"]'));error('Inspect current model before continuing.');
end
if complete
    health=model_check(model,scope,'["all"]');disp(health);assert(~contains(string(health),'severity: error'));
end
end
function value=id(result,reference)
pattern=['(?m)^[ \t]*',regexptranslate('escape',reference),':[ \t]*(blk_\d+)'];
matches=regexp(char(result),pattern,'tokens');assert(isscalar(matches));value=matches{1}{1};
end
