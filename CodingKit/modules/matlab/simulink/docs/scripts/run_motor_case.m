function result = run_motor_case(model, overrides, inputs, duration)
%RUN_MOTOR_CASE Simulate one saved model with nonpersistent parameter overrides.
%   R = RUN_MOTOR_CASE(MODEL,OVERRIDES,INPUTS,DURATION) overrides nested
%   module structs. INPUTS is an N-by-port-count uniformly sampled matrix;
%   use [] for the model's default input. R includes SI trace and all configs.
if nargin<2, overrides=struct(); end
if nargin<3, inputs=[]; end
initialize_motor_paths();
if ~bdIsLoaded(model), open_system(model); end
[p,defaultStimulus]=motor_case_parameters(model);
if nargin<4,duration=p.fixtureCfg.Duration;end
assert(isfinite(duration)&&duration>0,'Stop time must be finite and positive.');
groups=fieldnames(overrides);
for k=1:numel(groups)
    group=groups{k}; assert(isfield(p,group),'Unknown parameter group: %s',group);
    fields=fieldnames(overrides.(group));
    for j=1:numel(fields)
        field=fields{j};
        assert(isfield(p.(group),field),'Unknown parameter: %s.%s',group,field);
        p.(group).(field)=overrides.(group).(field);
    end
end
assert(p.pmsmCfg.Rs>0&&p.pmsmCfg.Ld>0&&p.pmsmCfg.Lq>0&&p.pmsmCfg.J>0);
assert(p.pmsmCfg.B>=0&&p.pmsmCfg.PolePairs>=1);
assert(p.inverterCfg.Vdc>0&&p.inverterCfg.MinDuty>=0&&p.inverterCfg.MinDuty<0.5);
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
assert(p.deadtimeCfg.CurrentBlend>0&&p.deadtimeCfg.DeadTime>=0);
assert(p.currentCfg.Ts>0&&abs(p.timingCfg.Ts-p.currentCfg.Ts)<1e-12,'Timing Ts must equal current Ts.');
assert(abs(p.motionCfg.Ts/p.currentCfg.Ts-round(p.motionCfg.Ts/p.currentCfg.Ts))<1e-9,'Outer-loop period must be an integer multiple.');
assert(abs(p.currentCfg.Ts/p.experimentCfg.Step-round(p.currentCfg.Ts/p.experimentCfg.Step))<1e-9,'Plant step must divide current Ts.');
assert(all([p.timingCfg.FeedbackTicks,p.timingCfg.ActuationTicks]>=0));
assert(all(mod([p.timingCfg.FeedbackTicks,p.timingCfg.ActuationTicks],1)==0));
if ~isempty(inputs)
    assert(isnumeric(inputs)&&all(isfinite(inputs),'all'));
    stim.time=[];stim.signals.values=inputs;stim.signals.dimensions=size(inputs,2);
else
    stim=defaultStimulus;
end
in=Simulink.SimulationInput(model);
fields=fieldnames(p);
for k=1:numel(fields)
    in=in.setVariable(fields{k},p.(fields{k}),'Workspace',model);
end
in=in.setVariable('testStim',stim,'Workspace',model);
in=in.setModelParameter('StopTime',sprintf('%.15g',duration));
timer=tic;out=sim(in);
result.model=model;result.parameters=p;result.inputs=stim.signals.values;
result.trace=out.trace;
result.wall_time_s=toc(timer);
assert(all(isfinite(result.trace.signals.values),'all'),'Nonfinite model output.');
assert(abs(result.trace.time(end)-duration)<p.experimentCfg.LogTs*1.1);
end
