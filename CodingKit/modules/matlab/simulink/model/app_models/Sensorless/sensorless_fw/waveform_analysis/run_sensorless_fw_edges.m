function summary=run_sensorless_fw_edges(outputFolder,reanalyze)
%RUN_SENSORLESS_FW_EDGES Preserve independent moving/fault/restart results.
if nargin<1,outputFolder=fullfile(fileparts(mfilename('fullpath')),'edges');end
if nargin<2,reanalyze=false;end
if ~isfolder(outputFolder),mkdir(outputFolder);end
if reanalyze,prefix='edge_reanalysis';else,prefix='edge';end
cases=sensorless_fw_edge_cases();limits=sensorless_fw_validation_parameters();results=cell(numel(cases),1);
for k=1:numel(cases)
    item=cases(k);p=item.parameters;
    try
        if reanalyze
            previous=load(fullfile(outputFolder,[item.name '.mat']));record=previous.record;
            assert(isequaln(record.parameters,refresh_sensorless_fw_parameters(p)));
            assert(isequaln(record.stimulus,item.stimulus));
        else
            record=run_sensorless_fw_case(p,item.stimulus);
        end
        cp=record.plant.columns;cg=record.guard.columns;cc=record.controller.columns;
        physical=record.plant.trace;g=record.guard.trace;
        normI=hypot(physical(:,cp.id_true),physical(:,cp.iq_true));
        continuity=max(abs(physical(2:end,cp.phase_current)-physical(1:end-1,cp.next_phase_current)),[],'all');
        metrics=struct('current_peak_A',max(normI),'continuity_error_A',continuity, ...
            'speed_end_rad_per_s',physical(end,cp.speed_mechanical),'permit_count',nnz(g(:,cg.permit)>0.5), ...
            'emf_end_V',g(end,cg.emf_magnitude),'host_seconds',record.host_seconds);
        checks=struct('kcl',max(abs(sum(physical(:,cp.phase_current),2)))<limits.KclTolerance, ...
            'physical_state_continuity',continuity<1e-11);
        % Bound a *single physical step* by the declared PMSM torque equation.
        % A loaded coasting rotor need not retain an arbitrary end speed.
        torqueBound=1.5*p.pmsmCfg.PolePairs*(p.pmsmCfg.Flux+ ...
            abs(p.pmsmCfg.Ld-p.pmsmCfg.Lq)*max(normI))*max(normI);
        speedStepBound=p.bridgeCfg.Ts/p.pmsmCfg.J*(torqueBound+ ...
            max(abs(physical(:,cp.load_torque)))+p.pmsmCfg.B*max(abs(physical(:,cp.speed_mechanical))))+1e-11;
        metrics.maximum_speed_step= max(abs(diff(physical(:,cp.speed_mechanical))));
        metrics.speed_step_bound=speedStepBound;
        checks.mechanical_step_bound=metrics.maximum_speed_step<=speedStepBound;
        switch item.kind
            case 'moving_refused'
                checks.no_alignment=all(g(:,cg.permit)==0)&&all(physical(:,cp.bridge_mode)==0);
                checks.motion_preserved=abs(metrics.speed_end_rad_per_s)>40;
                checks.observed_motion=metrics.emf_end_V>p.startGuardCfg.MaxStartEmf;
                checks.no_current=max(normI)<1e-8;
            case 'observer_disabled'
                checks.no_alignment=all(g(:,cg.permit)==0)&&all(physical(:,cp.bridge_mode)==0);
                checks.no_observation_count=all(g(:,cg.warm_count)==0);
                checks.no_current=max(normI)<1e-8;
            case 'moving_exit'
                first=round(item.event_time/p.bridgeCfg.Ts)+1;
                off=find(record.plant.time>=item.event_time-p.bridgeCfg.Ts/4 & physical(:,cp.bridge_mode)==0,1);
                assert(~isempty(off));metrics.gate_off_latency_s=record.plant.time(off)-item.event_time;
                after=record.plant.time>=item.event_time+2*p.currentCfg.Ts;
                afterGuard=record.guard.time>=item.event_time+2*p.currentCfg.Ts;
                checks.prompt_gate_off=metrics.gate_off_latency_s<=2*p.currentCfg.Ts+1e-12;
                checks.no_moving_realign=all(physical(after,cp.bridge_mode)==0)&&all(g(afterGuard,cg.permit)==0);
                metrics.speed_before_event=physical(first-1,cp.speed_mechanical);
                metrics.speed_at_event=physical(first,cp.speed_mechanical);
                checks.motion_preserved=metrics.speed_before_event>100&& ...
                    max(abs(diff(physical(first-1:first+1,cp.speed_mechanical))))<=speedStepBound;
                checks.current_not_cleared=normI(first)>1;
                checks.current_peak=max(normI)<=p.refCfg.CurrentMax+limits.CurrentOvershoot;
            case 'observer_loss'
                off=find(record.plant.time>=item.event_time-p.bridgeCfg.Ts/4 & physical(:,cp.bridge_mode)==0,1);
                assert(~isempty(off));metrics.gate_off_latency_s=record.plant.time(off)-item.event_time;
                after=record.plant.time>=item.event_time+p.handoverCfg.LossTime+2*p.currentCfg.Ts;
                checks.loss_timeout=metrics.gate_off_latency_s<=p.handoverCfg.LossTime+2*p.currentCfg.Ts+1e-12;
                checks.remains_off=all(physical(after,cp.bridge_mode)==0);
                checks.fault_latched=record.controller.trace(end,cc.handover_fault)>0;
                first=round(item.event_time/p.bridgeCfg.Ts)+1;
                metrics.speed_before_event=physical(first-1,cp.speed_mechanical);
                metrics.speed_at_event=physical(first,cp.speed_mechanical);
                checks.motion_preserved=metrics.speed_before_event>100&& ...
                    max(abs(diff(physical(first-1:first+1,cp.speed_mechanical))))<=speedStepBound;
                checks.current_peak=max(normI)<=p.refCfg.CurrentMax+limits.CurrentOvershoot;
            case 'restart'
                after=record.guard.time>=item.event_time;
                gap=g(after,cg.permit)==0;metrics.off_samples_after_direction=nnz(gap);
                checks.requalified=metrics.off_samples_after_direction>=p.startGuardCfg.ObserveTicks;
                spec=struct('name',item.name,'expect_tracking',true,'require_weakening',false, ...
                    'require_regeneration',false,'expected_counterexample',false,'target_speed',-80);
                final=analyze_sensorless_fw_case(record,spec,limits);metrics.final=final.metrics;
                checks.restart_tracking=final.passed;
                checks.final_direction=record.controller.trace(end,cc.omega_base)<0;
            case 'counterexample'
                checks.bypass_active=any(g(:,cg.permit)>0.5)&&any(physical(:,cp.bridge_mode)==1);
                checks.blind_alignment_exceeds_nominal_current=max(normI)>p.refCfg.CurrentMax+limits.CurrentOvershoot;
            otherwise,error('Unknown edge case');
        end
        values=struct2cell(checks);passed=all(cellfun(@(x)isscalar(x)&&x,values));
        analysis=struct('name',item.name,'kind',item.kind,'passed',passed,'metrics',metrics,'checks',checks);
        if reanalyze
            save(fullfile(outputFolder,[item.name '_reanalysis.mat']),'analysis','limits');
        else
            save(fullfile(outputFolder,[item.name '.mat']),'record','analysis','limits');
        end
        results{k}=analysis;
    catch exception
        results{k}=struct('name',item.name,'kind',item.kind,'passed',false,'runtime_error', ...
            getReport(exception,'extended','hyperlinks','off'));
    end
    fprintf('FW_EDGE %s: passed=%d\n',item.name,results{k}.passed);
    fid=fopen(fullfile(outputFolder,[prefix '_progress.json']),'w','n','UTF-8');
    fwrite(fid,jsonencode(results(1:k),PrettyPrint=true),'char');fclose(fid);
end
passed=all(cellfun(@(x)x.passed,results));if passed,status='passed';else,status='failed';end
summary=struct('status',status,'release',version('-release'),'model_cases',numel(cases), ...
    'normal_cases',sum(~strcmp({cases.kind},'counterexample')), ...
    'counterexamples',sum(strcmp({cases.kind},'counterexample')),'results',{results}, ...
    'reused_saved_simulations',logical(reanalyze), ...
    'mechanical_check','Single-step torque/J bound and state continuity; original end-speed >100 criterion was invalid for a loaded coasting rotor. Original records retained.');
fid=fopen(fullfile(outputFolder,[prefix '_results.json']),'w','n','UTF-8');
fwrite(fid,jsonencode(summary,PrettyPrint=true),'char');fclose(fid);
assert(passed,'Inspect preserved edge-case data and the declared physical criteria.');
end
