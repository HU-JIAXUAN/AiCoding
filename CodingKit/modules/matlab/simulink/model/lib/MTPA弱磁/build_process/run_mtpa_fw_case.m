function r = run_mtpa_fw_case(model,overrides,inputs,duration)
%RUN_MTPA_FW_CASE Simulate a saved allocator or motor model, nonpersistently.
%   Inputs are six uniform columns: T, we, Vdc, U_prev, enable, reset.
if nargin<2,overrides=struct();end
if nargin<3,inputs=[];end
assert(ismember(model,{'CurrentReferenceTest','MTPAFWMotor'}));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'));
modelRoot=fileparts(fileparts(module));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
initialize_motor_paths();
if strcmp(model,'MTPAFWMotor')
    source=fullfile(modelRoot,'app_models','Sensor','mtpa_fw','src');
else
    source=fullfile(module,'src');
end
if ~bdIsLoaded(model),open_system(fullfile(source,[char(model),'.slx']));end
p=reference_case_parameters(model);
if nargin<4
    if strcmp(model,'MTPAFWMotor'),duration=p.experimentCfg.Duration;else,duration=p.refTestCfg.Duration;end
end
assert(isfinite(duration)&&duration>0);
names=fieldnames(overrides);
for k=1:numel(names)
    key=names{k};assert(isfield(p,key),'Unknown configuration group: %s',key);
    fields=fieldnames(overrides.(key));
    for j=1:numel(fields)
        field=fields{j};assert(isfield(p.(key),field),'Unknown parameter: %s.%s',key,field);
        p.(key).(field)=overrides.(key).(field);
    end
end
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.refCfg.MinDuty=p.inverterCfg.MinDuty;
p.refCfg=refresh_mtpa_tables(p.refCfg,p.pmsmCfg);
assert(p.inverterCfg.Vdc>0);
assert(abs(p.refCfg.FwTs/p.currentCfg.Ts-round(p.refCfg.FwTs/p.currentCfg.Ts))<1e-9);
assert(abs(p.refCfg.SpeedTs-p.motionCfg.Ts)<1e-12);
assert(abs(p.timingCfg.Ts-p.currentCfg.Ts)<1e-12);
assert(abs(p.currentCfg.Ts/p.experimentCfg.Step-round(p.currentCfg.Ts/p.experimentCfg.Step))<1e-9);
if strcmp(model,'CurrentReferenceTest')
    if isempty(inputs)
        sample=(0:round(duration/p.currentCfg.Ts))';
        inputs=[p.refTestCfg.TorqueReference*ones(size(sample)), ...
            p.refTestCfg.ElectricalSpeed*ones(size(sample)),p.refTestCfg.Vdc*ones(size(sample)), ...
            p.refTestCfg.VoltageDemand*double(sample>=round(p.refTestCfg.VoltageDemandTime/p.currentCfg.Ts)), ...
            p.refTestCfg.Enable*ones(size(sample)),p.refTestCfg.Reset*ones(size(sample))];
    end
    assert(size(inputs,2)==6&&all(isfinite(inputs),'all'));
    assert(size(inputs,1)>=ceil(duration/p.currentCfg.Ts-1e-9)+1, ...
        'Input rows must cover the complete simulation duration.');
    assert(all(inputs(:,3:4)>=0,'all'));
    assert(all(ismember(inputs(:,5:6),[0,1]),'all'));
    stim.time=[];stim.signals.values=inputs;stim.signals.dimensions=6;
else
    assert(isempty(inputs),'Motor model uses its configured Step sources.');
    stim.time=[];stim.signals.values=zeros(2,6);stim.signals.dimensions=6;
end
in=Simulink.SimulationInput(model);names=fieldnames(p);
for k=1:numel(names),in=in.setVariable(names{k},p.(names{k}),'Workspace',model);end
in=in.setVariable('testStim',stim,'Workspace',model);
in=in.setModelParameter('StopTime',sprintf('%.15g',duration));
timer=tic;out=sim(in);
r.model=model;r.parameters=p;r.inputs=inputs;r.trace=out.trace;r.wall_time_s=toc(timer);
assert(all(isfinite(r.trace.signals.values),'all'));
end
