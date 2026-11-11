function initialize_frame_blend_test(model)
%INITIALIZE_FRAME_BLEND_TEST Load a local input table in the model workspace.
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'parameter'));
cfg=blend_test_parameters();testStim.time=(0:size(cfg.Inputs,1)-1)'*cfg.Ts;
testStim.signals.values=cfg.Inputs;testStim.signals.dimensions=9;
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'blendTestCfg',cfg);assignin(workspace,'testStim',testStim);
end
