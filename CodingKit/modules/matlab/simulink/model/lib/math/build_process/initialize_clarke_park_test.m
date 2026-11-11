function initialize_clarke_park_test(modelName)
%INITIALIZE_CLARKE_PARK_TEST Set model-workspace defaults and sampled inputs.
moduleDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(moduleDir,'src'),fullfile(moduleDir,'parameter'));
cfg = clarke_park_parameters();
t = (0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;
phase = 2*pi*cfg.FrequencyHz*t + cfg.InitialAngleRad;
abc = cfg.Amplitude*cos(phase + [0,-2*pi/3,2*pi/3]);
inputs = [abc,phase+cfg.AngleOffsetRad,zeros(numel(t),3)];
stim.time = [];
stim.signals.values = inputs;
stim.signals.dimensions = 7;
mw = get_param(modelName,'ModelWorkspace');
assignin(mw,'ctCfg',cfg);
assignin(mw,'ctStim',stim);
end
