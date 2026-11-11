function build_protected_libraries(root, inventoryFile, work, first, stride)
% Build each exported library subsystem as a protected Model Reference.
% The source library and test diagrams are only loaded. Temporary copies are
% converted in memory and only the protected files go to the delivery folder.
pathBefore=path;
cfgBefore=Simulink.fileGenControl('getConfig');
cwdBefore=pwd;
cleanup=onCleanup(@()restoreSession(pathBefore,cfgBefore,cwdBefore));
data=jsondecode(fileread(inventoryFile));
entries=data.exports;
addpath(fullfile(root,'docs','scripts'));initialize_motor_paths();
if ~isfolder(work),mkdir(work);end
out=fullfile(work,'delivery');
if ~isfolder(out),mkdir(out);end
for i=first:stride:numel(entries)
    item=entries(i);
    name=exportName(item,entries);
    caseDir=fullfile(work,name);
    if ~isfolder(caseDir),mkdir(caseDir);end
    recordFile=fullfile(out,[name '.json']);
    if isfile(recordFile)
        old=jsondecode(fileread(recordFile));
        if strcmp(old.status,'passed')&&isfield(old,'solver_configuration')&& ...
                isfield(old.solver_configuration,'UpdateModelReferenceTargets')&& ...
                isfile(fullfile(out,[name '.slxp']))
            continue
        end
    end
    fprintf('START %d/%d %s %s\n',i,numel(entries),name,item.block);
    attempts={};
    choices=item.candidates;
    if iscell(choices)&&~isempty(choices),choices=[choices{:}];end
    if ~isempty(choices)
        rank=[choices.depth]+10*~endsWith({choices.model},'Test');
        if strcmp(item.library,'PMSMPlant')
            rank=rank-20*strcmp({choices.model},'PMSMPlantTest');
        elseif strcmp(item.library,'PMSMHighFrequencyPlant')
            rank=rank-20*strcmp({choices.model},'PMSMHighFrequencyPlantTest');
        end
        [~,order]=sort(rank);
        choices=choices(order);
    end
    completed=false;
    for j=1:min(numel(choices),5)
        existing=loaded();
        fixture=choices(j);
        try
            attemptDir=fullfile(caseDir,sprintf('attempt_%d',j));
            if ~isfolder(attemptDir),mkdir(attemptDir);end
            cd(attemptDir);
            wrapper=fullfile(attemptDir,[name '.slx']);
            if isfile(wrapper)
                assert(movefile(wrapper,fullfile(attemptDir,[name '_previous.slx']),'f'));
            end
            Simulink.fileGenControl('set','CacheFolder',fullfile(attemptDir,'cache'), ...
                'CodeGenFolder',fullfile(attemptDir,'codegen'),'createDir',true);
            report=buildOne(item,name,fixture,attemptDir,out);
            writeJson(recordFile,report);
            fprintf('PASS %s outputs=%d max_error=%g\n',name,numel(report.outputs),report.max_error);
            completed=true;
        catch ME
            attempts{end+1}=struct('fixture',fixture.block,'message',getReport(ME,'basic','hyperlinks','off'));
            fprintf('FAIL %s (%s): %s\n',name,fixture.model,ME.message);
        end
        closeNew(existing);
        if completed,break,end
    end
    if ~completed
        writeJson(recordFile,struct('status','failed','name',name,'source',item.source, ...
            'block',item.block,'attempts',{attempts}));
    end
end
end

function report=buildOne(item,name,fixture,caseDir,out)
load_system(fixture.file);
m=fixture.model;
b=Simulink.ID.getFullName(fixture.sid);
assert(strcmp(get_param(b,'ReferenceBlock'),item.block));
if bdIsLoaded(name),close_system(name,0);end
fixture.input_profile='existing';
if ismember(m,{'PMSMPlantTest','PMSMHighFrequencyPlantTest'})
    % Continuous electrical/mechanical plants take continuous inputs.
    % The editable virtual subsystem also accepts held inputs, which the
    % reference-model conversion cannot propagate through continuous states.
    sources=find_system(m,'SearchDepth',1,'BlockType','FromWorkspace');
    parentWorkspace=get_param(m,'ModelWorkspace');
    for k=1:numel(sources)
        source=sources{k};
        variable=get_param(source,'VariableName');
        stimulus=getVariable(parentWorkspace,variable);
        if isstruct(stimulus)&&isempty(stimulus.time)
            period=slResolve(get_param(source,'SampleTime'),source);
            assert(isfinite(period)&&period>0,'Cannot determine the original input time grid.');
            stimulus.time=(0:size(stimulus.signals.values,1)-1)'*period;
            assignin(parentWorkspace,variable,stimulus);
        end
        set_param(sources{k},'SampleTime','0','Interpolate','on');
    end
    fixture.input_profile='continuous_interpolated_from_workspace';
end
set_param(m,'SignalLogging','on','SignalLoggingName','protectedComparison');
stop=slResolve(get_param(m,'StopTime'),m);
assert(isfinite(stop)&&stop>0);
duration=min(double(stop),0.4);
set_param(m,'StopTime',num2str(duration,16));
setLogNames(b,item.outputs);
reference=sim(m);
reference=reference.get('protectedComparison');
assert(reference.numElements>=item.outputs);

% Disengage only this in-memory link for the native conversion advisor.
set_param(b,'LinkStatus','inactive');
[ok,modelBlock]=Simulink.SubSystem.convertToModelReference(b,name, ...
    AutoFix=true,ReplaceSubsystem=true);
assert(ok&&isscalar(modelBlock),'Conversion failed for %s.',item.block);
assert(strcmp(get_param(modelBlock,'BlockType'),'ModelReference'), ...
    'Conversion changed the outer model reference interface.');
argNames=get_param(name,'ParameterArgumentNames');
ws=get_param(name,'ModelWorkspace');
vars=ws.whos;
defaults=struct;
for k=1:numel(vars)
    value=getVariable(ws,vars(k).name);
    if isnumeric(value)||islogical(value)||isstruct(value)
        defaults.(vars(k).name)=value;
    end
end
set_param(name,'ParameterArgumentNames','','PreLoadFcn','','PostLoadFcn','','InitFcn','', ...
    'StartFcn','','StopFcn','','CloseFcn','');
configuration=freezeSolverSettings(name);
inputs=ports(name,'Inport');
outputs=ports(name,'Outport');
assert(numel(inputs)==item.inputs&&numel(outputs)==item.outputs, ...
    'Export port count changed during conversion.');
save_system(name,fullfile(caseDir,[name '.slx']));
file=fullfile(out,[name '.slxp']);
if isfile(file)
    % A failed attempt may have produced a package with different settings.
    movefile(file,fullfile(caseDir,[name '_previous.slxp']),'f');
end
Simulink.ModelReference.protect(name,Mode="Simulation",Path=out,Webview=false);
assert(isfile(file),'Protected package was not produced.');
close_system(name,0);
assert(movefile(fullfile(caseDir,[name '.slx']),fullfile(caseDir,[name '_private.slx']),'f'));
addpath(out);
pathCleanup=onCleanup(@()rmpath(out));
set_param(modelBlock,'ModelName',[name '.slxp'],'SimulationMode','Accelerator');
assert(endsWith(string(get_param(modelBlock,'ModelFile')),name+".slxp"), ...
    'Model block did not select the protected package.');
assert(isempty(which([name '.slx'])),'Editable wrapper is on the path.');
setLogNames(modelBlock,item.outputs);
actual=sim(m);actual=actual.get('protectedComparison');
errors=zeros(1,item.outputs);
samples=zeros(1,item.outputs);
for j=1:item.outputs
    signal=logName(j);
    original=reference.getElement(signal).Values;
    protected=actual.getElement(signal).Values;
    assert(isequal(original.Time,protected.Time),'Sample schedule changed on output %d.',j);
    assert(strcmp(class(original.Data),class(protected.Data)), 'Type changed on output %d.',j);
    assert(isequal(size(original.Data),size(protected.Data)),'Size changed on output %d.',j);
    values=double(original.Data(:));result=double(protected.Data(:));
    assert(isequal(isfinite(values),isfinite(result)),'Non-finite pattern changed on output %d.',j);
    assert(isequaln(values(~isfinite(values)),result(~isfinite(result))));
    values=values(isfinite(values));result=result(isfinite(result));
    errors(j)=max([0;abs(values-result)]);
    samples(j)=numel(original.Time);
    assert(all(abs(values-result)<=1e-11+1e-9*abs(values)), ...
        'Protected output %d differs. Max absolute error: %g.',j,errors(j));
end
report=struct('status','passed','name',name,'source',item.source,'block',item.block, ...
    'mode','Simulation','matlab_release',version('-release'),'platform',computer('arch'), ...
    'fixture',fixture,'duration_s',duration,'fixed_model_arguments',argNames, ...
    'workspace_defaults',defaults,'solver_configuration',configuration,'inputs',inputs,'outputs',outputs, ...
    'samples',samples,'max_error_by_output',errors,'max_error',max([0 errors]), ...
    'editable_wrapper_on_path',false);
end

function settings=freezeSolverSettings(model)
% A receiver harness inherits the configuration without the source model
% workspace. Resolve expressions such as pidCfg.Ts before protecting it.
fields={'StartTime','StopTime','FixedStep','InitialStep','MinStep','MaxStep','RelTol','AbsTol'};
settings=struct('Solver',get_param(model,'Solver'),'SolverType',get_param(model,'SolverType'));
set_param(model,'UpdateModelReferenceTargets','IfOutOfDate');
settings.UpdateModelReferenceTargets=get_param(model,'UpdateModelReferenceTargets');
for k=1:numel(fields)
    field=fields{k};
    expression=get_param(model,field);
    if ischar(expression)&&~strcmpi(strtrim(expression),'auto')
        value=slResolve(expression,model);
        assert(isnumeric(value)&&isreal(value)&&isscalar(value),'Expected a scalar solver setting: %s',field);
        expression=num2str(value,17);
        set_param(model,field,expression);
    end
    settings.(field)=expression;
end
end

function info=ports(model,type)
blocks=find_system(model,'SearchDepth',1,'BlockType',type);
info=struct('port',{},'name',{},'data_type',{},'dimensions',{},'sample_time',{});
for j=1:numel(blocks)
    b=blocks{j};
    info(j)=struct('port',str2double(get_param(b,'Port')),'name',get_param(b,'Name'), ...
        'data_type',get_param(b,'OutDataTypeStr'),'dimensions',get_param(b,'PortDimensions'), ...
        'sample_time',get_param(b,'SampleTime'));
end
if ~isempty(info),[~,order]=sort([info.port]);info=info(order);end
end

function setLogNames(block,count)
p=get_param(block,'PortHandles');
assert(numel(p.Outport)==count);
for j=1:count
    set_param(p.Outport(j),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',logName(j));
end
end

function s=logName(j)
s=sprintf('PMContractPort%d',j);
end

function name=exportName(item,entries)
if isfield(item,'protected_name')
    name=item.protected_name;
elseif nnz(strcmp({entries.library},item.library))==1
    name=[item.library 'Protected'];
else
    block=extractAfter(item.block,'/');
    name=[item.library '_' regexprep(block,'[^A-Za-z0-9_]','') 'Protected'];
end
assert(isvarname(name),name);
end

function list=loaded()
list=find_system('Type','block_diagram');
end

function closeNew(before)
list=setdiff(loaded(),before,'stable');
for j=1:numel(list)
    if bdIsLoaded(list{j}),close_system(list{j},0);end
end
end

function restoreSession(pathBefore,cfg,cwd)
Simulink.fileGenControl('set','CacheFolder',cfg.CacheFolder,'CodeGenFolder',cfg.CodeGenFolder, ...
    'CodeGenFolderStructure',cfg.CodeGenFolderStructure);
path(pathBefore);cd(cwd);
end

function writeJson(path,value)
f=fopen(path,'w','n','UTF-8');assert(f>=0,path);
cleanup=onCleanup(@()fclose(f));
fprintf(f,'%s\n',jsonencode(value,PrettyPrint=true));
end
