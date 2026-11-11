function initialize_open_loop_drive_test(model)
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'parameter'),fullfile(module,'src'));
openLoopCfg=open_loop_drive_parameters();openLoopTestCfg=open_loop_drive_test_parameters();
time=(0:openLoopCfg.Ts:openLoopTestCfg.Duration)';
testStim=struct('time',[],'signals',struct('values',[openLoopTestCfg.Frequency+0*time,ones(size(time)),zeros(size(time)), ...
    openLoopTestCfg.Current+0*time,openLoopTestCfg.TerminalVoltage+0*time,openLoopTestCfg.BusVoltage+0*time],'dimensions',6));
workspace=get_param(model,'ModelWorkspace');assignin(workspace,'openLoopCfg',openLoopCfg);assignin(workspace,'openLoopTestCfg',openLoopTestCfg);assignin(workspace,'testStim',testStim);
end
