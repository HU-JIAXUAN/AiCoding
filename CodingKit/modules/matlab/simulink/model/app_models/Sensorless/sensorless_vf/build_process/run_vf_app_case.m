function record=run_vf_app_case(p,stimulus)
%RUN_VF_APP_CASE SimulationInput overrides; no raw MAT is written.
if nargin<1,p=vf_app_parameters();end
if nargin<2,stimulus=open_loop_app_stimulus(p);end
record=run_open_loop_app_case('vf',p,stimulus);
end
