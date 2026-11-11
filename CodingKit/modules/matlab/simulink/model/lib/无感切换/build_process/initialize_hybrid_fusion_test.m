function initialize_hybrid_fusion_test(model)
%INITIALIZE_HYBRID_FUSION_TEST Load local M parameters into this model workspace.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
cfg=hybrid_fusion_parameters();test=hybrid_fusion_test_parameters();
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'fusionCfg',cfg);assignin(workspace,'fusionTestCfg',test);
assignin(workspace,'testStim',hybrid_fusion_stimulus(test,cfg));
end
