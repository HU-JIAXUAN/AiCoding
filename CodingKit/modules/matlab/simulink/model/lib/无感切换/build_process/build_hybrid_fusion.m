function build_hybrid_fusion()
%BUILD_HYBRID_FUSION Append a shared two-tracker fusion block and separate bench.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
model='SensorlessHandover';file=fullfile(module,'src',[model,'.slx']);load_system(file);
assert(strcmpi(strrep(get_param(model,'FileName'),'\','/'),strrep(file,'\','/')));
assert(isempty(find_system(model,'SearchDepth',1,'Name','HybridFusion')),'Use an isolated base-library copy to rebuild.');
edit(model,'root',{struct('op','configure','target',['config:',model],'params',struct('Lock','off'))},false,'incremental');
r=edit(model,'root',{struct('op','create_subsystem','name','HybridFusion','ref','fusion', ...
    'interface',struct('inputs',{{}},'outputs',{{}}))},false,'incremental');
scope=created_id(r,'fusion');
mask=struct('Mask','on','MaskVariables','fusionCfg=@1;','MaskStyleString','edit', ...
    'MaskPromptString','Two-tracker fusion configuration','MaskValueString','hybrid_fusion_parameters()');
edit(model,'root',{struct('op','configure','target',scope,'params',mask)},false,'incremental');
r=edit(model,scope,{b('MATLAB Function','FusionStep',struct()),b('MATLAB Function','InjectionOutput',struct())},false,'full');
step=created_id(r,'FusionStep');injection=created_id(r,'InjectionOutput');
embed(model,step,fullfile(module,'src/hybrid_fusion_step.m'));
embed(model,injection,fullfile(module,'src/hybrid_injection_output.m'));
inputs={'theta_low','omega_low','low_valid','theta_high','omega_high','high_valid','enable','reset'};
outputs={'theta_e','omega_base','omega_frame','valid','beta','injection_scale','mode','fault', ...
    'low_qualified','high_qualified','low_pi_flip','phase_gap','low_count','high_count', ...
    'loss_count','phase_correction','low_branch_ready'};
ops={b('Mux','Inputs',struct('Inputs','8')),b('Demux','Outputs',struct('Outputs','17')), ...
    b('UnitDelay','States',struct('InitialCondition','fusionCfg.State0','SampleTime','fusionCfg.Ts')), ...
    b('Constant','Parameters',struct('Value','fusionCfg.Vector')),b('Terminator','UnusedCoreInjection',struct()), ...
    c('#States.y1',[step,'.u1']),c('#Inputs.y1',[step,'.u2']),c('#Parameters.y1',[step,'.u3']), ...
    c([step,'.y1'],'#States.u1'),c([step,'.y2'],'#Outputs.u1'),c('#States.y1',[injection,'.u1']), ...
    c('#Outputs.y6','#UnusedCoreInjection.u1')};
for k=1:8
    ops=[ops,{b('Inport',inputs{k},struct('Port',num2str(k),'SampleTime','fusionCfg.Ts')), ...
        c(['#',inputs{k},'.y1'],sprintf('#Inputs.u%d',k))}];
end
ops=[ops,{c('#enable.y1',[injection,'.u2']),c('#reset.y1',[injection,'.u3'])}];
for k=1:17
    ops{end+1}=b('Outport',outputs{k},struct('Port',num2str(k)));
    if k==6,source=[injection,'.y1'];else,source=sprintf('#Outputs.y%d',k);end
    ops{end+1}=c(source,['#',outputs{k},'.u1']);
end
edit(model,scope,ops,false,'full');
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','off'))},false,'incremental');
disp(model_read(model,scope,'0'));check=model_check(model,scope,'["all"]');disp(check);
assert(contains(string(check),'status: healthy'));
mask.MaskValueString='fusionCfg';
edit(model,'root',{struct('op','configure','target',scope,'params',mask)},false,'incremental');
source=Simulink.ID.getFullName([model,':',extractAfter(scope,'blk_')]);
save_system(model);close_system(model,0);

model='HybridFusionTest';assert(~bdIsLoaded(model) && ~isfile(fullfile(module,'src',[model,'.slx'])));
new_system(model);initialize_hybrid_fusion_test(model);
callback='addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));initialize_hybrid_fusion_test(bdroot);';
ops={struct('op','configure','target',['config:',model],'params',struct('Solver','FixedStepDiscrete', ...
    'SolverType','Fixed-step','FixedStep','fusionCfg.Ts','StopTime','fusionTestCfg.Duration', ...
    'ReturnWorkspaceOutputs','on','PostLoadFcn',callback)), ...
    b('FromWorkspace','Stimulus',struct('VariableName','testStim','Interpolate','off', ...
    'SampleTime','fusionCfg.Ts','OutputAfterFinalValue','Holding final value')), ...
    b('Demux','Inputs',struct('Outputs','10')), ...
    struct('op','add_block','type','HybridFusion','ReferenceBlock',source,'name','Fusion','ref','Fusion'), ...
    b('Mux','Trace',struct('Inputs','27')),b('ToWorkspace','SaveTrace',struct('VariableName','trace', ...
    'SaveFormat','Structure With Time','SampleTime','fusionCfg.Ts','MaxDataPoints','inf')), ...
    b('Sum','AngleDifference',struct('Inputs','+-')),b('Trigonometry','ErrorSin',struct('Operator','sin')), ...
    b('Trigonometry','ErrorCos',struct('Operator','cos')),b('Trigonometry','AngleError',struct('Operator','atan2')), ...
    c('#Stimulus.y1','#Inputs.u1'),c('#Trace.y1','#SaveTrace.u1'),c('#Fusion.y1','#AngleDifference.u1'), ...
    c('#Inputs.y9','#AngleDifference.u2'),c('#AngleDifference.y1','#ErrorSin.u1'),c('#AngleDifference.y1','#ErrorCos.u1'), ...
    c('#ErrorSin.y1','#AngleError.u1'),c('#ErrorCos.y1','#AngleError.u2')};
for k=1:10
    ops{end+1}=c(sprintf('#Inputs.y%d',k),sprintf('#Trace.u%d',k));
    if k<=8,ops{end+1}=c(sprintf('#Inputs.y%d',k),sprintf('#Fusion.u%d',k));end
end
for k=1:17,ops{end+1}=c(sprintf('#Fusion.y%d',k),sprintf('#Trace.u%d',k+10));end
groups={'AngleScope',{'#Inputs.y9','#Inputs.y1','#Inputs.y4','#Fusion.y1'}; ...
    'AngleErrorScope',{'#AngleError.y1','#Fusion.y12','#Fusion.y16'}; ...
    'SpeedScope',{'#Inputs.y10','#Inputs.y2','#Inputs.y5','#Fusion.y2','#Fusion.y3'}; ...
    'WeightScope',{'#Fusion.y5','#Fusion.y6','#Fusion.y11','#Fusion.y17'}; ...
    'StatusScope',{'#Inputs.y3','#Inputs.y6','#Fusion.y4','#Fusion.y7','#Fusion.y8','#Fusion.y9','#Fusion.y10'}; ...
    'CountScope',{'#Fusion.y13','#Fusion.y14','#Fusion.y15'}};
for group=1:size(groups,1)
    name=groups{group,1};signals=groups{group,2};mux=[name,'Channels'];
    ops=[ops,{b('Mux',mux,struct('Inputs',num2str(numel(signals)))), ...
        b('Scope',name,struct('NumInputPorts','1')),c(['#',mux,'.y1'],['#',name,'.u1'])}];
    for k=1:numel(signals),ops{end+1}=c(signals{k},sprintf('#%s.u%d',mux,k));end
end
edit(model,'root',ops,true,'full');save_system(model,fullfile(module,'src',[model,'.slx']));close_system(model,0);
end
function result=edit(model,scope,ops,complete,layout)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(ops),layout);disp(result);disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok')
    disp(model_check(model,scope,'["all"]'));error('HybridFusion:Edit','%s',char(result));
end
if complete,check=model_check(model,scope,'["all"]');disp(check);assert(~contains(string(check),'severity: error'));end
end
function id=created_id(result,name)
match=regexp(char(result),['(?m)^[ \t]*',regexptranslate('escape',name),':[ \t]*(blk_\d+)'],'tokens');
assert(isscalar(match),'Inspect the editor-created ID map.');id=match{1}{1};
end
function embed(model,id,file)
block=Simulink.ID.getFullName([model,':',extractAfter(id,'blk_')]);
configuration=get_param(block,'MATLABFunctionConfiguration');configuration.FunctionScript=fileread(file);
end
function operation=b(type,name,parameters)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',parameters);
end
function operation=c(source,target)
operation=struct('op','connect','target',[source,' -> ',target]);
end
