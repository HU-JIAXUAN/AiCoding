function initialize_hf_plant_test(model)
%INITIALIZE_HF_PLANT_TEST Load this module's physical plant and pulse settings.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'));
hfPlantCfg=pmsm_hf_parameters();hfPlantTestCfg=hf_plant_test_parameters();
testStim=hf_plant_stimulus(hfPlantTestCfg);
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'hfPlantCfg',hfPlantCfg);assignin(workspace,'hfPlantTestCfg',hfPlantTestCfg);
assignin(workspace,'testStim',testStim);
end
