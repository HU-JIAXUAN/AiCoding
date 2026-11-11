function build_pmsm_bridge_bus()
%BUILD_PMSM_BRIDGE_BUS Add a runtime DC-bus port without altering old exports.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));
sourceModule=fileparts(fileparts(which('pmsm_bridge_step')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
model='PMSMBridgeBusPlant';test='PMSMBridgeBusPlantTest';
assert(~bdIsLoaded(model) && ~bdIsLoaded(test));
assert(~isfile(fullfile(module,'src',[model,'.slx'])) && ~isfile(fullfile(module,'src',[test,'.slx'])));
if bdIsLoaded('PMSMBridgePlantTest')
    assert(strcmp(get_param('PMSMBridgePlantTest','Dirty'),'off'));
    assert(strcmp(get_param('PMSMBridgePlantTest','Open'),'off'));
    close_system('PMSMBridgePlantTest',0);
end
load_system(fullfile(sourceModule,'src','PMSMBridgePlant.slx'));
assert(strcmp(get_param('PMSMBridgePlant','Dirty'),'off'));
save_system('PMSMBridgePlant',fullfile(module,'src',[model,'.slx']));
disp(model_read(model,'root','0'));
root=at(model,'root');core=root.BridgeMotor;
edit(model,'root',{struct('op','configure','target',['config:',model],'params',struct('Lock','off')), ...
    struct('op','configure','target',core,'params',struct('Name','BridgeBusMotor'))},false,'incremental');
known=at(model,core);
result=edit(model,core,{b('Inport','bus_voltage',struct('Port','4','SampleTime','cfg.Ts')), ...
    b('MATLAB Function','BusSettings',struct())},false,'incremental');
busId=createdId(result,'BusSettings');busPort=createdId(result,'bus_voltage');
configuration=get_param(Simulink.ID.getFullName([model,':',extractAfter(busId,'blk_')]),'MATLABFunctionConfiguration');
configuration.FunctionScript=fileread(fullfile(module,'src','bridge_bus_settings.m'));
edit(model,core,{c([known.Settings,'.y1'],[busId,'.u1']), ...
    c([busPort,'.y1'],[busId,'.u2']),c([busId,'.y1'],[known.Step,'.u5']), ...
    c([busId,'.y1'],[known.Measure,'.u2'])},true,'incremental');
edit(model,'root',{struct('op','configure','target',['config:',model],'params',struct('Lock','on'))},false,'incremental');
save_system(model,fullfile(module,'src',[model,'.slx']));

load_system(fullfile(sourceModule,'src','PMSMBridgePlantTest.slx'));
assert(strcmp(get_param('PMSMBridgePlantTest','Dirty'),'off'));
save_system('PMSMBridgePlantTest',fullfile(module,'src',[test,'.slx']));
initialize_bridge_bus_test(test);disp(model_read(test,'root','0'));
known=at(test,'root');destinations=outputs(test,known.Plant);
callback=['addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));initialize_bridge_bus_test(bdroot);'];
source=Simulink.ID.getFullName([model,':',extractAfter(core,'blk_')]);
o={struct('op','configure','target',['config:',test],'params',struct('PostLoadFcn',callback)), ...
    struct('op','configure','target',known.Stimulus,'params',struct('VariableName','bridgeBusStim')), ...
    struct('op','configure','target',known.Inputs,'params',struct('Outputs','6')), ...
    struct('op','delete','target',known.Plant),struct('op','delete','target',known.BusPower), ...
    struct('op','add_block','type','BridgeBusMotor','ReferenceBlock',source,'name','Plant','ref','Plant', ...
    'params',struct('MaskValueString','bridgeCfg')), ...
    b('Product','BusPower',struct('Inputs','**')), ...
    b('Scope','BusVoltageScope',struct('NumInputPorts','1')), ...
    b('Scope','BusCurrentScope',struct('NumInputPorts','1')), ...
    c([known.Duty,'.y1'],'#Plant.u1'),c([known.Inputs,'.y4'],'#Plant.u2'), ...
    c([known.Inputs,'.y5'],'#Plant.u3'),c([known.Inputs,'.y6'],'#Plant.u4'), ...
    c([known.Inputs,'.y6'],'#BusPower.u2'),c('#Plant.y8','#BusPower.u1'), ...
    c([known.Inputs,'.y6'],'#BusVoltageScope.u1'),c('#Plant.y8','#BusCurrentScope.u1')};
for k=1:numel(destinations)
    for j=1:numel(destinations{k})
        destination=destinations{k}{j};
        if startsWith(destination,[known.BusPower,'.']),continue,end
        o{end+1}=c(sprintf('#Plant.y%d',k),destination);
    end
end
% Existing power Scope receives dynamic Vdc[k]*Idc[k], with no fixed Gain.
powerDestinations=outputs(test,known.BusPower); %#ok<NASGU> captured below before deletion applies
for j=1:numel(powerDestinations{1}),o{end+1}=c('#BusPower.y1',powerDestinations{1}{j});end
edit(test,'root',o,true,'incremental');
save_system(test,fullfile(module,'src',[test,'.slx']));
close_system(test,0);close_system(model,0);
tidy_bridge_bus_models();
end
function ids=at(model,scope)
if strcmp(scope,'root'),owner=model;else,owner=Simulink.ID.getFullName([model,':',extractAfter(scope,'blk_')]);end
blocks=find_system(owner,'SearchDepth',1,'LookUnderMasks','all','Type','Block');ids=struct();
for k=1:numel(blocks)
    if strcmp(blocks{k},owner),continue,end
    ids.(get_param(blocks{k},'Name'))=['blk_',extractAfter(Simulink.ID.getSID(blocks{k}),':')];
end
end
function destinations=outputs(model,id)
block=Simulink.ID.getFullName([model,':',extractAfter(id,'blk_')]);ports=get_param(block,'PortHandles');
destinations=cell(1,numel(ports.Outport));
for k=1:numel(ports.Outport)
    line=get_param(ports.Outport(k),'Line');targets=[];
    if line~=-1,targets=get_param(line,'DstPortHandle');end
    entries={};
    for target=reshape(targets,1,[])
        if target==-1,continue,end
        parent=get_param(target,'Parent');sid=extractAfter(Simulink.ID.getSID(parent),':');
        entries{end+1}=sprintf('blk_%s.u%d',sid,get_param(target,'PortNumber'));
    end
    destinations{k}=entries;
end
end
function operation=b(type,name,params)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',params);
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
    disp(model_check(model,scope,'["all"]'));error('Inspect partial bridge-bus model before continuing.');
end
if complete
    check=model_check(model,scope,'["all"]');disp(check);assert(~contains(string(check),'severity: error'));
end
end
