function initialize_speed_profile_test(model)
%INITIALIZE_SPEED_PROFILE_TEST Load module-local profile and test settings.
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'src'),fullfile(module,'parameter'));
profileCfg=speed_profile_parameters();profileTestCfg=speed_profile_test_parameters();workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'profileCfg',profileCfg);assignin(workspace,'profileTestCfg',profileTestCfg);
assignin(workspace,'testStim',speed_profile_stimulus(profileTestCfg));
end
