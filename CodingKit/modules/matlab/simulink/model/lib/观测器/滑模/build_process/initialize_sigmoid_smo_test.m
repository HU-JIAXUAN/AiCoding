function initialize_sigmoid_smo_test(model)
%INITIALIZE_SIGMOID_SMO_TEST Load local M configuration into this bench only.
initialize_sigmoid_smo_paths();cfg=sigmoid_smo_parameters();test=sigmoid_smo_test_parameters();
pll=sigmoid_smo_pll_parameters(cfg);
assert(cfg.Ts==pll.Ts);t=(0:cfg.Ts:test.Duration)';
[stim,~]=smo_fixture(t,test.Omega*ones(size(t)),test.InitialTheta,test.Iq,cfg);
workspace=get_param(model,'ModelWorkspace');assignin(workspace,'sigmoidCfg',cfg);
assignin(workspace,'pllCfg',pll);assignin(workspace,'sigmoidTestCfg',test);assignin(workspace,'testStim',stim);
end
