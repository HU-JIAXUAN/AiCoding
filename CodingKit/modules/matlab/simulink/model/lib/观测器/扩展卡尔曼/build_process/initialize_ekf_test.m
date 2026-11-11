function initialize_ekf_test(model)
%INITIALIZE_EKF_TEST Set editable local defaults and independent physical inputs.
initialize_ekf_paths();cfg=ekf_parameters();test=ekf_test_parameters();time=(0:cfg.Model.Ts:test.Duration).';
[stimulus,truth]=spmsm_estimation_fixture(time,test.ElectricalSpeed*ones(size(time)),test.InitialAngle, ...
    test.Id*ones(size(time)),test.Iq*ones(size(time)),cfg.Model,test.Direction);
stimulus.signals.values(:,6)=test.Enable;stimulus.signals.values(:,7)=test.Reset;
if test.NoiseRms>0
    stream=RandStream('mt19937ar','Seed',test.NoiseSeed);
    stimulus.signals.values(:,3:4)=stimulus.signals.values(:,3:4)+test.NoiseRms*randn(stream,numel(time),2);
end
assert(ismember(test.CurrentDelay,[0,1]));
if test.CurrentDelay>0,stimulus.signals.values(:,3:4)=[zeros(1,2);stimulus.signals.values(1:end-1,3:4)];end
workspace=get_param(model,'ModelWorkspace');assignin(workspace,'ekfCfg',cfg);assignin(workspace,'ekfTestCfg',test);
assignin(workspace,'testStim',stimulus);assignin(workspace,'fixtureTruth',truth);
end
