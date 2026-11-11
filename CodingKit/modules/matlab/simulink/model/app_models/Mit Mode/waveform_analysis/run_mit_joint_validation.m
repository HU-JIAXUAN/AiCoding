function report = run_mit_joint_validation()
%RUN_MIT_JOINT_VALIDATION Run closed-loop MIL checks on the saved application.
module = fileparts(fileparts(mfilename('fullpath')));
model = 'MitJointControl';
wasLoaded = bdIsLoaded(model);
load_system(fullfile(module,'src',[model '.slx']));
closeModel = onCleanup(@() closeIfOpened(model,wasLoaded));
p = mit_joint_parameters();

originalConfig = Simulink.fileGenControl('getConfig');
cache = tempname;
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache,'createDir',true);
restoreConfig = onCleanup(@() cleanCache(originalConfig,cache));
tol = 1e-9;

% Exercise all five inputs against the closed-loop measured feedback.
combined = p.mitCfg;
combined.FeedforwardTorque = 0.25;
combined.VelocityReference = 0.4;
x = simulate(model,p,combined,0.45);
tau = combined.Kp*(x.QRef-x.Q)+combined.Kd*(x.DqRef-x.Dq)+x.Filtered;
assert(max(abs(x.TorqueRequest-tau)) < tol,'Five-parameter law mismatch.');
expected = filter(1-combined.FeedforwardMemory,[1,-combined.FeedforwardMemory],x.Feedforward);
assert(max(abs(x.Filtered-expected)) < tol,'Feedforward update differs from Katz recursion.');
assert(max(abs(x.IqSelected-x.IqMIT)) < tol && all(x.IdSelected == 0), ...
    'MIT mode is not supplying both references to the shared FOC.');

torque = p.mitCfg;
torque.Kp = 0;
torque.Kd = 0;
torque.LoadTorque = 0;
torque.FeedforwardTorque = 0.3;
x = simulate(model,p,torque,0.2);
iTarget = torque.FeedforwardTorque/(torque.Kt*torque.GearRatio);
steady = x.Time > 0.12;
report.pure_torque_current_A = mean(x.Iq(steady));
assert(max(abs(x.IqMIT(steady)-iTarget)) < 1e-5);
assert(abs(report.pure_torque_current_A-iTarget) < 0.08,'Shared current loop did not follow torque feedforward.');

soft = p.mitCfg;
hard = soft;
hard.Kp = 2*soft.Kp;
x = simulate(model,p,soft,2.0);
y = simulate(model,p,hard,2.0);
report.soft_deflection_rad = mean(x.QRef(x.Time>1.8)-x.Q(x.Time>1.8));
report.stiff_deflection_rad = mean(y.QRef(y.Time>1.8)-y.Q(y.Time>1.8));
assert(abs(report.soft_deflection_rad-soft.LoadTorque/soft.Kp) < 0.01);
assert(abs(report.stiff_deflection_rad-hard.LoadTorque/hard.Kp) < 0.01);

low = p.mitCfg;
low.Kd = 0.025;
low.LoadTorque = 0;
high = low;
high.Kd = p.mitCfg.Kd;
x = simulate(model,p,low,1.3);
y = simulate(model,p,high,1.3);
report.low_damping_tail_rad = max(abs(x.Q(x.Time>0.75)-x.QRef(x.Time>0.75)));
report.high_damping_tail_rad = max(abs(y.Q(y.Time>0.75)-y.QRef(y.Time>0.75)));
assert(report.high_damping_tail_rad < 0.4*report.low_damping_tail_rad, ...
    'Greater joint damping did not reduce the late tracking oscillation.');

limited = torque;
limited.CurrentLimit = iTarget/2;
for direction = [-1,1]
    limited.FeedforwardTorque = direction*torque.FeedforwardTorque;
    x = simulate(model,p,limited,0.12);
    assert(all(abs(x.IqSelected) <= limited.CurrentLimit+tol));
    assert(abs(x.IqSelected(end)-direction*limited.CurrentLimit) < tol, ...
        'Current limiter gave %.12g A, expected %.12g A.', ...
        x.IqSelected(end),direction*limited.CurrentLimit);
end
blocked = p.mitCfg;
blocked.BusVoltageMax = p.inverterCfg.Vdc-1;
x = simulate(model,p,blocked,0.12);
assert(any(x.TorqueRequest > 0) && all(x.IqSelected == 0),'Bus guard did not clear iq reference.');
off = p;
off.experimentCfg.Reset = 1;
x = simulate(model,off,combined,0.12);
assert(all(x.IqSelected == 0) && all(x.Filtered == 0),'Reset left a command or filter state.');

% Check the unchanged legacy position and speed branches against the source model.
legacy = p.mitCfg;
legacy.UseMitMode = false;
fixture = p;
fixture.experimentCfg.PositionReference = legacy.GearRatio*legacy.PositionReference;
fixture.experimentCfg.LoadTorque = legacy.LoadTorque/legacy.GearRatio;
source = 'MotorExperiment';
sourceWasLoaded = bdIsLoaded(source);
load_system(source);
closeSource = onCleanup(@() closeIfOpened(source,sourceWasLoaded));
report.legacy_max_trace_error = zeros(1,2);
for mode = 1:2
    if mode == 1, legacy.VelocityReference = 0.4; end
    fixture.experimentCfg.SpeedReference = legacy.GearRatio*legacy.VelocityReference;
    fixture.experimentCfg.Mode = mode;
    [x,out] = simulate(model,fixture,legacy,0.55);
    reference = sim(withParameters(source,fixture,0.55));
    a = out.trace.signals.values;
    b = reference.trace.signals.values;
    assert(isequal(out.trace.time,reference.trace.time));
    report.legacy_max_trace_error(mode) = max(abs(a-b),[],'all');
    assert(report.legacy_max_trace_error(mode) < tol && max(abs(x.IqSelected)) > 0.1);
end
disp(report);
end

function [trace,out] = simulate(model,parameters,mit,stop)
parameters.mitCfg = mit;
out = sim(withParameters(model,parameters,stop));
data = out.mitTrace.signals.values;
assert(size(data,2) == 13 && all(isfinite(data),'all'));
assert(abs(out.mitTrace.time(end)-stop) < 1e-8);
names = {'QRef','DqRef','Q','Dq','Feedforward','Filtered','TorqueRequest', ...
    'IqMIT','IqSelected','Iq','TorqueEstimate','Load','IdSelected'};
trace = cell2struct(num2cell(data,1),names,2);
trace.Time = out.mitTrace.time;
end

function input = withParameters(model,parameters,stop)
input = Simulink.SimulationInput(model);
names = fieldnames(parameters);
for k = 1:numel(names)
    input = input.setVariable(names{k},parameters.(names{k}),'Workspace',model);
end
input = input.setModelParameter('StopTime',sprintf('%.15g',stop));
end

function closeIfOpened(model,wasLoaded)
if ~wasLoaded && bdIsLoaded(model), close_system(model,0); end
end

function cleanCache(config,cache)
Simulink.fileGenControl('setConfig','config',config);
if isfolder(cache), rmdir(cache,'s'); end
end
