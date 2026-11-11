function initialize_frame_pi_test(model)
%INITIALIZE_FRAME_PI_TEST Assign defaults only in the test model workspace.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'));
[currentCfg,inverterCfg,testCfg]=frame_pi_test_parameters();
sample=(0:round(testCfg.StopTime/currentCfg.Ts))';
testStim.time=sample*currentCfg.Ts;
testStim.signals.values=repmat([testCfg.ErrorD,testCfg.ErrorQ,testCfg.ResidualD,testCfg.ResidualQ, ...
    testCfg.FeedforwardD,testCfg.FeedforwardQ,testCfg.ExtraAngle,testCfg.Track,testCfg.Enable,testCfg.Reset],numel(sample),1);
testStim.signals.dimensions=10;
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'currentCfg',currentCfg);assignin(workspace,'inverterCfg',inverterCfg);
assignin(workspace,'testCfg',testCfg);assignin(workspace,'testStim',testStim);
end
