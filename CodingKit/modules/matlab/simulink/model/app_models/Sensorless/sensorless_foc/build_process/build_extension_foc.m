function build_extension_foc(kind)
%BUILD_EXTENSION_FOC Substitute a linked observer in the verified bridge App.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
spec=extension_foc_spec(kind);model=spec.model;destination=fullfile(module,'src',[model '.slx']);
assert(~bdIsLoaded(model)&&~isfile(destination),'Refusing to overwrite an App.');
p=extension_foc_parameters(kind); %#ok<NASGU>
entry=which('initialize_motor_paths');root=fileparts(fileparts(fileparts(entry)));
template='SensorlessFieldWeakeningFOC';source=fullfile(root,'model','app_models','Sensorless','sensorless_fw','src',[template '.slx']);
load_system(source);assert(strcmp(get_param(template,'Dirty'),'off')&&strcmp(get_param(template,'Open'),'off'));
save_system(template,destination);close_system(template,0);initialize_extension_foc(model,spec.kind);
disp(model_read(model,'root','0'));ids=scopeIds(model,model);
callback=sprintf(['addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''parameter''),', ...
    'fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));initialize_extension_foc(bdroot,''%s'');'],spec.kind);
ops={struct('op','configure','target',['config:' model],'params',struct('PostLoadFcn',callback)), ...
    struct('op','delete','target',ids.Observer), ...
    struct('op','create_subsystem','name','Observer','ref','Observer','interface',struct('inputs',{{}},'outputs',{{}}))};
edit(model,'root',ops,false,'incremental');ids=scopeIds(model,model);
load_system(fullfile(root,'model','lib',spec.module,'src',[spec.library '.slx']));disp(model_read(spec.library,'root','0'));
source=find_system(spec.library,'SearchDepth',1,'Name',spec.export);assert(isscalar(source));
ins={'phase_voltage','current_ab','enable','reset','direction'};outs={'theta_hat','omega_hat','valid','residual_norm','start_voltage_magnitude'};ops={};
for k=1:numel(ins),ops{end+1}=b('Inport',ins{k},struct('Port',num2str(k)));end
for k=1:numel(outs),ops{end+1}=b('Outport',outs{k},struct('Port',num2str(k)));end
mask='observerCfg';if strcmp(spec.kind,'sigmoid'),mask='observerCfg|pllCfg';end
ops=[ops,{b('Demux','PhaseChannels',struct('Outputs','3')), ...
    struct('op','add_block','type','Clarke','ReferenceBlock','ClarkePark/Clarke','name','VoltageClarke','ref','VoltageClarke'), ...
    b('Mux','VoltageAB',struct('Inputs','2')),b('ZeroOrderHold','VoltageSample',struct('SampleTime','timingCfg.Ts')), ...
    b('Delay','VoltageAge',struct('SampleTime','timingCfg.Ts','DelayLength','timingCfg.FeedbackTicks*experimentCfg.UseTiming','InitialCondition','0')), ...
    b('Demux','VoltageChannels',struct('Outputs','2')),b('Demux','CurrentChannels',struct('Outputs','2')), ...
    struct('op','add_block','type',spec.export,'ReferenceBlock',source{1},'name','Estimator','ref','Estimator','params',struct('MaskValueString',mask)), ...
    b('Terminator','ZeroSequence',struct()),b('Mux','ResidualAB',struct('Inputs','2')), ...
    b('DotProduct','ResidualSquared',struct()),b('Sqrt','ResidualNorm',struct()), ...
    b('DotProduct','TerminalVoltageSquared',struct()),b('Sqrt','TerminalVoltageMagnitude',struct()), ...
    c('#phase_voltage.y1','#PhaseChannels.u1'),c('#current_ab.y1','#CurrentChannels.u1'), ...
    c('#VoltageClarke.y1','#VoltageAB.u1'),c('#VoltageClarke.y2','#VoltageAB.u2'),c('#VoltageClarke.y3','#ZeroSequence.u1'), ...
    c('#VoltageAB.y1','#VoltageSample.u1'),c('#VoltageSample.y1','#VoltageAge.u1'),c('#VoltageAge.y1','#VoltageChannels.u1'), ...
    c('#VoltageChannels.y1','#Estimator.u1'),c('#VoltageChannels.y2','#Estimator.u2'), ...
    c('#CurrentChannels.y1','#Estimator.u3'),c('#CurrentChannels.y2','#Estimator.u4'), ...
    c('#direction.y1','#Estimator.u5'),c('#enable.y1','#Estimator.u6'),c('#reset.y1','#Estimator.u7'), ...
    c('#Estimator.y1','#theta_hat.u1'),c('#Estimator.y2','#omega_hat.u1'),c('#Estimator.y3','#valid.u1'), ...
    c('#ResidualAB.y1','#ResidualSquared.u1'),c('#ResidualAB.y1','#ResidualSquared.u2'),c('#ResidualSquared.y1','#ResidualNorm.u1'), ...
    c('#ResidualNorm.y1','#residual_norm.u1'),c('#VoltageAge.y1','#TerminalVoltageSquared.u1'), ...
    c('#VoltageAge.y1','#TerminalVoltageSquared.u2'),c('#TerminalVoltageSquared.y1','#TerminalVoltageMagnitude.u1'), ...
    c('#TerminalVoltageMagnitude.y1','#start_voltage_magnitude.u1')}];
for k=1:3,ops{end+1}=c(sprintf('#PhaseChannels.y%d',k),sprintf('#VoltageClarke.u%d',k));end
switch spec.kind
    case {'mras','sigmoid'},residualPorts=[8,9];
    case {'ekf','ukf'},residualPorts=[6,7];
end
for k=1:2,ops{end+1}=c(sprintf('#Estimator.y%d',residualPorts(k)),sprintf('#ResidualAB.u%d',k));end
definitions=extension_foc_channels('observer',spec.kind);
ops=[ops,{b('Mux','TraceChannels',struct('Inputs',num2str(size(definitions,1)))), ...
    b('ToWorkspace','SaveTrace',struct('VariableName','observer_trace','SaveFormat','Structure With Time','SampleTime','currentCfg.Ts','MaxDataPoints','inf')), ...
    c('#TraceChannels.y1','#SaveTrace.u1')}];
for k=1:size(definitions,1),ops{end+1}=c(definitions{k,4},sprintf('#TraceChannels.u%d',k));end
groups={'EstimateAngleScope',{'#Estimator.y1'};'EstimateSpeedScope',{'#Estimator.y2'}; ...
    'ResidualScope',{sprintf('#Estimator.y%d',residualPorts(1)),sprintf('#Estimator.y%d',residualPorts(2)),'#ResidualNorm.y1'}; ...
    'ValidityScope',{'#Estimator.y3','#enable.y1','#reset.y1'};'TerminalVoltageScope',{'#TerminalVoltageMagnitude.y1'}};
switch spec.kind
    case 'mras',groups=[groups;{'NormalizedResidualScope',{'#Estimator.y10','#Estimator.y11'}}];
    case {'ekf','ukf'},groups=[groups;{'NISScope',{'#Estimator.y8'};'AngleUncertaintyScope',{'#Estimator.y9'};'SpeedUncertaintyScope',{'#Estimator.y10'}}];
    case 'sigmoid',groups=[groups;{'EmfScope',{'#Estimator.y4','#Estimator.y5','#Estimator.y11'}}];
end
ops=[ops,scopes(groups)];edit(model,ids.Observer,ops,true,'full');
ops={c([ids.Plant '.y3'],[ids.Observer '.u1']),c([ids.Measurement '.y1'],[ids.Observer '.u2']), ...
    c([ids.ObserverEnabledDouble '.y1'],[ids.Observer '.u3']),c([ids.inputs '.y4'],[ids.Observer '.u4']), ...
    c([ids.inputs '.y5'],[ids.Observer '.u5']),c([ids.Observer '.y5'],[ids.StartInterlock '.u4'])};
for k=1:4,ops{end+1}=c(sprintf('%s.y%d',ids.Observer,k),sprintf('%s.u%d',ids.Controller,k+1));end
edit(model,'root',ops,true,'incremental');
guard=Simulink.ID.getFullName([model ':' extractAfter(ids.StartInterlock,'blk_')]);gi=scopeIds(model,guard);
ops={struct('op','configure','target',gi.emf_magnitude,'params',struct('Name','voltage_magnitude')), ...
    struct('op','configure','target',gi.StartEmfLimit,'params',struct('Name','StartVoltageLimit','Value','startGuardCfg.MaxStartVoltage')), ...
    struct('op','configure','target',gi.LowEmf,'params',struct('Name','LowTerminalVoltage')), ...
    struct('op','configure','target',gi.ObservedEmfScope,'params',struct('Name','ObservedVoltageScope'))};
edit(model,ids.StartInterlock,ops,true,'incremental');
tidy_extension_foc(model);
save_system(model,destination);print(['-s' model],'-dpng',fullfile(module,'build_process',[spec.kind '_app_diagram.png']));
close_system(model,0);close_system(spec.library,0);fprintf('EXTENSION_FOC_BUILT %s\n',spec.kind);
end
function ids=scopeIds(model,scope)
blocks=find_system(scope,'SearchDepth',1,'Type','Block');ids=struct();
for k=1:numel(blocks)
    if strcmp(blocks{k},scope),continue;end
    name=get_param(blocks{k},'Name');assert(isvarname(name));ids.(name)=['blk_' extractAfter(Simulink.ID.getSID(blocks{k}),':')];
end
end
function operation=b(type,name,params)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',params);
end
function operation=c(source,destination)
operation=struct('op','connect','target',[source ' -> ' destination]);
end
function operations=scopes(groups)
operations={};
for k=1:size(groups,1)
    name=groups{k,1};signals=groups{k,2};mux=[name 'Channels'];
    operations=[operations,{b('Mux',mux,struct('Inputs',num2str(numel(signals)))),b('Scope',name,struct('NumInputPorts','1')),c(['#' mux '.y1'],['#' name '.u1'])}];
    for j=1:numel(signals),operations{end+1}=c(signals{j},sprintf('#%s.u%d',mux,j));end
end
end
function result=edit(model,scope,operations,complete,layout)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(operations),layout);disp(result);disp(model_read(model,scope,'0'));
if ~startsWith(strtrim(string(result)),'status: ok')
    disp(model_check(model,scope,'["all"]'));error('Inspect the partial edit before continuing.');
end
if complete
    check=model_check(model,scope,'["all"]');disp(check);assert(startsWith(strtrim(string(check)),'status: healthy'));
end
end
