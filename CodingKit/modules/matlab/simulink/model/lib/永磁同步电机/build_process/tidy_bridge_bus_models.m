function tidy_bridge_bus_models()
%TIDY_BRIDGE_BUS_MODELS Size new function blocks and lay out generated scopes.
module=fileparts(fileparts(mfilename('fullpath')));
model='PMSMBridgeBusPlant';test='PMSMBridgeBusPlantTest';
if bdIsLoaded(test)
    assert(strcmp(get_param(test,'Dirty'),'off') && strcmp(get_param(test,'Open'),'off'));
    close_system(test,0);
end
load_system(fullfile(module,'src',[model,'.slx']));
assert(strcmp(get_param(model,'Dirty'),'off') && strcmp(get_param(model,'Open'),'off'));
disp(model_read(model,'root','0'));
result=model_edit(model,'root',jsonencode({struct('op','configure','target',['config:',model], ...
    'params',struct('Lock','off'))}),'incremental');assert(contains(string(result),'status: ok'));
export=find_system(model,'SearchDepth',1,'Name','BridgeBusMotor');assert(isscalar(export));
scope=['blk_',extractAfter(Simulink.ID.getSID(export{1}),':')];disp(model_read(model,scope,'0'));
dimensions={'Step',240,440;'Measure',230,250;'BusSettings',220,110;'Settings',120,45};ops={};
for k=1:size(dimensions,1)
    block=find_system(export{1},'SearchDepth',1,'LookUnderMasks','all','Name',dimensions{k,1});assert(isscalar(block));
    id=['blk_',extractAfter(Simulink.ID.getSID(block{1}),':')];position=get_param(block{1},'Position');
    position(3:4)=position(1:2)+[dimensions{k,2},dimensions{k,3}];
    ops{end+1}=struct('op','configure','target',id,'params',struct('Position',mat2str(position)));
end
result=model_edit(model,scope,jsonencode(ops),'full');assert(contains(string(result),'status: ok'));
check=model_check(model,scope,'["all"]');assert(~contains(string(check),'severity: error'));
result=model_edit(model,'root',jsonencode({struct('op','configure','target',['config:',model], ...
    'params',struct('Lock','on'))}),'incremental');assert(contains(string(result),'status: ok'));
save_system(model,fullfile(module,'src',[model,'.slx']));close_system(model,0);
load_system(fullfile(module,'src',[test,'.slx']));
assert(strcmp(get_param(test,'Dirty'),'off') && strcmp(get_param(test,'Open'),'off'));
disp(model_read(test,'root','0'));
shortNames={'MechanicalSpeedScopeChannels','SpeedChannels'; ...
    'EquationResidualScopeChannels','ResidualChannels'; ...
    'PhaseCurrentScopeChannels','CurrentChannels'; ...
    'PhaseVoltageScopeChannels','VoltageChannels'};ops={};
for k=1:size(shortNames,1)
    block=find_system(test,'SearchDepth',1,'Name',shortNames{k,1});
    if isempty(block),continue,end
    assert(isscalar(block));id=['blk_',extractAfter(Simulink.ID.getSID(block{1}),':')];
    ops{end+1}=struct('op','configure','target',id,'params',struct('Name',shortNames{k,2}));
end
result=model_edit(test,'root',jsonencode(ops),'full');assert(contains(string(result),'status: ok'));
check=model_check(test,'root','["all"]');assert(~contains(string(check),'severity: error'));
save_system(test,fullfile(module,'src',[test,'.slx']));close_system(test,0);
if bdIsLoaded(model),close_system(model,0);end
end
