function build_open_loop_drive(outputModule)
%BUILD_OPEN_LOOP_DRIVE Create paired reusable oscillator/interlock and Test.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
sourceModule=fileparts(fileparts(mfilename('fullpath')));
if nargin==0,outputModule=sourceModule;end
addpath(fullfile(sourceModule,'src'),fullfile(sourceModule,'parameter'));
libraryName='OpenLoopDrive';testName='OpenLoopDriveTest';
assert(~bdIsLoaded(libraryName)&&~bdIsLoaded(testName));
assert(~isfile(fullfile(outputModule,'src',[libraryName '.slx']))&&~isfile(fullfile(outputModule,'src',[testName '.slx'])));
new_system(libraryName,'Library');
r=edit(libraryName,'root',{struct('op','create_subsystem','name','Reference','ref','Reference','interface',struct('inputs',{{}},'outputs',{{}}))},false);
scope=id(r,'Reference');subsystem=Simulink.ID.getFullName([libraryName ':' extractAfter(scope,'blk_')]);
r=edit(libraryName,scope,{b('MATLAB Function','Update',struct()),b('MATLAB Function','ReadState',struct())},false);
for pair={'Update','open_loop_drive_update.m';'ReadState','open_loop_drive_output.m'}'
    block=Simulink.ID.getFullName([libraryName ':' extractAfter(id(r,pair{1}),'blk_')]);
    cfg=get_param(block,'MATLABFunctionConfiguration');cfg.FunctionScript=fileread(fullfile(sourceModule,'src',pair{2}));
end
disp(model_read(libraryName,scope,'0'));ids=scopeIds(libraryName,subsystem);
ins={'frequency_ref','enable','reset','current_norm','terminal_voltage','bus_voltage'};
outs={'theta','frequency','amplitude','pwm_enable','stage','fault','elapsed','voltage_limited'};ops={};
for k=1:6,ops{end+1}=b('Inport',ins{k},struct('Port',num2str(k),'SampleTime','openLoopCfg.Ts'));end
for k=1:8,ops{end+1}=b('Outport',outs{k},struct('Port',num2str(k)));end
ops=[ops,{b('Mux','Inputs',struct('Inputs','6')),b('Constant','Settings',struct('Value','openLoopCfg.Vector')), ...
    b('UnitDelay','State',struct('InitialCondition','openLoopCfg.State0','SampleTime','openLoopCfg.Ts')), ...
    b('Demux','Outputs',struct('Outputs','8')),c('#State.y1',[ids.Update '.u1']),c('#Inputs.y1',[ids.Update '.u2']), ...
    c('#Settings.y1',[ids.Update '.u3']),c([ids.Update '.y1'],'#State.u1'), ...
    c('#State.y1',[ids.ReadState '.u1']),c('#enable.y1',[ids.ReadState '.u2']),c('#reset.y1',[ids.ReadState '.u3']), ...
    c('#Settings.y1',[ids.ReadState '.u4']),c([ids.ReadState '.y1'],'#Outputs.u1')}];
for k=1:6,ops{end+1}=c(['#' ins{k} '.y1'],sprintf('#Inputs.u%d',k));end
for k=1:8,ops{end+1}=c(sprintf('#Outputs.y%d',k),['#' outs{k} '.u1']);end
edit(libraryName,scope,ops,true);
edit(libraryName,'root',{struct('op','configure','target',scope,'params',struct('Mask','on','MaskVariables','openLoopCfg=@1;', ...
    'MaskStyleString','edit','MaskPromptString','Software field and interlock configuration','MaskValueString','open_loop_drive_parameters()')), ...
    struct('op','configure','target',['config:' libraryName],'params',struct('Lock','on'))},false);
save_system(libraryName,fullfile(outputModule,'src',[libraryName '.slx']));close_system(libraryName,0);
new_system(testName);initialize_open_loop_drive_test(testName);
callback='addpath(fullfile(fileparts(get_param(bdroot,''FileName'')),''..'',''build_process''));initialize_open_loop_drive_test(bdroot);';
ops={struct('op','configure','target',['config:' testName],'params',struct('Solver','FixedStepDiscrete','SolverType','Fixed-step','FixedStep','openLoopCfg.Ts', ...
    'StopTime','openLoopTestCfg.Duration','ReturnWorkspaceOutputs','on','PostLoadFcn',callback)), ...
    b('FromWorkspace','Stimulus',struct('VariableName','testStim','Interpolate','off','SampleTime','openLoopCfg.Ts','OutputAfterFinalValue','Holding final value')), ...
    b('Demux','Inputs',struct('Outputs','6')),struct('op','add_block','type','Reference','ReferenceBlock',subsystem,'name','Reference','ref','Reference','params',struct('MaskValueString','openLoopCfg')), ...
    b('Mux','Trace',struct('Inputs','14')),b('ToWorkspace','SaveTrace',struct('VariableName','trace','SaveFormat','Structure With Time','SampleTime','openLoopCfg.Ts','MaxDataPoints','inf')), ...
    c('#Stimulus.y1','#Inputs.u1'),c('#Trace.y1','#SaveTrace.u1')};
for k=1:6,ops=[ops,{c(sprintf('#Inputs.y%d',k),sprintf('#Reference.u%d',k)),c(sprintf('#Inputs.y%d',k),sprintf('#Trace.u%d',k))}];end
for k=1:8,ops{end+1}=c(sprintf('#Reference.y%d',k),sprintf('#Trace.u%d',k+6));end
groups={'AngleScope',[7];'FrequencyScope',[1,8];'AmplitudeScope',[9,14];'StatusScope',[2,3,10,11,12];'ObservationScope',[4,5,6,13]};
for k=1:size(groups,1)
    name=groups{k,1};cols=groups{k,2};mux=[name 'Channels'];
    ops=[ops,{b('Mux',mux,struct('Inputs',num2str(numel(cols)))),b('Scope',name,struct('NumInputPorts','1')),c(['#' mux '.y1'],['#' name '.u1'])}];
    for j=1:numel(cols)
        col=cols(j);if col<=6,source=sprintf('#Inputs.y%d',col);else,source=sprintf('#Reference.y%d',col-6);end
        ops{end+1}=c(source,sprintf('#%s.u%d',mux,j));
    end
end
edit(testName,'root',ops,true);save_system(testName,fullfile(outputModule,'src',[testName '.slx']));close_system(testName,0);
end
function result=edit(model,scope,ops,complete)
result=open_loop_model_edit(model,scope,ops,complete,'full');
end
function op=b(type,name,params),op=struct('op','add_block','type',type,'name',name,'ref',name,'params',params);end
function op=c(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
function value=id(text,name)
match=regexp(char(text),['(?m)^\s*' regexptranslate('escape',name) ':\s*(blk_\d+)'],'tokens');assert(isscalar(match));value=match{1}{1};
end
function ids=scopeIds(model,scope)
blocks=find_system(scope,'SearchDepth',1,'Type','Block');ids=struct();
for k=1:numel(blocks),if strcmp(blocks{k},scope),continue;end;ids.(get_param(blocks{k},'Name'))=['blk_' extractAfter(Simulink.ID.getSID(blocks{k}),':')];end
end
