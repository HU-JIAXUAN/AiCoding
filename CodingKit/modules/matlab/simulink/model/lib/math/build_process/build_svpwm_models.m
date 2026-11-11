function build_svpwm_models(outputDir)
%BUILD_SVPWM_MODELS Build two editable SVPWM libraries and a linked test model.
arguments
    outputDir (1,1) string
end

module = fileparts(fileparts(mfilename('fullpath')));
project = fileparts(fileparts(fileparts(module)));
addpath(fullfile(project,'docs','scripts'),fullfile(module,'parameter'));
gate = library.settingsLookup();
assert(gate.gatePass,'Resolve the Simulink library settings first.');
build_variant(outputDir,"seven_segment","SvpwmSevenSegment",true);
build_variant(outputDir,"five_segment","SvpwmFiveSegment",false);
build_test(outputDir);
end

function build_variant(outputDir,folder,model,centered)
target = fullfile(outputDir,folder);
if ~isfolder(target), mkdir(target); end
destination = fullfile(target,model+".slx");
assert(~isfile(destination) && ~bdIsLoaded(model),'Use an empty output location.');
new_system(model,'Library');
cleanup = onCleanup(@() close_system(model,0));
ports = struct('inputs',{{}},'outputs',{{}});
result = edit(model,'root',{struct('op','create_subsystem','name','SVPWM', ...
    'ref','svpwm','interface',ports)},false);
id = regexp(char(result),'svpwm:\s*(blk_\d+)','tokens','once');
assert(~isempty(id),'SVPWM subsystem ID is missing.');

ops = {block('Inport','alpha',struct('Port','1','OutDataTypeStr','double')), ...
    block('Inport','beta',struct('Port','2','OutDataTypeStr','double')), ...
    block('Inport','vdc',struct('Port','3','OutDataTypeStr','double')), ...
    block('Outport','duty_a',struct('Port','1')), ...
    block('Outport','duty_b',struct('Port','2')), ...
    block('Outport','duty_c',struct('Port','3')), ...
    block('Outport','common_mode',struct('Port','4')), ...
    block('Gain','HalfAlpha',struct('Gain','-0.5')), ...
    block('Gain','ScaledBeta',struct('Gain','sqrt(3)/2')), ...
    block('Sum','PhaseB',struct('Inputs','++')), ...
    block('Sum','PhaseC',struct('Inputs','+-')), ...
    block('Mux','Phases',struct('Inputs','3')), ...
    block('MinMax','Minimum',struct('Function','min')), ...
    block('Product','Normalize',struct('Inputs','*/')), ...
    block('Saturate','DutyLimit',struct('LowerLimit','0','UpperLimit','1')), ...
    block('Demux','Duties',struct('Outputs','3'))};
ops = [ops, connections({
    '#alpha.y1','#HalfAlpha.u1'; '#beta.y1','#ScaledBeta.u1';
    '#HalfAlpha.y1','#PhaseB.u1'; '#ScaledBeta.y1','#PhaseB.u2';
    '#HalfAlpha.y1','#PhaseC.u1'; '#ScaledBeta.y1','#PhaseC.u2';
    '#alpha.y1','#Phases.u1'; '#PhaseB.y1','#Phases.u2'; '#PhaseC.y1','#Phases.u3';
    '#Phases.y1','#Minimum.u1'; '#vdc.y1','#Normalize.u2';
    '#DutyLimit.y1','#Duties.u1'; '#Duties.y1','#duty_a.u1';
    '#Duties.y2','#duty_b.u1'; '#Duties.y3','#duty_c.u1'})];

if centered
    ops = [ops, {block('MinMax','Maximum',struct('Function','max')), ...
        block('Sum','ExtremaSum',struct('Inputs','++')), ...
        block('Gain','CommonMode',struct('Gain','-0.5')), ...
        block('Sum','ShiftedPhases',struct('Inputs','++')), ...
        block('Constant','HalfDuty',struct('Value','0.5')), ...
        block('Sum','CenteredDuty',struct('Inputs','++'))}, connections({
        '#Phases.y1','#Maximum.u1'; '#Minimum.y1','#ExtremaSum.u1';
        '#Maximum.y1','#ExtremaSum.u2'; '#ExtremaSum.y1','#CommonMode.u1';
        '#Phases.y1','#ShiftedPhases.u1'; '#CommonMode.y1','#ShiftedPhases.u2';
        '#ShiftedPhases.y1','#Normalize.u1'; '#Normalize.y1','#CenteredDuty.u1';
        '#HalfDuty.y1','#CenteredDuty.u2'; '#CenteredDuty.y1','#DutyLimit.u1';
        '#CommonMode.y1','#common_mode.u1'})];
else
    ops = [ops, {block('Sum','ShiftedPhases',struct('Inputs','+-')), ...
        block('Gain','NegativeHalfBus',struct('Gain','-0.5')), ...
        block('Sum','CommonMode',struct('Inputs','+-'))}, connections({
        '#Phases.y1','#ShiftedPhases.u1'; '#Minimum.y1','#ShiftedPhases.u2';
        '#ShiftedPhases.y1','#Normalize.u1'; '#Normalize.y1','#DutyLimit.u1';
        '#vdc.y1','#NegativeHalfBus.u1'; '#NegativeHalfBus.y1','#CommonMode.u1';
        '#Minimum.y1','#CommonMode.u2'; '#CommonMode.y1','#common_mode.u1'})];
end
edit(model,id{1},ops,true);
edit(model,'root',{configure(model,struct('Lock','on'))},false);
save_system(model,destination);
end

function build_test(outputDir)
addpath(fullfile(outputDir,'seven_segment'),fullfile(outputDir,'five_segment'));
model = 'SvpwmComparisonTest';
destination = fullfile(outputDir,[model,'.slx']);
assert(~isfile(destination) && ~bdIsLoaded(model),'Use an empty output location.');
new_system(model);
cleanup = onCleanup(@() close_system(model,0));
callback = [ ...
    'svpwmDir=fileparts(get_param(bdroot,''FileName''));', ...
    'addpath(fullfile(svpwmDir,''seven_segment''),fullfile(svpwmDir,''five_segment''),', ...
    'fullfile(svpwmDir,''..'',''..'',''parameter''));', ...
    'assignin(get_param(bdroot,''ModelWorkspace''),''svpwmTest'',svpwm_test_parameters());', ...
    'clear svpwmDir;'];
assignin(get_param(model,'ModelWorkspace'),'svpwmTest',svpwm_test_parameters());
ops = {configure(model,struct('Solver','FixedStepDiscrete','SolverType','Fixed-step', ...
    'FixedStep','svpwmTest.Ts','StopTime','svpwmTest.StopTime', ...
    'ReturnWorkspaceOutputs','on','PostLoadFcn',callback)), ...
    block('FromWorkspace','Stimulus',struct('VariableName','svpwmTest.Stimulus', ...
    'SampleTime','svpwmTest.Ts','Interpolate','off','OutputAfterFinalValue','Holding final value')), ...
    block('Demux','VoltageInputs',struct('Outputs','3')), ...
    library_block('SevenSegment','SvpwmSevenSegment/SVPWM'), ...
    library_block('FiveSegment','SvpwmFiveSegment/SVPWM'), ...
    block('Mux','TraceChannels',struct('Inputs','9')), ...
    block('Scope','ModulationScope',struct()), ...
    block('ToWorkspace','SaveTrace',struct('VariableName','trace', ...
    'SaveFormat','Structure With Time','MaxDataPoints','inf'))};
ops = [ops, connections({'#Stimulus.y1','#VoltageInputs.u1';
    '#Stimulus.y1','#TraceChannels.u1'; '#TraceChannels.y1','#SaveTrace.u1';
    '#TraceChannels.y1','#ModulationScope.u1'})];
for k = 1:3
    output = sprintf('#VoltageInputs.y%d',k);
    ops = [ops, connections({output,sprintf('#SevenSegment.u%d',k);
        output,sprintf('#FiveSegment.u%d',k)})]; %#ok<AGROW>
end
for k = 1:4
    ops = [ops, connections({sprintf('#SevenSegment.y%d',k),sprintf('#TraceChannels.u%d',k+1);
        sprintf('#FiveSegment.y%d',k),sprintf('#TraceChannels.u%d',k+5)})]; %#ok<AGROW>
end
edit(model,'root',ops,true);
save_system(model,destination);
end

function result = edit(model,scope,ops,complete)
result = open_loop_model_edit(char(model),scope,ops,complete,'full');
end

function op = configure(model,params)
op = struct('op','configure','target',"config:"+model,'params',params);
end

function op = block(type,name,params)
op = struct('op','add_block','type',type,'name',name,'ref',name,'params',params);
end

function op = library_block(name,reference)
op = struct('op','add_block','type','SVPWM','name',name,'ref',name,'ReferenceBlock',reference);
end

function ops = connections(edges)
ops = cell(1,size(edges,1));
for k = 1:numel(ops)
    ops{k} = struct('op','connect','target',[edges{k,1},' -> ',edges{k,2}]);
end
end
