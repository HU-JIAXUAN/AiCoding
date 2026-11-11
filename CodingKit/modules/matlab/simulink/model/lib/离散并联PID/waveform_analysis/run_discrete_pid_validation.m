function summary = run_discrete_pid_validation()
%RUN_DISCRETE_PID_VALIDATION Simulate the library block and save MIL evidence.
%   SUMMARY = RUN_DISCRETE_PID_VALIDATION runs twelve deterministic scenarios.
%   Results and figures are written beside this file. No base-workspace
%   parameter assignment or model reconstruction is performed.

analysisDir = fileparts(mfilename('fullpath'));
moduleDir = fileparts(analysisDir);
addpath(fullfile(moduleDir,'src'), fullfile(moduleDir,'parameter'), ...
    fullfile(moduleDir,'build_process'));
modelName = 'DiscretePIDTest';
load_system(fullfile(moduleDir,'src',[modelName '.slx']));

% Keep disposable Simulink caches outside the source module.
oldFileGen = Simulink.fileGenControl('getConfig');
cacheDir = tempname;
mkdir(cacheDir);
cleanup = onCleanup(@() restore_file_generation(oldFileGen,cacheDir));
Simulink.fileGenControl('set','CacheFolder',fullfile(cacheDir,'cache'), ...
    'CodeGenFolder',fullfile(cacheDir,'codegen'),'createDir',true);

base = discrete_pid_parameters();
tol = 1.0e-10;
cases = struct();

cfg = base;
cfg.ClosedLoop = 0;
cfg.UMin = -100;
cfg.UMax = 100;
cfg.X0 = 0.15;
t = (0:cfg.Ts:0.2)';
cases.linear_positive = simulate_case(modelName,cfg,t,0.2*ones(size(t)));
p = cases.linear_positive.trace;
expected = cfg.Kp*0.2 + cfg.X0 + cfg.Ki*0.2*p.time;
analyticError = max(abs(p.values(:,3)-expected));
assert(analyticError < tol,'PID:Integral','Forward Euler analytic check failed.');

cfg.X0 = -0.15;
cases.linear_negative = simulate_case(modelName,cfg,t,-0.2*ones(size(t)));
assert(max(abs(cases.linear_negative.trace.values(:,3)+p.values(:,3))) < tol, ...
    'PID:Symmetry','Positive/negative symmetry check failed.');

cfg = base;
cfg.ClosedLoop = 0;
t = (0:cfg.Ts:2.0)';
cases.limit_positive_aw = simulate_case(modelName,cfg,t,2*ones(size(t)));
cases.limit_negative_aw = simulate_case(modelName,cfg,t,-2*ones(size(t)));
pa = cases.limit_positive_aw.trace.values;
na = cases.limit_negative_aw.trace.values;
assert(all(abs(pa(:,3)-cfg.UMax) < tol) && all(abs(na(:,3)-cfg.UMin) < tol), ...
    'PID:Limits','Output limit check failed.');
assert(all(pa(:,7)==1) && all(na(:,7)==1),'PID:LimitFlag','Limit flag check failed.');
assert(max(abs(pa(:,5)+na(:,5))) < tol,'PID:StateSymmetry','Integral state symmetry failed.');
cfg.Kaw = 0;
cases.limit_positive_no_aw = simulate_case(modelName,cfg,t,2*ones(size(t)));
pn = cases.limit_positive_no_aw.trace.values;
assert(abs(pn(end,5)-cfg.Ki*2*t(end)) < tol,'PID:WindupBaseline','No-AW integral baseline failed.');
awEquilibrium = base.UMax-base.Kp*2+base.Ki*2/base.Kaw;
assert(abs(pa(end,5)-awEquilibrium) < 1.0e-8,'PID:BackCalculation','AW equilibrium check failed.');

cfg = base;
cfg.ClosedLoop = 0;
cfg.X0 = 0.1;
t = (0:cfg.Ts:0.4)';
enable = true(size(t));
enable(t>=0.1 & t<0.2) = false;
reset = false(size(t));
reset(t>=0.15 & t<0.17) = true; % reset and disabled together
reset(t>=0.3 & t<0.32) = true;  % reset while enabled
cases.enable_reset = simulate_case(modelName,cfg,t,0.25*ones(size(t)),enable,reset);
r = cases.enable_reset.trace.values;
inactive = ~enable | reset;
assert(all(r(inactive,3)==0) && all(r(inactive,4)==0) && all(r(inactive,7)==0), ...
    'PID:InactiveOutput','Disabled/reset outputs must be zero.');
assert(all(abs(r(inactive,5)-cfg.X0) < tol),'PID:ResetState','Reset state check failed.');
restart = diff([false; ~inactive])==1;
assert(all(abs(r(restart,3)-(cfg.Kp*0.25+cfg.X0)) < tol), ...
    'PID:Restart','First enabled sample must use X0.');

cfg = base;
t = (0:cfg.Ts:2.0)';
command = 0.2*double(t>=0.1);
cases.closed_loop_linear = simulate_case(modelName,cfg,t,command);
cl = cases.closed_loop_linear.trace.values;
assert(~any(cl(:,7)),'PID:LinearLoop','Nominal loop unexpectedly saturated.');
assert(abs(cl(end,6)-0.2) < 1.0e-4,'PID:Tracking','Nominal tracking error too large.');

t = (0:cfg.Ts:3.0)';
command = zeros(size(t));
command(t>=0.1 & t<1.0) = 2;
command(t>=1.0) = 0.2;
cases.recovery_aw = simulate_case(modelName,cfg,t,command);
cfg.Kaw = 0;
cases.recovery_no_aw = simulate_case(modelName,cfg,t,command);
awRecovery = recovery_time(cases.recovery_aw,1.0,0.2,0.02);
noAwRecovery = recovery_time(cases.recovery_no_aw,1.0,0.2,0.02);
assert(isfinite(awRecovery) && isfinite(noAwRecovery) && awRecovery < noAwRecovery, ...
    'PID:Recovery','AW did not shorten recovery in the specified scenario.');

% Pure filtered derivative: a known step produces a geometric decay.
cfg = base;
cfg.ClosedLoop = 0;
cfg.Kp = 0;
cfg.Ki = 0;
cfg.Kd = 0.02;
cfg.UMin = -100;
cfg.UMax = 100;
t = (0:cfg.Ts:0.3)';
command = zeros(size(t));
stepIndex = 51;
command(stepIndex:end) = 0.2;
cases.derivative_step = simulate_case(modelName,cfg,t,command);
expectedD = zeros(size(t));
expectedD(stepIndex:end) = (0.2*cfg.Kd/(cfg.Tf+cfg.Ts)) ...
    *(cfg.Tf/(cfg.Tf+cfg.Ts)).^(0:numel(t)-stepIndex)';
derivativeError = max(abs(cases.derivative_step.trace.values(:,9)-expectedD));
assert(derivativeError < tol,'PID:Derivative','Filtered derivative step check failed.');

cfg = base;
cfg.ClosedLoop = 0;
cfg.Kd = 0.02;
cases.pid_ramp = simulate_case(modelName,cfg,t,0.5*t);
cfg.X0 = 0.1;
t = (0:cfg.Ts:0.4)';
enable = true(size(t)); enable(101:200) = false;
reset = false(size(t)); reset(151:170) = true; reset(301:320) = true;
command = 0.25*ones(size(t)); command(151:end) = 0.4;
cases.pid_enable_reset = simulate_case(modelName,cfg,t,command,enable,reset);
rd = cases.pid_enable_reset.trace.values;
inactive = ~enable | reset;
assert(all(rd(inactive,9)==0) && all(rd(inactive,3)==0), ...
    'PID:DerivativeReset','Inactive derivative/output must be zero.');
assert(all(abs(rd([201 321],9))<tol),'PID:DerivativeRestart','Derivative reset retained state.');
assert(all(abs(rd([201 321],3)-(cfg.Kp*0.4+cfg.X0))<tol), ...
    'PID:PIDRestart','PID restart state check failed.');

names = fieldnames(cases);
officialError = 0;
officialCases = 0;
officialPiCases = 0;
zeroKdDerivative = 0;
for idx = 1:numel(names)
    c = cases.(names{idx});
    v = c.trace.values;
    assert(all(isfinite(v),'all'),'PID:Finite','Nonfinite trace in %s.',names{idx});
    active = c.stim.enable.Data & ~c.stim.reset.Data;
    if c.cfg.Kd==0
        zeroKdDerivative = max(zeroKdDerivative,max(abs(v(:,9))));
    end
    assert(all(v(active,3)<=c.cfg.UMax+tol & v(active,3)>=c.cfg.UMin-tol), ...
        'PID:Bounds','Active output out of bounds in %s.',names{idx});
    assert(isequal(v(active,7)~=0,v(active,3)~=v(active,4)), ...
        'PID:FlagConsistency','Saturation diagnostic mismatch in %s.',names{idx});
    if all(active)
        officialCases = officialCases + 1;
        officialPiCases = officialPiCases + double(c.cfg.Kd==0);
        officialError = max(officialError,max(abs(v(:,3)-v(:,8))));
    end
end
assert(officialError < tol,'PID:OfficialReference','Official PI/PID comparison failed.');
assert(zeroKdDerivative==0,'PID:ZeroKd','Kd=0 must give an exactly zero D contribution.');

summary = struct('status','passed','scenario_count',numel(names), ...
    'scenario_names',{names},'official_comparison_count',officialCases, ...
    'official_pi_case_count',officialPiCases, ...
    'official_pid_case_count',officialCases-officialPiCases, ...
    'analytic_max_error',analyticError,'official_max_error',officialError, ...
    'derivative_analytic_max_error',derivativeError,'zero_kd_derivative_max',zeroKdDerivative, ...
    'aw_integral_end',pa(end,5),'no_aw_integral_end',pn(end,5), ...
    'recovery_band',0.02,'recovery_step_time_s',1.0, ...
    'aw_recovery_s',awRecovery,'no_aw_recovery_s',noAwRecovery, ...
    'sample_time_s',base.Ts,'solver','FixedStepDiscrete', ...
    'matlab_release',version('-release'),'matlab_version',version, ...
    'executed_at_utc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss XXX')));
save(fullfile(analysisDir,'results.mat'),'cases','summary');
fid = fopen(fullfile(analysisDir,'metrics.json'),'w','n','UTF-8');
assert(fid>=0,'PID:MetricsFile','Cannot open metrics.json.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(summary,PrettyPrint=true));
clear fileCleanup
write_figures(cases,analysisDir);
disp(summary);
end

function c = simulate_case(modelName,cfg,t,command,enable,reset)
if nargin<5
    enable = true(size(t));
    reset = false(size(t));
end
stim.command = timeseries(command,t);
stim.enable = timeseries(enable,t);
stim.reset = timeseries(reset,t);
% Use sample-based sources; saved timeseries remain convenient for analysis.
sampled = @(values) struct('time',[], ...
    'signals',struct('values',values,'dimensions',1));
source.command = sampled(command);
source.enable = sampled(enable);
source.reset = sampled(reset);
in = Simulink.SimulationInput(modelName);
in = in.setVariable('pidCfg',cfg,'Workspace',modelName);
in = in.setVariable('pidStim',source,'Workspace',modelName);
in = in.setModelParameter('StopTime',sprintf('%.15g',t(end)));
if cfg.Kd==0
    % Explicitly compare the generic PID against the official PI mode.
    referenceBlock = Simulink.ID.getFullName([modelName ':11']);
    in = in.setBlockParameter(referenceBlock,'Controller','PI');
end
out = sim(in);
trace.time = out.pidTrace.time;
trace.values = out.pidTrace.signals.values;
trace.channels = {'command','error','u','u_unsat','x_i','plant_y','saturated','official_reference','x_d'};
assert(numel(trace.time)==numel(t) && max(abs(trace.time-t))<1.0e-10, ...
    'PID:SampleGrid','Unexpected trace sample grid.');
c = struct('cfg',cfg,'stim',stim,'trace',trace);
end

function elapsed = recovery_time(c,stepTime,target,band)
t = c.trace.time;
bad = find(t>=stepTime & abs(c.trace.values(:,6)-target)>band,1,'last');
if isempty(bad)
    elapsed = 0;
elseif bad==numel(t)
    elapsed = inf;
else
    elapsed = t(bad+1)-stepTime;
end
end

function write_figures(cases,analysisDir)
f = figure('Visible','off','Color','white','Position',[50 50 1200 760]);
figCleanup = onCleanup(@() close(f));
tiledlayout(2,1);
c = cases.linear_positive;
nexttile; plot(c.trace.time,c.trace.values(:,[3 8]),'LineWidth',1.5); grid on;
ylabel('u'); title('Forward Euler PI: analytic and official reference checks');
legend('Custom PI','Official PI','Location','northwest');
nexttile; plot(c.trace.time,c.trace.values(:,5),'LineWidth',1.5); grid on;
ylabel('Integral state x[k]'); xlabel('Time (s)');
save_figure(f,analysisDir,'linear_integration');
clf(f); tiledlayout(3,1);
c = cases.enable_reset; t = c.trace.time;
nexttile; stairs(t,[c.stim.enable.Data,c.stim.reset.Data],'LineWidth',1.4); grid on;
ylim([-0.1 1.1]); legend('enable','reset'); title('Synchronous disable / reset');
nexttile; plot(t,c.trace.values(:,[3 4]),'LineWidth',1.4); grid on;
ylabel('Command'); legend('u','u unsaturated');
nexttile; plot(t,c.trace.values(:,5),'LineWidth',1.4); grid on;
ylabel('Integral state'); xlabel('Time (s)');
save_figure(f,analysisDir,'enable_reset');
clf(f); tiledlayout(2,1);
c = cases.limit_positive_aw; d = cases.limit_positive_no_aw;
nexttile; plot(c.trace.time,c.trace.values(:,3),'LineWidth',1.4); grid on;
ylabel('u'); title('Constant error = 2: output stays limited at 1');
nexttile; plot(c.trace.time,[c.trace.values(:,5),d.trace.values(:,5)],'LineWidth',1.4); grid on;
ylabel('Integral state'); xlabel('Time (s)'); legend('Back-calculation','Kaw = 0','Location','northwest');
save_figure(f,analysisDir,'constant_error_windup');
clf(f); tiledlayout(3,1);
c = cases.recovery_aw; d = cases.recovery_no_aw; t = c.trace.time;
nexttile; plot(t,[c.stim.command.Data,c.trace.values(:,6),d.trace.values(:,6)],'LineWidth',1.4); grid on;
ylabel('Reference / y'); title('Same first-order plant, same PI gains: saturation recovery');
legend('Reference','Back-calculation','Kaw = 0','Location','northeast');
nexttile; plot(t,[c.trace.values(:,3),d.trace.values(:,3)],'LineWidth',1.4); grid on;
ylabel('u'); legend('Back-calculation','Kaw = 0');
nexttile; plot(t,[c.trace.values(:,5),d.trace.values(:,5)],'LineWidth',1.4); grid on;
ylabel('Integral state'); xlabel('Time (s)');
save_figure(f,analysisDir,'saturation_recovery');
clf(f); tiledlayout(2,1);
c = cases.derivative_step;
nexttile; stairs(c.trace.time,c.stim.command.Data,'LineWidth',1.4); grid on;
ylabel('Error'); title('Filtered derivative: Kd = 0.02 s, Tf = 0.01 s');
nexttile; plot(c.trace.time,c.trace.values(:,[3 8 9]),'LineWidth',1.4); grid on;
ylabel('D contribution'); xlabel('Time (s)');
legend('Custom PID (pure D)','Official PID','x d');
save_figure(f,analysisDir,'derivative_step');
end

function save_figure(f,analysisDir,name)
exportgraphics(f,fullfile(analysisDir,[name '.png']),'Resolution',150);
exportgraphics(f,fullfile(analysisDir,[name '.svg']),'ContentType','vector');
end

function restore_file_generation(oldFileGen,cacheDir)
Simulink.fileGenControl('setConfig','config',oldFileGen);
% cacheDir is the exact fresh directory created by this invocation.
if isfolder(cacheDir)
    rmdir(cacheDir,'s');
end
end
