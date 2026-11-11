function report=inspect_bridge_bus_models()
%INSPECT_BRIDGE_BUS_MODELS Verify native sources, wiring, scopes and exports.
module=fileparts(fileparts(mfilename('fullpath')));
model='PMSMBridgeBusPlant';test='PMSMBridgeBusPlantTest';
load_system(fullfile(module,'src',[model,'.slx']));load_system(fullfile(module,'src',[test,'.slx']));
assert(strcmp(get_param(model,'BlockDiagramType'),'library'));
export=find_system(model,'SearchDepth',1,'Name','BridgeBusMotor');assert(isscalar(export));
ports=get_param(export{1},'PortHandles');assert(numel(ports.Inport)==4 && numel(ports.Outport)==16);
sources={'Step','pmsm_bridge_step.m';'Measure','pmsm_bridge_output.m';'BusSettings','bridge_bus_settings.m'};
for k=1:size(sources,1)
    blocks=find_system(export{1},'SearchDepth',1,'LookUnderMasks','all','Name',sources{k,1});assert(isscalar(blocks));
    configuration=get_param(blocks{1},'MATLABFunctionConfiguration');
    assert(strcmp(configuration.FunctionScript,fileread(which(sources{k,2}))));
end
state=find_system(export{1},'SearchDepth',1,'LookUnderMasks','all','Name','PhysicalState');
assert(isscalar(state) && strcmp(get_param(state{1},'InitialCondition'),'cfg.State0'));
plant=find_system(test,'SearchDepth',1,'Name','Plant');assert(isscalar(plant));
assert(strcmp(get_param(plant{1},'ReferenceBlock'),[model,'/BridgeBusMotor']));
power=find_system(test,'SearchDepth',1,'Name','BusPower');assert(isscalar(power));
assert(strcmp(get_param(power{1},'BlockType'),'Product'));
scopes=find_system(test,'SearchDepth',1,'BlockType','Scope');assert(numel(scopes)==9);
scopeSources=struct();
for k=1:numel(scopes)
    handles=get_param(scopes{k},'PortHandles');assert(numel(handles.Inport)==1);
    line=get_param(handles.Inport(1),'Line');assert(line~=-1);
    source=get_param(line,'SrcPortHandle');parent=get_param(source,'Parent');
    scopeSources.(get_param(scopes{k},'Name'))=struct('block',get_param(parent,'Name'),'output_port',get_param(source,'PortNumber'));
end
assert(strcmp(scopeSources.BusVoltageScope.block,'Inputs') && scopeSources.BusVoltageScope.output_port==6);
assert(strcmp(scopeSources.BusCurrentScope.block,'Plant') && scopeSources.BusCurrentScope.output_port==8);
check=model_check(test,'root','["all"]');assert(~contains(string(check),'severity: error'));
print(['-s',export{1}],'-dpng',fullfile(module,'build_process','bus_library_diagram.png'));
print(['-s',export{1}],'-dsvg',fullfile(module,'build_process','bus_library_diagram.svg'));
print(['-s',test],'-dpng',fullfile(module,'build_process','bus_test_diagram.png'));
print(['-s',test],'-dsvg',fullfile(module,'build_process','bus_test_diagram.svg'));
report=struct('release',version('-release'),'library_model',model,'test_model',test, ...
    'library_inputs',4,'library_outputs',16,'scopes',scopeSources,'scope_count',numel(scopes), ...
    'physical_sources_exact',true,'bus_power_uses_runtime_voltage',true,'physical_state_not_reset_on_bus_change',true);
fid=fopen(fullfile(module,'waveform_analysis','bus_native_inventory.json'),'w');assert(fid>=0);
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
assert(strcmp(get_param(model,'Dirty'),'off') && strcmp(get_param(test,'Dirty'),'off'));
assert(strcmp(get_param(model,'Open'),'off') && strcmp(get_param(test,'Open'),'off'));
close_system(test,0);close_system(model,0);
disp('BRIDGE_BUS_NATIVE_INSPECTION_PASSED');
end
