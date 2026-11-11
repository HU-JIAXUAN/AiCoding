function report=run_bridge_validation()
%RUN_BRIDGE_VALIDATION Physical circuit MIL, scheduling and rejection checks.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));
names={'coast_forward','coast_reverse','release_forward','release_reverse','active_short', ...
    'pwm_locked','rectify_forward','rectify_reverse','coast_short_release', ...
    'low_bus_rectify','zero_friction_coast','half_step','spmsm_release','zero_voltage_PWM_is_short','invalid_mode'};
records=struct();metrics=cell(1,numel(names));
for test=1:numel(names)
    name=names{test};p=bridge_test_parameters();p.bridgeTestCfg.ModeTimes=0;p.bridgeTestCfg.ModeValues=0;
    p.bridgeTestCfg.Duration=0.01;
    switch name
        case 'coast_reverse',p.bridgeCfg.Speed0=-80;
        case 'release_forward',p.bridgeCfg.Iq0=3;
        case 'release_reverse',p.bridgeCfg.Speed0=-80;p.bridgeCfg.Iq0=-3;
        case {'active_short','zero_voltage_PWM_is_short'}
            p.bridgeTestCfg.ModeValues=2;
            if strcmp(name,'zero_voltage_PWM_is_short'),p.bridgeTestCfg.ModeValues=1;end
        case 'pwm_locked'
            p.bridgeCfg.Speed0=0;p.bridgeCfg.MechanicalEnabled=0;
            p.bridgeTestCfg.ModeValues=1;p.bridgeTestCfg.Duty=[0.65,0.4,0.45];
        case 'rectify_forward',p.bridgeCfg.Speed0=400;p.bridgeCfg.MechanicalEnabled=0;p.bridgeTestCfg.Duration=0.006;
        case 'rectify_reverse',p.bridgeCfg.Speed0=-400;p.bridgeCfg.MechanicalEnabled=0;p.bridgeTestCfg.Duration=0.006;
        case 'coast_short_release',p=bridge_test_parameters();
        case 'low_bus_rectify',p.bridgeCfg.Vdc=24;p.bridgeCfg.Speed0=120;p.bridgeTestCfg.Duration=0.02;
        case 'zero_friction_coast',p.bridgeCfg.B=0;
        case 'half_step',p=bridge_test_parameters();p.bridgeCfg.Ts=p.bridgeCfg.Ts/2;
        case 'spmsm_release',p.bridgeCfg.Lq=p.bridgeCfg.Ld;p.bridgeCfg.Iq0=3;
    end
    p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);stimulus=bridge_plant_stimulus(p);
    fprintf('Bridge MIL %s\n',name);
    if strcmp(name,'invalid_mode')
        stimulus.signals.values(round(0.002/p.bridgeCfg.Ts)+1:end,4)=3;rejected=false;diagnostic='';
        try,run_bridge_case(p,stimulus);catch exception
            diagnostic=getReport(exception,'extended','hyperlinks','off');
            rejected=contains(diagnostic,'Bridge mode must be 0, 1 or 2');
        end
        assert(rejected,'Expected the specific runtime bridge-mode assertion.');
        metrics{test}=struct('name',name,'passed',true,'expected_rejection',true,'samples',0, ...
            'max_current_A',NaN,'final_speed_rad_s',NaN,'returned_energy_J',NaN, ...
            'max_equation_residual_V',NaN,'max_bridge_power_residual_W',NaN, ...
            'max_next_current_age_difference_A',NaN,'max_M_replay_difference',NaN);
        fid=fopen(fullfile(module,'waveform_analysis','bridge_invalid_mode.json'),'w');
        cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(struct('expected_rejection',true, ...
            'requested_mode',3,'requested_time_s',0.002,'diagnostic',diagnostic),PrettyPrint=true));clear cleanup
        continue
    end
    r=run_bridge_case(p,stimulus);records.(name)=r;
    try,metric=checkRecord(r,name);catch exception
        save(fullfile(module,'waveform_analysis',['bridge_',name,'_failure.mat']),'r','-v7.3');rethrow(exception);
    end
    columns=r.columns;trace=r.trace;time=r.time;
    switch name
        case {'coast_forward','coast_reverse','zero_friction_coast'}
            assert(max(abs(trace(:,columns.phase_current)),[],'all')==0);
            assert(max(abs(trace(:,columns.dc_current)))==0);
            count=(0:numel(time)-1)';cfg=r.parameters.bridgeCfg;
            expected=cfg.Speed0*(1-cfg.Ts*cfg.B/cfg.J).^count;
            assert(max(abs(trace(:,columns.speed_mechanical)-expected))<1e-8);
        case {'release_forward','release_reverse','spmsm_release'}
            assert(norm(trace(2,columns.current_ab))>0);
            assert(norm(trace(2,columns.current_ab))<norm(trace(1,columns.current_ab)));
            assert(all(trace(time>=0.002,columns.phase_current)==0,'all'));
            assert(metric.returned_energy_J>0);
        case {'active_short','zero_voltage_PWM_is_short'}
            assert(metric.max_current_A>8 && abs(metric.final_speed_rad_s)<abs(p.bridgeCfg.Speed0));
            if strcmp(name,'zero_voltage_PWM_is_short')
                reference=records.active_short;
                compare=[columns.current_ab,columns.speed_mechanical,columns.theta_e,columns.torque];
                assert(max(abs(trace(:,compare)-reference.trace(:,compare)),[],'all')<1e-10);
            end
        case 'pwm_locked'
            cfg=p.bridgeCfg;theta=cfg.PolePairs*cfg.Position0;
            rotation=[cos(theta),-sin(theta);sin(theta),cos(theta)];
            rotorVoltage=rotation'*trace(1,columns.voltage_ab)';current=[cfg.Id0;cfg.Iq0];
            worst=0;
            for index=1:numel(time)
                worst=max(worst,max(abs(trace(index,columns.current_ab)'-rotation*current)));
                current=([cfg.Ld;cfg.Lq].*current+cfg.Ts*rotorVoltage)./([cfg.Ld;cfg.Lq]+cfg.Ts*cfg.Rs);
            end
            assert(worst<1e-10 && all(trace(:,columns.speed_mechanical)==0));
        case {'rectify_forward','rectify_reverse','low_bus_rectify'}
            assert(metric.returned_energy_J>0.01 && min(trace(:,columns.dc_current))<0);
        case 'coast_short_release'
            assert(all(trace(time<0.015,columns.phase_current)==0,'all'));
            assert(max(vecnorm(trace(time>=0.015 & time<0.025,columns.current_ab),2,2))>8);
            assert(all(trace(time>=0.03,columns.phase_current)==0,'all'));
        case 'half_step'
            reference=records.coast_short_release;
            assert(max(abs(trace(1:2:end,columns.speed_mechanical)-reference.trace(:,columns.speed_mechanical)))<0.1);
            assert(max(abs(trace(1:2:end,columns.current_ab)-reference.trace(:,columns.current_ab)),[],'all')<0.2);
    end
    metrics{test}=metric;fprintf('%s PASS, peak %.7g A, returned %.7g J\n',name,metric.max_current_A,metric.returned_energy_J);
end
metrics=vertcat(metrics{:});report=struct('release',version('-release'),'passed',all([metrics.passed]), ...
    'tests',numel(names),'physical_cases',numel(names)-1,'expected_rejections',1,'cases',metrics, ...
    'bus_is_ideal_stiff_voltage',true,'zero_off_state_leakage',true,'switching_ripple_modeled',false, ...
    'Simscape_reference_executed',false,'hardware_tested',false);
save(fullfile(module,'waveform_analysis','bridge_results.mat'),'records','report','-v7.3');
fid=fopen(fullfile(module,'waveform_analysis','bridge_metrics.json'),'w');cleanup=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(report,PrettyPrint=true));clear cleanup
plot_bridge_results(records,module);disp(report);
end
function metric=checkRecord(r,name)
cfg=r.parameters.bridgeCfg;t=r.time;x=r.trace;c=r.columns;stimulus=r.stimulus.signals.values;
assert(size(x,2)==33 && numel(t)==round(r.parameters.bridgeTestCfg.Duration/cfg.Ts)+1);
assert(max(abs(diff(t)-cfg.Ts))<1e-12);
assert(max(abs(sum(x(:,c.phase_current),2)))<1e-10);
assert(max(abs(x(2:end,c.phase_current)-x(1:end-1,c.next_phase_current)),[],'all')<1e-10);
assert(max(abs(x(:,c.phase_voltage)+x(:,c.neutral_voltage)-x(:,c.pole_voltage)),[],'all')<1e-8);
powerResidual=cfg.Vdc*x(:,c.dc_current)-sum(x(:,c.phase_voltage).*x(:,c.next_phase_current),2)-x(:,c.bridge_loss);
assert(max(abs(powerResidual))<1e-6 && min(x(:,c.bridge_loss))>=0);
assert(max(x(:,c.equation_residual))<1e-8);
mode=stimulus(:,4);off=mode==0;assert(all(x(off,c.dc_current)<=1e-9));
for phase=1:3
    states=x(:,c.diode_states(phase));current=x(:,c.next_phase_current(phase));pole=x(:,c.pole_voltage(phase));
    lower=off & states>0;upper=off & states<0;floating=off & states==0;
    assert(all(current(lower)>=-cfg.CurrentTolerance));
    assert(all(current(upper)<=cfg.CurrentTolerance));
    assert(all(abs(pole(lower)+cfg.DiodeVf+cfg.DiodeRon*current(lower))<1e-8));
    assert(all(abs(pole(upper)-cfg.Vdc-cfg.DiodeVf+cfg.DiodeRon*current(upper))<1e-8));
    assert(all(abs(current(floating))<=cfg.CurrentTolerance));
    assert(all(pole(floating)>=-cfg.DiodeVf-cfg.VoltageTolerance & pole(floating)<=cfg.Vdc+cfg.DiodeVf+cfg.VoltageTolerance));
end
% This replay verifies embedded-source wiring and time ages; independent
% physical references are the RL/neutral-bisection/energy checks, not replay.
state=cfg.State0;worst=0;
for index=1:numel(t)
    [iab,iabc,speed,theta,torque,wm,wk]=pmsm_bridge_output(state,cfg.Vector);
    [state,u,v,dc,diodes,loss,residual,nextI,neutral,poles]=pmsm_bridge_step(state, ...
        stimulus(index,1:3)',stimulus(index,4),stimulus(index,5),cfg.Vector);
    expected=[stimulus(index,:),iab',iabc',v',u',speed,theta,torque,dc,diodes',wm,wk,loss,residual,nextI',neutral,poles'];
    worst=max(worst,max(abs(x(index,:)-expected)));
end
assert(worst<1e-8,'Embedded model and M replay differ.');
metric=struct('name',name,'passed',true,'expected_rejection',false,'samples',numel(t), ...
    'max_current_A',max(vecnorm(x(:,c.current_ab),2,2)),'final_speed_rad_s',x(end,c.speed_mechanical), ...
    'returned_energy_J',-trapz(t,min(0,cfg.Vdc*x(:,c.dc_current))), ...
    'max_equation_residual_V',max(x(:,c.equation_residual)), ...
    'max_bridge_power_residual_W',max(abs(powerResidual)), ...
    'max_next_current_age_difference_A',max(abs(x(2:end,c.phase_current)-x(1:end-1,c.next_phase_current)),[],'all'), ...
    'max_M_replay_difference',worst);
end
