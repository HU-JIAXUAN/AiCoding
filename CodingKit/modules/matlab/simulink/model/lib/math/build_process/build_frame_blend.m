function build_frame_blend(outputFolder)
%BUILD_FRAME_BLEND Add a shared coordinate-aware current-reference blend.
assert(strcmp(version('-release'),'2026b'));
gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
libraryName='ClarkePark';testName='FrameBlendTest';
assert(isfolder(outputFolder) && ~bdIsLoaded(testName));
assert(~isfile(fullfile(outputFolder,[libraryName,'.slx'])) && ~isfile(fullfile(outputFolder,[testName,'.slx'])));
load_system(fullfile(module,'src',[libraryName,'.slx']));
assert(strcmp(get_param(libraryName,'Dirty'),'off'));
assert(strcmpi(get_param(libraryName,'FileName'),fullfile(module,'src',[libraryName,'.slx'])));
read=model_read(libraryName,'root','0');disp(read);
existing=regexp(char(read),'- id: (blk_\d+)\s+Name: BlendDQ','tokens');assert(numel(existing)<=1);
save_system(libraryName,fullfile(outputFolder,[libraryName,'.slx']));
edit(libraryName,'root',{struct('op','configure','target',['config:',libraryName],'params',struct('Lock','off'))},false,'incremental');
if isempty(existing)
result=edit(libraryName,'root',{struct('op','create_subsystem','name','BlendDQ', ...
    'ref','blend','interface',struct('inputs',{{}},'outputs',{{}}))},false,'incremental');
parent=createdId(result,'blend');
result=edit(libraryName,parent,{b('MATLAB Function','Blend',struct())},false,'full');
core=createdId(result,'Blend');
corePath=Simulink.ID.getFullName([libraryName,':',extractAfter(core,'blk_')]);
else
    parent=existing{1}{1};parentPath=Simulink.ID.getFullName([libraryName,':',extractAfter(parent,'blk_')]);
    observed=find_system(parentPath,'SearchDepth',1,'Name','Blend');assert(numel(observed)==1);
    corePath=observed{1};
end
configuration=get_param(corePath,'MATLABFunctionConfiguration');
configuration.FunctionScript=fileread(fullfile(module,'src','blend_dq.m'));
disp(model_read(libraryName,parent,'0'));
if isempty(existing)
inputs={'start_current','closed_current','theta_start','theta_control','beta','enable','reset'};operations={};
for index=1:7
    operations=[operations,{b('Inport',inputs{index},struct('Port',num2str(index))), ...
        c(['#',inputs{index},'.y1'],sprintf('%s.u%d',core,index))}];
end
operations=[operations,{b('Outport','reference',struct('Port','1')),c([core,'.y1'],'#reference.u1')}];
edit(libraryName,parent,operations,true,'full');
else
    check=model_check(libraryName,parent,'["all"]');disp(check);assert(~contains(string(check),'severity: error'));
end
edit(libraryName,'root',{struct('op','configure','target',['config:',libraryName],'params',struct('Lock','on'))},false,'incremental');
save_system(libraryName,fullfile(outputFolder,[libraryName,'.slx']));
parentPath=Simulink.ID.getFullName([libraryName,':',extractAfter(parent,'blk_')]);
new_system(testName);open_system(testName);initialize_frame_blend_test(testName);
callback=['addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));', ...
    'initialize_frame_blend_test(bdroot);'];
operations={struct('op','configure','target',['config:',testName],'params', ...
    struct('Solver','FixedStepDiscrete','SolverType','Fixed-step','FixedStep','blendTestCfg.Ts', ...
    'StopTime','blendTestCfg.Duration','ReturnWorkspaceOutputs','on','PostLoadFcn',callback)), ...
    b('FromWorkspace','stimulus',struct('VariableName','testStim','Interpolate','off','SampleTime','blendTestCfg.Ts', ...
    'OutputAfterFinalValue','Holding final value')), ...
    b('Demux','inputs',struct('Outputs','[2 2 1 1 1 1 1]')), ...
    struct('op','add_block','type','BlendDQ','ReferenceBlock',parentPath,'name','BlendDQ','ref','blend'), ...
    b('Mux','trace_channels',struct('Inputs','2')), ...
    b('ToWorkspace','trace',struct('VariableName','trace','SaveFormat','Structure With Time','MaxDataPoints','inf')), ...
    c('#stimulus.y1','#inputs.u1'),c('#stimulus.y1','#trace_channels.u1'), ...
    c('#blend.y1','#trace_channels.u2'),c('#trace_channels.y1','#trace.u1')};
for index=1:7,operations{end+1}=c(sprintf('#inputs.y%d',index),sprintf('#blend.u%d',index));end
groups={'ReferenceScope',{'#blend.y1'};'AnglesScope',{'#inputs.y3','#inputs.y4'}; ...
    'BlendScope',{'#inputs.y5','#inputs.y6','#inputs.y7'}};
for group=1:size(groups,1)
    name=groups{group,1};sources=groups{group,2};mux=[name,'_mux'];
    operations=[operations,{b('Mux',mux,struct('Inputs',num2str(numel(sources)))), ...
        b('Scope',name,struct('NumInputPorts','1')),c(['#',mux,'.y1'],['#',name,'.u1'])}];
    for index=1:numel(sources),operations{end+1}=c(sources{index},sprintf('#%s.u%d',mux,index));end
end
edit(testName,'root',operations,true,'full');save_system(testName,fullfile(outputFolder,[testName,'.slx']));
print(['-s',parentPath],'-dpng',fullfile(module,'build_process','blend_diagram.png'));
print(['-s',testName],'-dpng',fullfile(module,'build_process','blend_test_diagram.png'));
end
function operation=b(type,name,parameters)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',parameters);
end
function operation=c(source,destination)
operation=struct('op','connect','target',[source,' -> ',destination]);
end
function id=createdId(result,reference)
match=regexp(char(result),[reference,':\s*(blk_\d+)'],'tokens');assert(isscalar(match));id=match{1}{1};
end
function result=edit(model,scope,operations,complete,layout)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(operations),layout);disp(result);
disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok')
    disp(model_check(model,scope,'["all"]'));error('Inspect the partial or failed edit.');
end
if complete
    check=model_check(model,scope,'["all"]');disp(check);assert(~contains(string(check),'severity: error'));
end
end
