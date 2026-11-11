function record=run_if_app_case(p,stimulus)
%RUN_IF_APP_CASE SimulationInput overrides; no raw MAT is written.
if nargin<1,p=if_app_parameters();end
if nargin<2,stimulus=open_loop_app_stimulus(p);end
record=run_open_loop_app_case('if',p,stimulus);
end
