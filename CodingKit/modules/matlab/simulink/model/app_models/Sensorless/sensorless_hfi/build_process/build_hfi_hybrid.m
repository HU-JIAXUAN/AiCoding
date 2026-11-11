function build_hfi_hybrid()
%BUILD_HFI_HYBRID Assemble physical HFI/EEMF with the shared bidirectional fusion.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));model='SensorlessHFIHybrid';
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
target=fullfile(module,'src',[model,'.slx']);assert(~isfile(target) && ~bdIsLoaded(model));
load_system(fullfile(module,'src/SensorlessHFIFOC.slx'));disp(model_read('SensorlessHFIFOC','root','0'));
save_system('SensorlessHFIFOC',target);
if bdIsLoaded('SensorlessHFIFOC'),close_system('SensorlessHFIFOC',0);end
if ~bdIsLoaded(model),load_system(target);end
initialize_hfi_hybrid(model);disp(model_read(model,'root','0'));
for name={'EmfObserver','SensorlessHandover'},load_system(name{1});disp(model_read(name{1},'root','0'));end
p=lookup(model,'root',{'Position','Measurement','Controller','VoltageStage','Inputs','MasterDouble', ...
    'ControlActive','SupervisorUpdate','AngleDifference','AngleScopeChannels','ValidityScopeChannels','Physical'});
callback='addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));initialize_hfi_hybrid(bdroot);';
ops={struct('op','configure','target',['config:',model],'params',struct('PostLoadFcn',callback)), ...
    struct('op','configure','target',p.Inputs,'params',struct('Outputs','11')), ...
    struct('op','configure','target',p.AngleScopeChannels,'params',struct('Inputs','5')), ...
    reference('EmfObserver','EEMF','EEMF','emfCfg|emfPllCfg'), ...
    reference('SensorlessHandover','HybridFusion','Fusion','fusionCfg'), ...
    b('Demux','EMFVoltage',struct('Outputs','2')),b('Demux','EMFCurrent',struct('Outputs','2')), ...
    b('Logic','HighValid',struct('Operator','AND','Inputs','2')),b('DataTypeConversion','HighValidDouble',struct('OutDataTypeStr','double')), ...
    b('UnitDelay','Direction',struct('InitialCondition','hybridCfg.InitialDirection','SampleTime','hfiCfg.Ts')), ...
    b('MATLAB Function','DirectionUpdate',struct()),b('Constant','DirectionSettings',struct('Value','hybridCfg.DirectionSettings'))};
r=edit(model,'root',ops,false);p=merge(p,created(r,ops));
configuration=get_param(Simulink.ID.getFullName([model,':',extractAfter(p.DirectionUpdate,'blk_')]),'MATLABFunctionConfiguration');
configuration.FunctionScript=fileread(fullfile(module,'src/hfi_hybrid_direction.m'));

disp(model_read(model,p.Position,'0'));position=lookup(model,p.Position,{'Polarity','Axis'});
ops={b('Inport','injection_scale',struct('Port','6','SampleTime','hfiCfg.Ts')),b('Product','FusionInjection',struct('Inputs','**')), ...
    c([position.Polarity,'.y3'],'#FusionInjection.u1'),c('#injection_scale.y1','#FusionInjection.u2'), ...
    c('#FusionInjection.y1',[position.Axis,'.u5'])};
edit(model,p.Position,ops,true);

ops={c('#Position.y2','#Fusion.u1'),c('#Position.y3','#Fusion.u2'),c('#Position.y4','#Fusion.u3'), ...
    c('#EEMF.y1','#Fusion.u4'),c('#EEMF.y2','#Fusion.u5'),c('#EEMF.y3','#HighValid.u1'), ...
    c('#Inputs.y11','#HighValid.u2'),c('#HighValid.y1','#HighValidDouble.u1'),c('#HighValidDouble.y1','#Fusion.u6'), ...
    c('#MasterDouble.y1','#Fusion.u7'),c('#Inputs.y3','#Fusion.u8'),c('#Fusion.y6','#Position.u6'), ...
    c('#Fusion.y1','#Controller.u2'),c('#Fusion.y2','#Controller.u3'),c('#Fusion.y4','#ControlActive.u2'), ...
    c('#Fusion.y4','#SupervisorUpdate.u2'),c('#Fusion.y1','#AngleDifference.u1'), ...
    c('#Fusion.y1','#AngleScopeChannels.u2'),c('#Position.y2','#AngleScopeChannels.u4'),c('#EEMF.y1','#AngleScopeChannels.u5'), ...
    c('#Fusion.y4','#ValidityScopeChannels.u1'),c('#VoltageStage.y2','#EMFVoltage.u1'),c('#Measurement.y1','#EMFCurrent.u1'), ...
    c('#Direction.y1','#EEMF.u5'),c('#MasterDouble.y1','#EEMF.u6'),c('#Inputs.y3','#EEMF.u7'), ...
    c('#Direction.y1','#DirectionUpdate.u1'),c('#Fusion.y2','#DirectionUpdate.u2'),c('#MasterDouble.y1','#DirectionUpdate.u3'), ...
    c('#Inputs.y3','#DirectionUpdate.u4'),c('#DirectionSettings.y1','#DirectionUpdate.u5'),c('#DirectionUpdate.y1','#Direction.u1')};
for k=1:2,ops=[ops,{c(sprintf('#EMFVoltage.y%d',k),sprintf('#EEMF.u%d',k)),c(sprintf('#EMFCurrent.y%d',k),sprintf('#EEMF.u%d',k+2))}];end
ops=[ops,{b('Mux','FusionTrace',struct('Inputs','17')),b('Mux','EMFTrace',struct('Inputs','12')), ...
    b('Mux','ObserverStateTrace',struct('Inputs','4')),c('#Direction.y1','#ObserverStateTrace.u1'), ...
    c('#Inputs.y11','#ObserverStateTrace.u2'),c('#EEMF.y3','#ObserverStateTrace.u3'),c('#HighValidDouble.y1','#ObserverStateTrace.u4')}];
for k=1:17,ops{end+1}=c(sprintf('#Fusion.y%d',k),sprintf('#FusionTrace.u%d',k));end
for k=1:12,ops{end+1}=c(sprintf('#EEMF.y%d',k),sprintf('#EMFTrace.u%d',k));end
for pair={{'FusionTrace','fusion_trace'},{'EMFTrace','emf_trace'},{'ObserverStateTrace','observer_state_trace'}}
    entry=pair{1};name=['Log',entry{1}];
    ops=[ops,{b('ToWorkspace',name,struct('VariableName',entry{2},'SaveFormat','Structure With Time', ...
        'SampleTime','hfiCfg.Ts','MaxDataPoints','inf')),c(['#',entry{1},'.y1'],['#',name,'.u1'])}];
end
groups={'FusionScope',{'#Fusion.y5','#Fusion.y6','#Fusion.y9','#Fusion.y10','#Fusion.y11','#Fusion.y17'}; ...
    'EMFSpeedScope',{'#Physical.y4','#Position.y3','#EEMF.y2','#Fusion.y2','#Fusion.y3'}; ...
    'EMFVoltageScope',{'#EEMF.y4','#EEMF.y5','#EEMF.y11'}; ...
    'EMFResidualScope',{'#EEMF.y8','#EEMF.y9'}; ...
    'FusionPhaseScope',{'#Fusion.y12','#Fusion.y16'}; ...
    'FusionStateScope',{'#Fusion.y7','#Fusion.y8','#EEMF.y3','#Inputs.y11','#Direction.y1'}};
for g=1:size(groups,1)
    name=groups{g,1};sources=groups{g,2};mux=[name,'Channels'];
    ops=[ops,{b('Mux',mux,struct('Inputs',num2str(numel(sources)))),b('Scope',name,struct('NumInputPorts','1')), ...
        c(['#',mux,'.y1'],['#',name,'.u1'])}];
    for k=1:numel(sources),ops{end+1}=c(sources{k},sprintf('#%s.u%d',mux,k));end
end
edit(model,'root',resolve(ops,p),true);save_system(model,target);close_system(model,0);
end
function result=edit(model,scope,ops,complete)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(ops),'incremental');disp(result);disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok'),disp(model_check(model,scope,'["all"]'));error('HFIHybrid:Edit','%s',char(result));end
if complete,check=model_check(model,scope,'["all"]');disp(check);assert(~contains(string(check),'severity: error'));end
end
function p=lookup(model,scope,names)
if strcmp(scope,'root'),location=model;else,location=Simulink.ID.getFullName([model,':',extractAfter(scope,'blk_')]);end
p=struct();
for k=1:numel(names)
    found=find_system(location,'SearchDepth',1,'Name',names{k});assert(isscalar(found),names{k});
    sid=Simulink.ID.getSID(found{1});p.(names{k})=['blk_',char(extractAfter(sid,':'))];
end
end
function operation=reference(model,name,instance,mask)
found=find_system(model,'SearchDepth',1,'Name',name);assert(isscalar(found));source=Simulink.ID.getFullName(Simulink.ID.getSID(found{1}));
operation=struct('op','add_block','type',get_param(source,'Name'),'ReferenceBlock',source,'name',instance,'ref',instance,'params',struct('MaskValueString',mask));
end
function p=created(result,ops)
p=struct();
for k=1:numel(ops)
    if ~isfield(ops{k},'ref'),continue;end
    name=ops{k}.ref;match=regexp(char(result),['(?m)^[ \t]*',regexptranslate('escape',name),':[ \t]*(blk_\d+)'],'tokens');
    assert(isscalar(match));p.(name)=match{1}{1};
end
end
function p=merge(p,other)
names=fieldnames(other);for k=1:numel(names),p.(names{k})=other.(names{k});end
end
function ops=resolve(ops,p)
names=fieldnames(p);
for k=1:numel(ops)
    if ~isfield(ops{k},'target'),continue;end
    for j=1:numel(names),ops{k}.target=strrep(ops{k}.target,['#',names{j},'.'],[p.(names{j}),'.']);end
end
end
function operation=b(type,name,parameters)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',parameters);
end
function operation=c(source,target)
operation=struct('op','connect','target',[source,' -> ',target]);
end
