function initialize_discrete_pid_test(modelName)
%INITIALIZE_DISCRETE_PID_TEST Load the fixture into the model workspace only.
moduleDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(moduleDir, 'parameter'), fullfile(moduleDir, 'src'));
cfg = discrete_pid_parameters();
pidTestCfg=pid_test_parameters();sample=(0:round(pidTestCfg.Duration/cfg.Ts))';
command = pidTestCfg.CommandInitial*ones(size(sample));
command(sample>=round(pidTestCfg.CommandTime/cfg.Ts) & sample<round(pidTestCfg.ReleaseTime/cfg.Ts))=pidTestCfg.CommandHigh;
command(sample>=round(pidTestCfg.ReleaseTime/cfg.Ts))=pidTestCfg.CommandFinal;
% Structure without time: each source consumes one row every pidCfg.Ts.
sampled = @(values) struct('time',[], ...
    'signals',struct('values',values,'dimensions',1));
stim.command = sampled(command);
stim.enable = sampled(repmat(logical(pidTestCfg.Enable),size(sample)));
stim.reset = sampled(repmat(logical(pidTestCfg.Reset),size(sample)));
modelWorkspace = get_param(modelName, 'ModelWorkspace');
assignin(modelWorkspace, 'pidCfg', cfg);
assignin(modelWorkspace, 'pidTestCfg', pidTestCfg);
assignin(modelWorkspace, 'pidStim', stim);
end
