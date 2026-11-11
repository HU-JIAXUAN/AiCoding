function [currentCfg,inverterCfg,testCfg]=frame_pi_test_parameters()
%FRAME_PI_TEST_PARAMETERS Defaults for coordinate-transfer regression.
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(module);
addpath(fullfile(lib,'永磁同步电机','parameter'),fullfile(lib,'逆变器','parameter'));
currentCfg=current_parameters(pmsm_parameters());currentCfg.Ts=50e-6;
inverterCfg=inverter_parameters();testCfg.UseInternalLimit=0;testCfg.StopTime=0.06;
testCfg.ErrorD=0.2;testCfg.ErrorQ=0;testCfg.ResidualD=0;testCfg.ResidualQ=0;
testCfg.FeedforwardD=0;testCfg.FeedforwardQ=0;testCfg.ExtraAngle=0;
testCfg.Track=0;testCfg.Enable=1;testCfg.Reset=0;
end
