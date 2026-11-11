function report=compare_sigmoid_basic()
%COMPARE_SIGMOID_BASIC Match input, K, origin slope and PLL; vary explicit LPF.
module=initialize_sigmoid_smo_paths();data=load(fullfile(module,'waveform_analysis','sigmoid_results.mat'),'records');
model='SlidingModeObserverTest';before=find_system('type','block_diagram');cleanup=onCleanup(@()close_added(before));
names={'positive','high_positive','noise_10mA_qualification_drop'};comparisons=cell(6,1);records=struct();index=0;
for k=1:numel(names)
    name=names{k};new=data.records.(name);cfg=smo_parameters();cfg.Ts=new.configuration.Ts;cfg.Rs=new.configuration.Rs;cfg.L=new.configuration.L;
    cfg.SlidingGain=new.configuration.SlidingGain;cfg.Boundary=2/new.configuration.Slope;
    for compensated=0:1
        cfg.Compensate=compensated;cfg=refresh_smo_parameters(cfg);
        assert(abs(cfg.BoundaryPole-new.configuration.LocalErrorPole)<1e-14);
        stim=struct('time',new.time,'signals',struct('values',new.inputs,'dimensions',9));
        in=Simulink.SimulationInput(model);in=in.setVariable('smoCfg',cfg,'Workspace',model);
        in=in.setVariable('pllCfg',new.pll,'Workspace',model);in=in.setVariable('testStim',stim,'Workspace',model);
        in=in.setModelParameter('StopTime',num2str(new.time(end),16));out=sim(in);
        v=out.trace.signals.values;time=out.trace.time;assert(isequal(time,new.time) && isequal(v(:,1:9),new.inputs));
        q=time>=new.metrics.window_start_s;index=index+1;
        comparisons{index}=struct('name',name,'basic_LPF_compensation',compensated, ...
            'same_K_and_origin_slope',true,'same_PLL_and_input',true,'basic_angle_rms',sqrt(mean(v(q,22).^2)), ...
            'sigmoid_angle_rms',new.metrics.angle_rms_rad,'basic_valid_fraction',mean(v(q,12)), ...
            'sigmoid_valid_fraction',new.metrics.valid_fraction);
        records.([name,'_comp',num2str(compensated)])=struct('configuration',cfg,'pll',new.pll,'time',time,'trace',v);
    end
end
report=struct('status','passed','cases',numel(names),'comparison_runs',numel(comparisons),'comparisons',vertcat(comparisons{:}), ...
    'comparison_scope','Matched K, zero-error injection slope, PLL, physical fixture and input; different nonlinear injection/LPF structures. No universal superiority claim.');
save(fullfile(module,'waveform_analysis','sigmoid_comparison_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','sigmoid_comparison_metrics.json'),'w');fprintf(file,'%s',jsonencode(report,'PrettyPrint',true));fclose(file);
disp(struct2table(report.comparisons));clear cleanup;
end
function close_added(before)
after=find_system('type','block_diagram');
for k=1:numel(after),if ~ismember(after{k},before),close_system(after{k},0);end,end
end
