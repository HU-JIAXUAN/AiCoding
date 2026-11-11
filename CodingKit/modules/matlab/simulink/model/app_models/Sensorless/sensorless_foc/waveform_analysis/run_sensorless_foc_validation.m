function report=run_sensorless_foc_validation(selectedCases)
%RUN_SENSORLESS_FOC_VALIDATION Check physical capture, transfer, control and exit.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));
cfg=sensorless_foc_validation_parameters();names=cfg.Cases;
if nargin>0
    selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,names)));
    names=names(ismember(names,selectedCases));assert(~isempty(names));
end
records=struct();metrics=cell(1,numel(names));
for test=1:numel(names)
    name=names{test};p=sensorless_foc_parameters();
    switch name
        case 'negative',p.focCfg.Direction=-1;p.focCfg.SpeedReference=cfg.NegativeSpeed;p.focCfg.LoadTorque=cfg.NegativeLoad;
        case 'initial_opposite',p.pmsmCfg.Position0=cfg.InitialElectricalAngle/p.pmsmCfg.PolePairs;
        case 'high_inertia',p.pmsmCfg.J=p.pmsmCfg.J*cfg.InertiaFactor;
        case 'resistance_mismatch',p.pmsmCfg.Rs=p.pmsmCfg.Rs*cfg.ResistanceFactor;
        case 'lower_bus',p.inverterCfg.Vdc=cfg.LowBusVoltage;
        case 'observer_loss',p.experimentCfg.Duration=cfg.FaultCaseDuration;
        case 'current_alignment_baseline',p.focCfg.VoltageAlignmentEnable=0;
    end
    stimulus=sensorless_foc_stimulus(p);
    if strcmp(name,'observer_loss')
        stimulus.signals.values(round(cfg.ObserverLossTime/p.currentCfg.Ts)+1:end,6)=0;
    end
    fprintf('Running %s\n',name);
    r=run_sensorless_foc_case(p,stimulus);t=r.time;c=r.controller.trace;cc=r.controller.columns;
    plant=r.plant.trace;pc=r.plant.columns;obs=r.observer.trace;oc=r.observer.columns;
    act=r.actuation.trace;ac=r.actuation.columns;
    assert(numel(t)==round(p.experimentCfg.Duration/p.currentCfg.Ts)+1);
    assert(max(abs(diff(t)-p.currentCfg.Ts))<1e-12);
    assert(all(c(:,cc.beta)>=0 & c(:,cc.beta)<=1));
    assert(max(vecnorm(c(:,cc.reference),2,2))<=cfg.MaxCurrentReference+1e-10);
    assert(all(act(:,ac.duty_command)>=-1e-12 & act(:,ac.duty_command)<=1+1e-12,'all'));
    assert(all(act(:,ac.duty_applied)>=-1e-12 & act(:,ac.duty_applied)<=1+1e-12,'all'));
    automatic=c(:,cc.handover_mode)==4;fault=c(:,cc.handover_fault)>0;
    run=c(:,cc.run)>0.5;off=~run;
    assert(all(c(off,cc.reference)==0,'all') && all(c(off,cc.voltage_pi)==0,'all'));
    assert(all(act(off,ac.voltage_request)==0,'all'));
    autoIndex=find(automatic,1);faultIndex=find(fault,1);blendIndex=find(c(:,cc.handover_mode)==3,1);
    metric=struct('name',name,'passed',true,'auto_time_s',NaN,'fault_time_s',NaN, ...
        'final_speed_rad_s',plant(end,pc.speed_true),'angle_RMS_rad',NaN, ...
        'speed_RMS_mechanical_rad_s',NaN,'max_healthy_current_A',0,'max_voltage_step_during_blend_V',NaN);
    if ~isempty(autoIndex),metric.auto_time_s=t(autoIndex);end
    if ~isempty(faultIndex),metric.fault_time_s=t(faultIndex);end
    currentNorm=vecnorm(plant(:,[pc.id_true,pc.iq_true]),2,2);
    metric.max_healthy_current_A=max(currentNorm(run));
    assert(metric.max_healthy_current_A<cfg.MaxHealthyCurrent);
    if strcmp(name,'current_alignment_baseline')
        assert(isempty(autoIndex) && ~isempty(faultIndex) && all(c(:,cc.beta)==0));
        assert(c(faultIndex,cc.startup_fault)==1);
    else
        assert(~isempty(autoIndex) && ~isempty(blendIndex));
        assert(abs(wrap(c(blendIndex,cc.theta_used)-c(blendIndex,cc.theta_start)))<1e-10);
        assert(all(c(automatic,cc.beta)==1));
        if strcmp(name,'observer_loss')
            assert(~isempty(faultIndex));
            assert(abs(metric.fault_time_s-(cfg.ObserverLossTime+p.handoverCfg.Samples(3)*p.currentCfg.Ts))<p.currentCfg.Ts/4);
            assert(all(c(faultIndex:end,cc.run)==0));
            window=t>=cfg.ObserverLossTime-cfg.SteadyWindow & t<cfg.ObserverLossTime;
        else
            assert(isempty(faultIndex));window=t>=p.experimentCfg.Duration-cfg.SteadyWindow;
        end
        angleError=wrap(obs(:,oc.theta_hat)-plant(:,pc.theta_true));
        speedError=plant(:,pc.speed_true)-c(:,cc.speed_reference);
        metric.angle_RMS_rad=sqrt(mean(angleError(window).^2));
        metric.speed_RMS_mechanical_rad_s=sqrt(mean(speedError(window).^2));
        assert(metric.angle_RMS_rad<cfg.MaxAngleRms && metric.speed_RMS_mechanical_rad_s<cfg.MaxSpeedError);
        assert(mean(obs(window,oc.valid)>0.5)>0.95);
        % Rotate the actual reference to physical alpha/beta and compare the
        % two independently rotated source vectors with the same beta.
        actual=toPhysical(c(:,cc.reference),c(:,cc.theta_used));
        start=toPhysical(c(:,[cc.id_start,cc.iq_start]),c(:,cc.theta_start));
        closed=toPhysical([zeros(size(t)),c(:,cc.iq_closed)],c(:,cc.theta_used));
        expected=(1-c(:,cc.beta)).*start+c(:,cc.beta).*closed;expected(off,:)=0;
        assert(max(abs(actual-expected),[],'all')<1e-10);
        extra=wrap(diff(c(:,cc.theta_used))-p.currentCfg.Ts*c(1:end-1,cc.omega_base));
        assert(max(abs(wrap(extra-c(2:end,cc.delta_extra))))<1e-10);
        physicalVoltage=toPhysical(act(:,ac.voltage_request),act(:,ac.theta_control));
        transition=c(2:end,cc.handover_mode)==3 & c(1:end-1,cc.handover_mode)==3;
        steps=vecnorm(diff(physicalVoltage),2,2);
        metric.max_voltage_step_during_blend_V=max(steps(transition));
        assert(metric.max_voltage_step_during_blend_V<2);
    end
    % The baseline deliberately has zero feedback-age; prove the observer
    % actually receives the physical current and final applied phase voltage.
    assert(p.timingCfg.FeedbackTicks==0);
    phaseCurrent=plant(:,pc.phase_current);phaseVoltage=act(:,ac.phase_voltage);
    assert(max(abs(obs(:,oc.current_ab)-clarke(phaseCurrent)),[],'all')<1e-10);
    assert(max(abs(obs(:,oc.observer_voltage)-clarke(phaseVoltage)),[],'all')<1e-10);
    records.(name)=r;metrics{test}=metric;
    fprintf('%s: PASS, AUTO %.6g s, final speed %.6g rad/s\n',name,metric.auto_time_s,metric.final_speed_rad_s);
end
metrics=[metrics{:}];report=struct('release',version('-release'),'passed',all([metrics.passed]), ...
    'case_count',numel(names),'cases',metrics,'position_sensor_used_in_control',false,'hardware_tested',false);
save(fullfile(module,'waveform_analysis','results.mat'),'records','report','-v7.3');
file=fopen(fullfile(module,'waveform_analysis','metrics.json'),'w');
cleanup=onCleanup(@()fclose(file));fwrite(file,jsonencode(report,PrettyPrint=true));clear cleanup
for name={'positive','negative','observer_loss','current_alignment_baseline'}
    if isfield(records,name{1}),plotCase(records.(name{1}),name{1},module);end
end
disp(report);
end
function result=wrap(value)
result=atan2(sin(value),cos(value));
end
function output=toPhysical(input,angle)
output=[cos(angle).*input(:,1)-sin(angle).*input(:,2),sin(angle).*input(:,1)+cos(angle).*input(:,2)];
end
function output=clarke(input)
output=[(2*input(:,1)-input(:,2)-input(:,3))/3,(input(:,2)-input(:,3))/sqrt(3)];
end
function plotCase(r,name,module)
figureHandle=figure('Visible','off','Position',[100,100,1100,1050]);
cleanup=onCleanup(@()close(figureHandle));tiledlayout(5,1);t=r.time;c=r.controller.trace;cc=r.controller.columns;
plant=r.plant.trace;pc=r.plant.columns;obs=r.observer.trace;oc=r.observer.columns;
nexttile;plot(t,[plant(:,pc.speed_true),obs(:,oc.omega_hat)/r.parameters.pmsmCfg.PolePairs,c(:,cc.speed_reference)]);
ylabel('mechanical rad/s');legend('plant','estimate','request');grid on
nexttile;plot(t,wrap(obs(:,oc.theta_hat)-plant(:,pc.theta_true)));ylabel('angle error (rad)');grid on
nexttile;plot(t,[c(:,cc.reference),c(:,cc.control_current)]);ylabel('control-frame A');legend('d ref','q ref','d measured','q measured');grid on
nexttile;plot(t,[plant(:,pc.torque_true),c(:,cc.torque_request)]);ylabel('torque (N m)');legend('plant','request');grid on
nexttile;plot(t,[c(:,cc.beta),c(:,cc.handover_mode),c(:,cc.handover_fault)]);ylabel('weight / mode');legend('beta','mode','fault');xlabel('time (s)');grid on
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.png']));
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.svg']),ContentType='vector');
end
