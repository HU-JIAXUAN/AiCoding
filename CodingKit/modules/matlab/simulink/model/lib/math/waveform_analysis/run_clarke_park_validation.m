function summary = run_clarke_park_validation()
%RUN_CLARKE_PARK_VALIDATION Verify four saved transform blocks in thirteen cases.
%   Saves all inputs, configurations, traces, metrics and five figure pairs.
%   No model reconstruction or base-workspace parameter assignment is used.
analysisDir = fileparts(mfilename('fullpath'));
moduleDir = fileparts(analysisDir);
addpath(fullfile(moduleDir,'src'),fullfile(moduleDir,'parameter'), ...
    fullfile(moduleDir,'build_process'));
modelName = 'ClarkeParkTest';
load_system(fullfile(moduleDir,'src',[modelName '.slx']));
oldFileGen = Simulink.fileGenControl('getConfig');
cacheDir = tempname;
mkdir(cacheDir);
cleanup = onCleanup(@() restore_file_generation(oldFileGen,cacheDir));
Simulink.fileGenControl('set','CacheFolder',fullfile(cacheDir,'cache'), ...
    'CodeGenFolder',fullfile(cacheDir,'codegen'),'createDir',true);

cfg = clarke_park_parameters();
cfg.UseIndependentInverse = 0;
cfg.ZeroSequenceGain = 1;
t = (0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;
phase = 2*pi*cfg.FrequencyHz*t + cfg.InitialAngleRad;
abc = cfg.Amplitude*cos(phase+[0,-2*pi/3,2*pi/3]);
inputs = [abc,phase,zeros(numel(t),3)];
cases = struct();
cases.balanced_d = simulate_case(modelName,cfg,t,inputs);
assert(max(abs(cases.balanced_d.trace.values(:,7)-cfg.Amplitude))<1e-12, ...
    'Transform:DAxis','Balanced d-axis magnitude failed.');
assert(max(abs(cases.balanced_d.trace.values(:,8)))<1e-12, ...
    'Transform:QAxis','Balanced d-axis case has nonzero q.');

qInputs = inputs;
qInputs(:,1:3) = cfg.Amplitude*cos(phase+pi/2+[0,-2*pi/3,2*pi/3]);
cases.balanced_q = simulate_case(modelName,cfg,t,qInputs);
assert(max(abs(cases.balanced_q.trace.values(:,7)))<1e-12 && ...
    max(abs(cases.balanced_q.trace.values(:,8)-cfg.Amplitude))<1e-12, ...
    'Transform:PositiveQ','Positive q-axis sign failed.');

offsetInputs = inputs;
offsetInputs(:,4) = phase+pi/6;
offsetCfg = cfg;
offsetCfg.AngleOffsetRad = pi/6;
cases.angle_offset = simulate_case(modelName,offsetCfg,t,offsetInputs);
assert(max(abs(cases.angle_offset.trace.values(:,7:8) ...
    -cfg.Amplitude*[cos(pi/6),-sin(pi/6)]),[],'all')<1e-12, ...
    'Transform:AngleOffset','Angle offset sign or magnitude failed.');

reversePhase = -2*pi*cfg.FrequencyHz*t+cfg.InitialAngleRad;
reverseInputs = [cfg.Amplitude*cos(reversePhase+[0,-2*pi/3,2*pi/3]), ...
    reversePhase,zeros(numel(t),3)];
reverseCfg = cfg;
reverseCfg.FrequencyHz = -cfg.FrequencyHz;
cases.reverse_rotation = simulate_case(modelName,reverseCfg,t,reverseInputs);
assert(max(abs(cases.reverse_rotation.trace.values(:,7:8) ...
    -[cfg.Amplitude,0]),[],'all')<1e-12,'Transform:Reverse','Reverse rotation failed.');

zeroInputs = [1.25*ones(numel(t),3),phase,zeros(numel(t),3)];
cases.pure_zero = simulate_case(modelName,cfg,t,zeroInputs);
z = cases.pure_zero.trace.values;
assert(max(abs(z(:,[4 5 7 8])),[],'all')<1e-12 && max(abs(z(:,6)-1.25))<1e-12, ...
    'Transform:ZeroSequence','Pure zero-sequence decomposition failed.');

mixedInputs = inputs;
mixedInputs(:,1:3) = abc+1.2*cos(3*phase);
cases.mixed_zero = simulate_case(modelName,cfg,t,mixedInputs);
dropCfg = cfg;
dropCfg.ZeroSequenceGain = 0;
cases.dropped_zero = simulate_case(modelName,dropCfg,t,mixedInputs);
drop = cases.dropped_zero.trace.values;
zeroLossError = max(abs(drop(:,18:20)+cases.mixed_zero.trace.values(:,6)),[],'all');
assert(zeroLossError<1e-12,'Transform:LostZero','Discarded zero sequence has unexpected effect.');
assert(max(abs(drop(:,18:20)),[],'all')>1,'Transform:LostZeroVisible','Zero-loss case did not demonstrate loss.');

tb = (0:2)'*cfg.Ts;
basisInputs = [eye(3),zeros(3,4)];
cases.clarke_basis = simulate_case(modelName,cfg,tb,basisInputs);
expectedBasis = [2/3,0,1/3;-1/3,1/sqrt(3),1/3;-1/3,-1/sqrt(3),1/3];
assert(max(abs(cases.clarke_basis.trace.values(:,4:6)-expectedBasis),[],'all')<1e-12, ...
    'Transform:ClarkeBasis','Clarke basis-vector scale failed.');

quarterInputs = [repmat([1,-0.5,-0.5],3,1),(pi/2)*ones(3,1),zeros(3,3)];
cases.park_quarter_turn = simulate_case(modelName,cfg,tb,quarterInputs);
assert(max(abs(cases.park_quarter_turn.trace.values(:,7:8)-[0,-1]),[],'all')<1e-12, ...
    'Transform:QuarterTurn','At theta=pi/2 alpha=1 must give d=0, q=-1.');

stream = RandStream('mt19937ar','Seed',cfg.RandomSeed);
tr = (0:255)'*cfg.Ts;
randomInputs = [20*rand(stream,256,3)-10,40*pi*rand(stream,256,1)-20*pi,zeros(256,3)];
cases.random_abc = simulate_case(modelName,cfg,tr,randomInputs);

unbalancedInputs = inputs;
unbalancedInputs(:,1:3) = [7*cos(phase)+0.4, ...
    2*cos(phase-2*pi/3)-0.2,4*cos(phase+2*pi/3)+0.7+sin(5*phase)];
cases.unbalanced_harmonics = simulate_case(modelName,cfg,t,unbalancedInputs);

inverseCfg = cfg;
inverseCfg.UseIndependentInverse = 1;
inverseInputs = [zeros(numel(t),3),phase, ...
    3*cos(17*t)+1,2*sin(13*t)-0.5,0.4*cos(7*t)];
cases.independent_inverse = simulate_case(modelName,inverseCfg,t,inverseInputs);

ta = (0:3)'*cfg.Ts;
anchorInputs = [zeros(4,3),[0;0;pi/2;pi/2], ...
    [1;0;1;0],[0;1;0;1],[0;0;0.3;-0.2]];
cases.inverse_axis_anchors = simulate_case(modelName,inverseCfg,ta,anchorInputs);
expectedAnchorAbc = [1,-0.5,-0.5;0,sqrt(3)/2,-sqrt(3)/2; ...
    0,sqrt(3)/2,-sqrt(3)/2;-1,0.5,0.5]+anchorInputs(:,7);
assert(max(abs(cases.inverse_axis_anchors.trace.values(:,15:17)-expectedAnchorAbc),[],'all')<1e-12, ...
    'Transform:InverseAnchors','Independent inverse axis anchors failed.');

names = fieldnames(cases);
referenceMaxError = 0;
roundTripMaxError = 0;
normMaxError = 0;
roundTripCount = 0;
for idx=1:numel(names)
    c = cases.(names{idx});
    m = verify_case(c);
    cases.(names{idx}).metrics = m;
    referenceMaxError = max(referenceMaxError,m.reference_max_error_A);
    normMaxError = max(normMaxError,m.squared_norm_error_A2);
    if c.cfg.UseIndependentInverse==0 && c.cfg.ZeroSequenceGain==1
        roundTripCount = roundTripCount+1;
        roundTripMaxError = max(roundTripMaxError,m.reconstruction_error_A);
    end
end
summary = struct('status','passed','scenario_count',numel(names), ...
    'scenario_names',{names},'round_trip_case_count',roundTripCount, ...
    'reference_max_error_A',referenceMaxError,'round_trip_max_error_A',roundTripMaxError, ...
    'squared_norm_error_A2',normMaxError,'zero_loss_identity_error_A',zeroLossError, ...
    'zero_loss_peak_A',max(abs(drop(:,18:20)),[],'all'), ...
    'tolerance_A',1e-12,'sample_time_s',cfg.Ts,'solver','FixedStepDiscrete', ...
    'scaling','amplitude_invariant','alignment','d_axis','angle_unit','rad', ...
    'matlab_version',version,'matlab_release',version('-release'), ...
    'executed_at_utc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss XXX')));
save(fullfile(analysisDir,'results.mat'),'cases','summary');
fid = fopen(fullfile(analysisDir,'metrics.json'),'w','n','UTF-8');
assert(fid>=0,'Transform:MetricsFile','Cannot open metrics.json.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(summary,PrettyPrint=true));
clear fileCleanup
write_figures(cases,analysisDir);
disp(summary);
end

function c = simulate_case(modelName,cfg,t,inputs)
cfg.Duration = t(end);
stim.time = [];
stim.signals.values = inputs;
stim.signals.dimensions = 7;
in = Simulink.SimulationInput(modelName);
in = in.setVariable('ctCfg',cfg,'Workspace',modelName);
in = in.setVariable('ctStim',stim,'Workspace',modelName);
in = in.setModelParameter('StopTime',sprintf('%.15g',t(end)));
out = sim(in);
trace.time = out.ctTrace.time;
trace.values = out.ctTrace.signals.values;
trace.channels = {'a','b','c','alpha','beta','zero','d','q','theta_e', ...
    'd_used','q_used','zero_used','alpha_recon','beta_recon', ...
    'a_recon','b_recon','c_recon','error_a','error_b','error_c'};
assert(numel(trace.time)==numel(t) && max(abs(trace.time-t))<1e-12, ...
    'Transform:SampleGrid','Unexpected trace sample grid.');
c = struct('cfg',cfg,'inputs',inputs,'trace',trace);
end

function metrics = verify_case(c)
v = c.trace.values;
abc = c.inputs(:,1:3);
theta = c.inputs(:,4);
clarkeMatrix = [2/3,-1/3,-1/3;0,1/sqrt(3),-1/sqrt(3);1/3,1/3,1/3];
expectedClarke = abc*clarkeMatrix';
% Independent combined abc->dq formula: does not reuse the model's alpha/beta.
angles = theta+[0,-2*pi/3,2*pi/3];
expectedDq = (2/3)*[sum(abc.*cos(angles),2),-sum(abc.*sin(angles),2)];
if c.cfg.UseIndependentInverse~=0
    selected = c.inputs(:,5:7);
else
    selected = [v(:,7:8),v(:,6)];
end
selected(:,3) = selected(:,3)*c.cfg.ZeroSequenceGain;
expectedInversePark = [selected(:,1).*cos(theta)-selected(:,2).*sin(theta), ...
    selected(:,1).*sin(theta)+selected(:,2).*cos(theta)];
expectedInverseAbc = [expectedInversePark,selected(:,3)] ...
    *[1,-0.5,-0.5;0,sqrt(3)/2,-sqrt(3)/2;1,1,1];
referenceError = max([max(abs(v(:,4:6)-expectedClarke),[],'all'), ...
    max(abs(v(:,7:8)-expectedDq),[],'all'), ...
    max(abs(v(:,10:12)-selected),[],'all'), ...
    max(abs(v(:,13:14)-expectedInversePark),[],'all'), ...
    max(abs(v(:,15:17)-expectedInverseAbc),[],'all')]);
normError = max(abs(sum(abc.^2,2)-1.5*sum(v(:,4:5).^2,2)-3*v(:,6).^2));
rotationNormError = max(abs(sum(v(:,4:5).^2,2)-sum(v(:,7:8).^2,2)));
reconstructionError = max(abs(v(:,15:17)-abc),[],'all');
assert(all(isfinite(v),'all'),'Transform:Finite','Nonfinite trace.');
assert(referenceError<1e-12,'Transform:Reference','Analytic matrix comparison failed.');
assert(normError<1e-10 && rotationNormError<1e-10,'Transform:Norm','Amplitude-invariant norm relation failed.');
assert(max(abs(v(:,18:20)-(v(:,15:17)-abc)),[],'all')<1e-12, ...
    'Transform:LoggedErrors','Logged error channels disagree with reconstruction minus original.');
if c.cfg.UseIndependentInverse==0 && c.cfg.ZeroSequenceGain==1
    assert(reconstructionError<1e-12,'Transform:RoundTrip','Full round-trip reconstruction failed.');
end
metrics = struct('reference_max_error_A',referenceError, ...
    'reconstruction_error_A',reconstructionError,'squared_norm_error_A2',normError, ...
    'rotation_norm_error_A2',rotationNormError);
end

function write_figures(cases,analysisDir)
f = figure('Visible','off','Color','white','Position',[50 50 1200 820]);
figureCleanup = onCleanup(@() close(f));
tiledlayout(3,1); c=cases.balanced_d; t=c.trace.time; v=c.trace.values;
nexttile; plot(t,v(:,1:3),'LineWidth',1.2); grid on; ylabel('abc (A)');
title('Amplitude-invariant transforms: 5 A balanced positive sequence'); legend('a','b','c');
nexttile; plot(t,v(:,4:6),'LineWidth',1.2); grid on; ylabel('Stationary (A)'); legend('alpha','beta','zero');
nexttile; plot(t,v(:,7:8),'LineWidth',1.2); grid on; ylabel('Rotating (A)'); xlabel('Time (s)'); legend('d','q');
save_figure(f,analysisDir,'balanced_transform');

clf(f); tiledlayout(2,1); colors=lines(3);
nexttile; hold on;
for idx=1:3
    plot(t,v(:,idx),'Color',colors(idx,:),'LineWidth',1.3);
    plot(t,v(:,14+idx),'--','Color',colors(idx,:),'LineWidth',1.0);
end
grid on; ylabel('abc (A)'); title('abc -> alpha-beta-zero -> dq -> inverse Park -> inverse Clarke');
legend('a','a reconstructed','b','b reconstructed','c','c reconstructed');
nexttile; plot(t,v(:,18:20),'LineWidth',1.2); grid on;
ylabel('Reconstruction error (A)'); xlabel('Time (s)'); legend('error a','error b','error c');
save_figure(f,analysisDir,'round_trip');

clf(f); tiledlayout(3,1); c=cases.mixed_zero; d=cases.dropped_zero; t=c.trace.time;
nexttile; plot(t,c.inputs(:,1:3),'LineWidth',1.2); grid on; ylabel('abc (A)');
title('Common-mode signal must be retained for full abc reconstruction'); legend('a','b','c');
nexttile; plot(t,c.trace.values(:,6),'LineWidth',1.3); grid on; ylabel('zero (A)');
nexttile; plot(t,[c.trace.values(:,18),d.trace.values(:,18)],'LineWidth',1.3); grid on;
ylabel('Phase-a error (A)'); xlabel('Time (s)'); legend('Retain zero','Discard zero');
save_figure(f,analysisDir,'zero_sequence');

clf(f); tiledlayout(3,1); c=cases.independent_inverse; t=c.trace.time;
nexttile; plot(t,c.trace.values(:,10:12),'LineWidth',1.2); grid on; ylabel('Commands (A)');
title('Independent inverse transform commands'); legend('d used','q used','zero used');
nexttile; plot(t,c.trace.values(:,13:14),'LineWidth',1.2); grid on; ylabel('alpha-beta (A)'); legend('alpha','beta');
nexttile; plot(t,c.trace.values(:,15:17),'LineWidth',1.2); grid on; ylabel('abc (A)'); xlabel('Time (s)'); legend('a','b','c');
save_figure(f,analysisDir,'independent_inverse');

clf(f); tiledlayout(2,1); c=cases.angle_offset; t=c.trace.time;
nexttile; plot(t,c.trace.values(:,1:3),'LineWidth',1.2); grid on; ylabel('abc (A)');
title('Transform angle advanced by 30 electrical degrees');
nexttile; plot(t,c.trace.values(:,7:8),'LineWidth',1.2); grid on; ylabel('dq (A)'); xlabel('Time (s)');
legend('d = 5 cos(30 deg)','q = -5 sin(30 deg)');
save_figure(f,analysisDir,'angle_offset');
end

function save_figure(f,analysisDir,name)
exportgraphics(f,fullfile(analysisDir,[name '.png']),'Resolution',150);
exportgraphics(f,fullfile(analysisDir,[name '.svg']),'ContentType','vector');
end

function restore_file_generation(oldFileGen,cacheDir)
Simulink.fileGenControl('setConfig','config',oldFileGen);
% cacheDir is the exact new temporary directory created by this invocation.
if isfolder(cacheDir), rmdir(cacheDir,'s'); end
end
