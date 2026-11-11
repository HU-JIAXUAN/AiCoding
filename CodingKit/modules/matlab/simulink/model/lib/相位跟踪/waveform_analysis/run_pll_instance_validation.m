function report=run_pll_instance_validation()
%RUN_PLL_INSTANCE_VALIDATION Check gains, initial states and parameter isolation.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
model='AngleTrackingInstancesTest';open_system(fullfile(module,'src',[model,'.slx']));
initialize_pll_instances(model);workspace=get_param(model,'ModelWorkspace');
first=evalin(workspace,'pllA');second=evalin(workspace,'pllB');records=struct();
names={'distinct_gains_and_initial_states','swapped_instances','first_instance_only_changed'};
for test=1:3
    cfgA=first;cfgB=second;
    if test==2,cfgA=second;cfgB=first;elseif test==3,cfgA.Theta0=0.7;end
    input=Simulink.SimulationInput(model);
    input=input.setVariable('pllA',cfgA,'Workspace',model);
    input=input.setVariable('pllB',cfgB,'Workspace',model);
    output=sim(input);trace=output.trace.signals.values;time=output.trace.time;
    expected=zeros(numel(time),4);
    configurations={cfgA,cfgB};
    for instance=1:2
        cfg=configurations{instance};sample=round(time/cfg.Ts);
        theta=0.1+(cfg.Theta0-0.1)*(1-cfg.Kp*cfg.Ts).^sample;
        expected(:,2*instance-1)=theta;expected(:,2*instance)=cfg.Kp*(0.1-theta);
    end
    angleError=max(abs(trace(:,[1,3])-expected(:,[1,3])),[],'all');
    speedError=max(abs(trace(:,[2,4])-expected(:,[2,4])),[],'all');
    assert(angleError<1e-12 && speedError<1e-10);
    if test==3,assert(isequal(trace(:,3:4),records.distinct_gains_and_initial_states.trace(:,3:4)));end
    record=struct('pllA',cfgA,'pllB',cfgB,'time',time,'trace',trace,'expected',expected, ...
        'angle_max_error_rad',angleError,'speed_max_error_rad_s',speedError,'passed',true);
    records.(names{test})=record;
end
report=struct('status','passed','release',version('-release'),'tests',3,'passed',3, ...
    'channels',{{'theta_A','omega_A','theta_B','omega_B'}},'records',records);
folder=fullfile(module,'waveform_analysis');save(fullfile(folder,'instances.mat'),'report');
summary=rmfield(report,'records');summary.cases=names;
summary.angle_max_error_rad=cellfun(@(name)records.(name).angle_max_error_rad,names);
summary.speed_max_error_rad_s=cellfun(@(name)records.(name).speed_max_error_rad_s,names);
file=fopen(fullfile(folder,'instance_metrics.json'),'w');fprintf(file,'%s',jsonencode(summary,PrettyPrint=true));fclose(file);
figureHandle=figure('Visible','off');tiledlayout(2,1);
base=records.distinct_gains_and_initial_states;
nexttile;plot(base.time,base.trace(:,[1,3]));ylabel('angle / rad');legend('A','B');grid on;
nexttile;plot(base.time,base.trace(:,[2,4]));ylabel('speed / rad/s');xlabel('time / s');legend('A','B');grid on;
exportgraphics(figureHandle,fullfile(folder,'instances.png'));
exportgraphics(figureHandle,fullfile(folder,'instances.svg'),'ContentType','vector');close(figureHandle);
disp(summary);
end
