function report=run_bridge_kernel_checks()
%RUN_BRIDGE_KERNEL_CHECKS Independent circuit, recurrence and energy checks.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'));
rows={};base=pmsm_bridge_parameters();base.MechanicalEnabled=0;
base.Id0=1;base.Iq0=3;base.Position0=0.2;base=refresh_pmsm_bridge_parameters(base);
duty=[0.65;0.4;0.45];state=base.State0;angle=base.PolePairs*state(4);
rotation=[cos(angle),-sin(angle);sin(angle),cos(angle)];
voltage=base.Vdc*[(2*duty(1)-duty(2)-duty(3))/3;(duty(2)-duty(3))/sqrt(3)];
expected=rotation'*state(1:2);rotorVoltage=rotation'*voltage;
maxError=0;
for k=1:40
    state=pmsm_bridge_step(state,duty,1,0,base.Vector);
    expected=([base.Ld;base.Lq].*expected+base.Ts*rotorVoltage)./([base.Ld;base.Lq]+base.Ts*base.Rs);
    maxError=max(maxError,max(abs(state(1:2)-rotation*expected)));
end
assert(maxError<1e-12);rows{end+1}=row('locked_rotor_PWM_backward_Euler',struct('max_current_difference_A',maxError));
state=base.State0;expected=rotation'*state(1:2);maxError=0;
for k=1:40
    state=pmsm_bridge_step(state,zeros(3,1),2,0,base.Vector);
    expected=([base.Ld;base.Lq].*expected)./([base.Ld;base.Lq]+base.Ts*base.Rs);
    maxError=max(maxError,max(abs(state(1:2)-rotation*expected)));
end
assert(maxError<1e-12);rows{end+1}=row('locked_rotor_active_short_RL',struct('max_current_difference_A',maxError));

cfg=base;cfg.Id0=0;cfg.Iq0=0;cfg.Speed0=80;cfg=refresh_pmsm_bridge_parameters(cfg);state=cfg.State0;
maxVoltageError=0;
for k=1:400
    old=state;[state,u,~,dc,diodes]=pmsm_bridge_step(state,NaN(3,1),0,0,cfg.Vector);
    first=cfg.PolePairs*old(4);last=cfg.PolePairs*state(4);
    expected=cfg.Flux*[cos(last)-cos(first);sin(last)-sin(first)]/cfg.Ts;
    maxVoltageError=max(maxVoltageError,max(abs(u-expected)));
    assert(all(state(1:2)==0) && dc==0 && all(diodes==0));
end
voltageRoundoffBound=64*eps(cfg.Flux)/cfg.Ts;
fprintf('Open EMF difference %.12g V; floating subtraction bound %.12g V\n',maxVoltageError,voltageRoundoffBound);
assert(maxVoltageError<voltageRoundoffBound);
rows{end+1}=row('high_impedance_open_EMF',struct('max_interval_voltage_difference_V',maxVoltageError, ...
    'floating_subtraction_bound_V',voltageRoundoffBound,'disabled_duty_ignored',true));

cfg.MechanicalEnabled=1;cfg=refresh_pmsm_bridge_parameters(cfg);state=cfg.State0;count=2000;
for k=1:count,state=pmsm_bridge_step(state,zeros(3,1),0,0,cfg.Vector);end
speedError=abs(state(3)-cfg.Speed0*(1-cfg.Ts*cfg.B/cfg.J)^count);
assert(speedError<1e-9 && all(state(1:2)==0));
rows{end+1}=row('free_coast_viscous_speed',struct('speed_difference_rad_s',speedError));

cfg=base;cfg.Speed0=80;cfg.MechanicalEnabled=1;cfg=refresh_pmsm_bridge_parameters(cfg);state=cfg.State0;
[first,~,~,dc]=pmsm_bridge_step(state,zeros(3,1),0,0,cfg.Vector);
assert(norm(first(1:2))>0 && norm(first(1:2))<norm(state(1:2)) && dc<0);
peakOff=norm(state(1:2));returned=0;diodeLoss=0;
for k=1:2000
    [state,~,~,dc,~,loss]=pmsm_bridge_step(state,zeros(3,1),0,0,cfg.Vector);
    assert(dc<=1e-9);returned=returned-cfg.Ts*cfg.Vdc*dc;diodeLoss=diodeLoss+cfg.Ts*loss;
    peakOff=max(peakOff,norm(state(1:2)));
end
assert(norm(state(1:2))==0 && returned>0 && diodeLoss>0);
rows{end+1}=row('turn_off_current_continuity_and_decay',struct('first_next_current_norm_A',norm(first(1:2)), ...
    'initial_current_norm_A',norm(cfg.State0(1:2)),'peak_off_current_A',peakOff,'returned_energy_J',returned,'diode_loss_J',diodeLoss));

cfg=base;cfg.Id0=0;cfg.Iq0=0;cfg.Speed0=80;cfg.MechanicalEnabled=1;cfg=refresh_pmsm_bridge_parameters(cfg);
state=cfg.State0;peakShort=0;
for k=1:2000,state=pmsm_bridge_step(state,zeros(3,1),2,0,cfg.Vector);peakShort=max(peakShort,norm(state(1:2)));end
assert(peakShort>8 && state(3)<cfg.Speed0);
rows{end+1}=row('active_short_is_not_coast',struct('peak_current_A',peakShort,'final_speed_rad_s',state(3)));

for direction=[1,-1]
    cfg=base;cfg.Id0=0;cfg.Iq0=0;cfg.Speed0=direction*400;cfg.MechanicalEnabled=0;
    cfg=refresh_pmsm_bridge_parameters(cfg);state=cfg.State0;generated=0;worstPower=0;peak=0;
    for k=1:1200
        [state,u,~,dc,~,loss,~,nextI]=pmsm_bridge_step(state,zeros(3,1),0,0,cfg.Vector);
        nextAB=[(2*nextI(1)-nextI(2)-nextI(3))/3;(nextI(2)-nextI(3))/sqrt(3)];
        worstPower=max(worstPower,abs(cfg.Vdc*dc-1.5*dot(u,nextAB)-loss));
        generated=generated-cfg.Vdc*dc*cfg.Ts;peak=max(peak,norm(state(1:2)));
        assert(dc<=1e-9);
    end
    assert(generated>0.1 && peak>1 && worstPower<1e-8);
    rows{end+1}=row(sprintf('uncontrolled_rectification_direction_%+d',direction), ...
        struct('returned_energy_J',generated,'peak_current_A',peak,'max_bridge_power_balance_W',worstPower));
end

stream=RandStream('mt19937ar','Seed',741);
cfg=base;cfg.Lq=cfg.Ld;cfg=refresh_pmsm_bridge_parameters(cfg);worst=0;
for k=1:240
    state=[40*(rand(stream,2,1)-0.5);600*(rand(stream)-0.5);8*(rand(stream)-0.5)];
    next=pmsm_bridge_step(state,zeros(3,1),0,0,cfg.Vector);
    reference=independentSpmsmOff(state,cfg);
    worst=max(worst,max(abs(next(1:2)-reference)));
end
assert(worst<1e-10);
rows{end+1}=row('SPMSM_independent_neutral_bisection',struct('points',240,'max_current_difference_A',worst));

worstFlux=0;worstPower=0;worstKcl=0;
for k=1:240
    cfg=base;cfg.Lq=cfg.Ld*(0.5+1.5*rand(stream));cfg=refresh_pmsm_bridge_parameters(cfg);
    state=[40*(rand(stream,2,1)-0.5);600*(rand(stream)-0.5);8*(rand(stream)-0.5)];
    [~,u,phaseV,dc,diodes,loss,residual,nextI,neutral,poles]=pmsm_bridge_step(state,zeros(3,1),0,0,cfg.Vector);
    worstFlux=max(worstFlux,residual);worstKcl=max(worstKcl,abs(sum(nextI)));
    worstPower=max(worstPower,abs(cfg.Vdc*dc-dot(phaseV,nextI)-loss));
    assert(max(abs(poles-phaseV-neutral))<1e-8 && dc<=1e-9);
    for phase=1:3
        if diodes(phase)>0
            assert(nextI(phase)>=-cfg.CurrentTolerance && abs(poles(phase)+cfg.DiodeVf+cfg.DiodeRon*nextI(phase))<1e-8);
        elseif diodes(phase)<0
            assert(nextI(phase)<=cfg.CurrentTolerance && abs(poles(phase)-cfg.Vdc-cfg.DiodeVf+cfg.DiodeRon*nextI(phase))<1e-8);
        else
            assert(abs(nextI(phase))<=cfg.CurrentTolerance && poles(phase)>=-cfg.DiodeVf-cfg.VoltageTolerance && poles(phase)<=cfg.Vdc+cfg.DiodeVf+cfg.VoltageTolerance);
        end
    end
    assert(all(isfinite(u)));
end
assert(worstFlux<1e-8 && worstPower<1e-8 && worstKcl<1e-12);
rows{end+1}=row('IPMSM_complementarity_KCL_KVL_power',struct('points',240,'max_flux_balance_V',worstFlux, ...
    'max_bridge_power_balance_W',worstPower,'max_KCL_A',worstKcl));

cfg=base;state=cfg.State0;[~,~,~,~,~,before]=pmsm_bridge_output(state,cfg.Vector);
for mode=0:2
    [next,u,~,dc,~,loss]=pmsm_bridge_step(state,duty,mode,0,cfg.Vector);
    [~,~,~,~,~,after]=pmsm_bridge_output(next,cfg.Vector);
    delta=next(1:2)-state(1:2);coenergy=0.75*delta'*(rotation*diag([cfg.Ld,cfg.Lq])*rotation')*delta;
    copper=1.5*cfg.Rs*dot(next(1:2),next(1:2));
    error=after-before-cfg.Ts*(cfg.Vdc*dc-copper-loss)+coenergy;
    assert(abs(error)<1e-12 && abs(cfg.Vdc*dc-1.5*dot(u,next(1:2))-loss)<1e-8);
end
rows{end+1}=row('locked_rotor_discrete_energy_identity',struct('max_accepted_residual_J',1e-12));

cfg=base;cfg.Id0=1;cfg.Iq0=3;cfg.Speed0=80;cfg.MechanicalEnabled=1;cfg.B=0;
defects=zeros(1,3);
for refinement=1:3
    cfg.Ts=5e-6/2^(refinement-1);cfg=refresh_pmsm_bridge_parameters(cfg);
    state=cfg.State0;[~,~,~,~,~,wm,wk]=pmsm_bridge_output(state,cfg.Vector);initial=wm+wk;work=0;
    for k=1:round(0.01/cfg.Ts)
        speed=state(3);[state,~,~,dc,~,loss]=pmsm_bridge_step(state,zeros(3,1),0,0.1,cfg.Vector);
        copper=1.5*cfg.Rs*dot(state(1:2),state(1:2));
        work=work+cfg.Ts*(cfg.Vdc*dc-copper-loss-0.1*speed);
    end
    [~,~,~,~,~,wm,wk]=pmsm_bridge_output(state,cfg.Vector);defects(refinement)=wm+wk-initial-work;
end
ratios=abs(defects(1:2)./defects(2:3));assert(all(ratios>1.5 & ratios<3));
rows{end+1}=row('free_rotor_energy_step_refinement',struct('steps_s',[5e-6,2.5e-6,1.25e-6],'energy_defect_J',defects,'ratios',ratios));

cfg=base;rejected=false;
try,pmsm_bridge_step(cfg.State0,duty,3,0,cfg.Vector);catch,rejected=true;end
assert(rejected);rows{end+1}=row('invalid_bridge_mode_rejected',struct());
rejected=false;try,pmsm_bridge_step(cfg.State0,NaN(3,1),1,0,cfg.Vector);catch,rejected=true;end
assert(rejected);rows{end+1}=row('invalid_active_duty_rejected',struct());
bad=cfg;bad.Ld=-1;rejected=false;try,refresh_pmsm_bridge_parameters(bad);catch,rejected=true;end
assert(rejected);rows{end+1}=row('invalid_physics_configuration_rejected',struct());
badState=cfg.State0;badState(3)=cfg.MaxSpeed*2;rejected=false;
try,pmsm_bridge_step(badState,duty,0,0,cfg.Vector);catch,rejected=true;end
assert(rejected);rows{end+1}=row('out_of_range_state_rejected',struct());
typed=base;typed.PolePairs=uint8(base.PolePairs);typed.Id0=int16(base.Id0);typed.Iq0=int16(base.Iq0);
typed=refresh_pmsm_bridge_parameters(typed);
assert(isa(typed.PolePairs,'double') && isa(typed.Id0,'double') && isequal(typed.State0,base.State0));
rows{end+1}=row('numeric_parameter_types_normalized',struct('initial_state_identical',true));
bad=base;bad.Id0=[1;2];rejected=false;
try,refresh_pmsm_bridge_parameters(bad);catch,rejected=true;end
assert(rejected);rows{end+1}=row('non_scalar_initial_state_rejected',struct());
report=struct('release',version('-release'),'passed',true,'checks',numel(rows),'cases',vertcat(rows{:}), ...
    'independent_SPMSM_points',240,'IPMSM_KKT_points',240,'Simscape_reference_executed',false,'hardware_tested',false);
save(fullfile(module,'waveform_analysis','bridge_kernel_checks.mat'),'report');
fid=fopen(fullfile(module,'waveform_analysis','bridge_kernel_checks.json'),'w');cleanup=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(report,PrettyPrint=true));disp(report);
end
function value=row(name,details)
value=struct('name',name,'passed',true,'details',details);
end
function current=independentSpmsmOff(state,cfg)
% Independent scalar-phase circuit + monotone neutral-voltage bisection.
angle=cfg.PolePairs*state(4);future=angle+cfg.PolePairs*state(3)*cfg.Ts;
forcing=cfg.Ld*state(1:2)+cfg.Flux*[cos(angle)-cos(future);sin(angle)-sin(future)];
transform=[1,0;-0.5,sqrt(3)/2;-0.5,-sqrt(3)/2];source=transform*forcing/cfg.Ts;
impedance=cfg.Ld/cfg.Ts+cfg.Rs+cfg.DiodeRon;
low=min(source)-cfg.DiodeVf-1;high=max(source)+cfg.Vdc+cfg.DiodeVf+1;
phase=zeros(3,1);
for iteration=1:100
    neutral=(low+high)/2;drive=source-neutral;
    phase=max(0,drive-cfg.DiodeVf)/impedance+min(0,drive+cfg.Vdc+cfg.DiodeVf)/impedance;
    if sum(phase)>0,low=neutral;else,high=neutral;end
end
current=[(2*phase(1)-phase(2)-phase(3))/3;(phase(2)-phase(3))/sqrt(3)];
end
