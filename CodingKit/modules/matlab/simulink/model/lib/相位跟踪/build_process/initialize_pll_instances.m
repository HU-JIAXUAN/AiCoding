function initialize_pll_instances(model)
%INITIALIZE_PLL_INSTANCES Load two distinct configurations for the mask test.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'));
pllA=angle_tracking_parameters();
pllA.Kp=100;pllA.Ki=0;pllA.Kaw=0;pllA.Theta0=-0.2;
pllB=angle_tracking_parameters();
pllB.Kp=250;pllB.Ki=0;pllB.Kaw=0;pllB.Theta0=0.3;
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'pllA',pllA);assignin(workspace,'pllB',pllB);
end
