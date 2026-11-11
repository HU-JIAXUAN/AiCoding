function report=analyze_extension_foc(record,spec,limits)
%ANALYZE_EXTENSION_FOC Common physical, timing and actual-input criteria.
p=record.parameters;cp=record.plant.columns;co=record.observer.columns;
cc=record.controller.columns;cg=record.guard.columns;
physical=record.plant.trace;observer=record.observer.trace;control=record.controller.trace;guard=record.guard.trace;
t=record.controller.time;ip=round(t/p.bridgeCfg.Ts)+1;
assert(max(abs(record.plant.time(ip)-t))<1e-11);
curr=physical(ip,cp.phase_current);voltage=record.actuation.trace(:,record.actuation.columns.phase_voltage);
currentError=max(abs(observer(:,co.current_ab)-clarke(curr)),[],'all');
voltageError=max(abs(observer(:,co.observer_voltage)-clarke(voltage)),[],'all');
normI=hypot(physical(:,cp.id_true),physical(:,cp.iq_true));
continuity=max(abs(physical(2:end,cp.phase_current)-physical(1:end-1,cp.next_phase_current)),[],'all');
torqueBound=1.5*p.pmsmCfg.PolePairs*p.pmsmCfg.Flux*max(normI);
speedBound=p.bridgeCfg.Ts/p.pmsmCfg.J*(torqueBound+max(abs(physical(:,cp.load_torque)))+p.pmsmCfg.B*max(abs(physical(:,cp.speed_mechanical))))+1e-11;
speedStep=max(abs(diff(physical(:,cp.speed_mechanical))));
checks=struct('current_input',currentError<=limits.InputAgreementTolerance, ...
    'voltage_input',voltageError<=limits.InputAgreementTolerance, ...
    'kcl',max(abs(sum(physical(:,cp.phase_current),2)))<=limits.KclTolerance, ...
    'current_continuity',continuity<=limits.PhysicalContinuityTolerance,'mechanical_step',speedStep<=speedBound, ...
    'current_limit',max(normI)<=p.refCfg.CurrentMax+limits.CurrentOvershoot);
metrics=struct('current_input_error_A',currentError,'voltage_input_error_V',voltageError, ...
    'physical_current_peak_A',max(normI),'physical_current_continuity_error_A',continuity, ...
    'maximum_speed_step',speedStep,'speed_step_bound',speedBound,'host_seconds',record.host_seconds);
switch spec.kind
    case 'tracking'
        common=struct('name',spec.name,'expect_tracking',true,'require_weakening',false, ...
            'require_regeneration',false,'expected_counterexample',false);
        result=analyze_sensorless_fw_case(record,common,limits);checks.closed_loop=result.passed;metrics.final=result.metrics;
        index=find(control(:,cc.handover_mode)==4,1);checks.acquired=~isempty(index);
        if ~isempty(index),metrics.auto_time_s=t(index);end
        reference=physicalVector(control(:,cc.reference),control(:,cc.theta_used));
        start=physicalVector(control(:,[cc.id_start,cc.iq_start]),control(:,cc.theta_start));
        closed=physicalVector([zeros(size(t)),control(:,cc.iq_closed)],control(:,cc.theta_used));
        expected=(1-control(:,cc.beta)).*start+control(:,cc.beta).*closed;expected(control(:,cc.run)<.5,:)=0;
        metrics.reference_blend_error=max(abs(reference-expected),[],'all');
        checks.reference_frame=metrics.reference_blend_error<=limits.FrameAgreementTolerance;
        delta=wrap(diff(control(:,cc.theta_used))-p.currentCfg.Ts*control(1:end-1,cc.omega_base));
        metrics.frame_delta_error=max(abs(wrap(delta-control(2:end,cc.delta_extra))));
        checks.frame_delta=metrics.frame_delta_error<=limits.FrameAgreementTolerance;
        applied=physicalVector(record.actuation.trace(:,record.actuation.columns.voltage_request),record.actuation.trace(:,record.actuation.columns.theta_control));
        blend=control(1:end-1,cc.handover_mode)==3&control(2:end,cc.handover_mode)==3;
        jump=vecnorm(diff(applied),2,2);metrics.blend_voltage_step=max(jump(blend));
        checks.blend_voltage=~isempty(metrics.blend_voltage_step)&&metrics.blend_voltage_step<limits.BlendVoltageStepMax;
    case {'observer_loss','moving_exit'}
        before=t>=spec.event_time-limits.SteadyWindow&t<spec.event_time;
        angleError=wrap(observer(:,co.theta_hat)-physical(ip,cp.theta_e));
        metrics.pre_event_angle_rms=sqrt(mean(angleError(before).^2));
        metrics.pre_event_speed_rms=sqrt(mean((physical(ip(before),cp.speed_mechanical)-p.focCfg.SpeedReference).^2));
        checks.pre_event_tracking=metrics.pre_event_angle_rms<=limits.AngleRmsMax&&metrics.pre_event_speed_rms<=limits.SpeedErrorRmsMax;
        checks.pre_event_auto=mean(control(before,cc.handover_mode)==4)>=limits.AutoFractionMin;
        index=find(t>=spec.event_time&control(:,cc.run)<.5,1);
        checks.gate_off=~isempty(index);
        if isempty(index),metrics.gate_off_latency=Inf;
        else,metrics.gate_off_latency=t(index)-spec.event_time;end
        if strcmp(spec.kind,'observer_loss')
            checks.loss_latency=abs(metrics.gate_off_latency-p.handoverCfg.LossTime)<=p.currentCfg.Ts/4;
            checks.fault_latched=~isempty(index)&&all(control(index:end,cc.handover_fault)>0);
        else
            checks.immediate_exit=metrics.gate_off_latency<=p.currentCfg.Ts/4;
            checks.no_realign=all(guard(t>=spec.event_time,cg.permit)<.5);
        end
        checks.remains_off=~isempty(index)&&all(control(index:end,cc.run)<.5);
    case 'moving_refused'
        checks.no_gate=all(physical(:,cp.bridge_mode)==0);
        checks.no_permission=all(guard(:,cg.permit)<.5);
        checks.observed_motion=guard(end,cg.terminal_voltage_magnitude)>p.startGuardCfg.MaxStartVoltage;
        checks.no_current=max(normI)<1e-9;
        checks.motion_not_erased=abs(physical(end,cp.speed_mechanical))>50;
    case 'observer_disabled'
        checks.no_gate=all(physical(:,cp.bridge_mode)==0);
        checks.no_permission=all(guard(:,cg.permit)<.5)&&all(guard(:,cg.warm_count)==0);
    otherwise,error('Unknown case classification.');
end
values=struct2cell(checks);passed=all(cellfun(@(x)isscalar(x)&&x,values));
report=struct('name',spec.name,'algorithm',record.kind,'kind',spec.kind,'passed',passed,'checks',checks,'metrics',metrics);
end
function result=clarke(x)
result=[(2*x(:,1)-x(:,2)-x(:,3))/3,(x(:,2)-x(:,3))/sqrt(3)];
end
function result=physicalVector(x,angle)
result=[cos(angle).*x(:,1)-sin(angle).*x(:,2),sin(angle).*x(:,1)+cos(angle).*x(:,2)];
end
function result=wrap(x)
result=atan2(sin(x),cos(x));
end
