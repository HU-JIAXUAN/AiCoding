function results=run_bridge_bus_validation(outputFolder)
%RUN_BRIDGE_BUS_VALIDATION Dynamic DC rail, electrical invariants and refusals.
if nargin<1,outputFolder=fileparts(mfilename('fullpath'));end
assert(isfolder(outputFolder));results=struct();
p=bridge_bus_test_parameters();
r=run_bridge_bus_case(p);verifyCircuit(r);verifyStateContinuity(r);
bus=r.stimulus.signals.values(:,6);duty=p.bridgeTestCfg.Duty;
expected=[(2/3)*(duty(1)-0.5*duty(2)-0.5*duty(3))*bus, ...
    (sqrt(3)/3)*(duty(2)-duty(3))*bus];
voltageError=max(abs(r.trace(:,r.columns.voltage_ab)-expected),[],'all');
assert(voltageError<1e-11);
results.pwm_bus_steps=struct('passed',true,'voltage_error_V',voltageError, ...
    'phase_peak_A',max(abs(r.trace(:,r.columns.phase_current)),[],'all'));
save(fullfile(outputFolder,'bus_pwm_steps.mat'),'r');

for voltage=[48,36]
    q=p;q.bridgeCfg.Vdc=voltage;q.bridgeCfg=refresh_pmsm_bridge_parameters(q.bridgeCfg);
    q.bridgeTestCfg.BusTimes=0;q.bridgeTestCfg.BusValues=voltage;
    dynamic=run_bridge_bus_case(q);reference=run_bridge_case(q);
    assert(isequal(dynamic.time,reference.time));
    newValues=dynamic.trace(:,7:end);oldValues=reference.trace(:,6:end);
    error=max(abs(newValues-oldValues),[],'all');
    relative=max(abs(newValues-oldValues)./max(1,abs(oldValues)),[],'all');
    assert(relative<1e-10);
    results.(sprintf('constant_%dV',voltage))=struct('passed',true, ...
        'max_absolute_numeric_difference',error,'max_scaled_difference',relative, ...
        'compared_values',numel(oldValues));
    save(fullfile(outputFolder,sprintf('constant_%dV.mat',voltage)),'dynamic','reference');
end

q=p;q.bridgeCfg.Speed0=150;q.bridgeCfg.MechanicalEnabled=0;
q.bridgeCfg=refresh_pmsm_bridge_parameters(q.bridgeCfg);
q.bridgeTestCfg.ModeTimes=0;q.bridgeTestCfg.ModeValues=0;
q.bridgeTestCfg.Duration=0.03;q.bridgeTestCfg.BusTimes=[0,.01,.02];
q.bridgeTestCfg.BusValues=[48,24,48];
r=run_bridge_bus_case(q);verifyCircuit(r);verifyStateContinuity(r);
c=r.columns;before=r.time<.01-q.bridgeCfg.Ts/2;
assert(max(abs(r.trace(before,c.phase_current)),[],'all')<1e-8);
assert(min(r.trace(:,c.dc_current))<-.1);
peak=max(abs(r.trace(:,c.phase_current)),[],'all');assert(peak>1);
stepIndex=round(.01/q.bridgeCfg.Ts)+1;
recoveryIndex=round(.02/q.bridgeCfg.Ts)+1;
assert(max(abs(r.trace(stepIndex,c.phase_current)))<1e-8);
assert(max(abs(r.trace(stepIndex,c.next_phase_current)))>0);
assert(max(abs(r.trace(recoveryIndex,c.phase_current)))>.1);
returned=-q.bridgeCfg.Ts*sum(min(r.stimulus.signals.values(1:end-1,6).*r.trace(1:end-1,c.dc_current),0));
assert(returned>0);
results.off_bus_steps=struct('passed',true,'phase_peak_A',peak,'returned_bus_energy_J',returned, ...
    'externally_held_speed_rad_per_s',150);
save(fullfile(outputFolder,'bus_off_rectification.mat'),'r');

q=p;q.bridgeCfg.Speed0=80;q.bridgeCfg=refresh_pmsm_bridge_parameters(q.bridgeCfg);
q.bridgeTestCfg.ModeTimes=0;q.bridgeTestCfg.ModeValues=2;
r=run_bridge_bus_case(q);verifyCircuit(r);verifyStateContinuity(r);
assert(max(abs(r.trace(:,r.columns.voltage_ab)),[],'all')<1e-12);
assert(max(abs(r.trace(:,r.columns.dc_current)))<1e-12);
q.bridgeTestCfg.BusTimes=0;q.bridgeTestCfg.BusValues=48;
constant=run_bridge_bus_case(q);
error=max(abs(r.trace(:,7:end)-constant.trace(:,7:end)),[],'all');assert(error<1e-11);
results.short_bus_steps=struct('passed',true,'physical_trace_difference',error);
save(fullfile(outputFolder,'bus_active_short.mat'),'r','constant');

% A passive bus is prescribed, with no capacitor/rectifier-source dynamics.
% Check energy accounting improves when the physical step is halved.
q=p;coarse=run_bridge_bus_case(q);coarseDefect=energyDefect(coarse);
q.bridgeCfg.Ts=q.bridgeCfg.Ts/2;q.bridgeCfg=refresh_pmsm_bridge_parameters(q.bridgeCfg);
fine=run_bridge_bus_case(q);fineDefect=energyDefect(fine);
assert(fineDefect<.75*coarseDefect+1e-8);
results.energy_refinement=struct('passed',true,'coarse_defect_J',coarseDefect, ...
    'fine_defect_J',fineDefect,'ratio',fineDefect/max(coarseDefect,eps));
save(fullfile(outputFolder,'bus_energy_refinement.mat'),'coarse','fine');

badValues=[0,-24,NaN,Inf];labels={'zero','negative','nan','inf'};
q=p;q.bridgeTestCfg.Duration=2*q.bridgeCfg.Ts;
q.bridgeTestCfg.BusTimes=0;q.bridgeTestCfg.BusValues=48;
validStim=bridge_bus_stimulus(q);model='PMSMBridgeBusPlantTest';load_system(model);
for k=1:numel(badValues)
    invalid=validStim;invalid.signals.values(:,6)=badValues(k);
    in=Simulink.SimulationInput(model);
    in=in.setVariable('bridgeCfg',q.bridgeCfg,'Workspace',model);
    in=in.setVariable('bridgeTestCfg',q.bridgeTestCfg,'Workspace',model);
    in=in.setVariable('bridgeBusStim',invalid,'Workspace',model);
    rejected=false;message='';
    try,sim(in);catch exception,rejected=true;message=exception.message;end
    assert(rejected,'Invalid bus must not simulate successfully.');
    results.(['refuse_',labels{k}])=struct('passed',true,'message',message);
end
close_system(model,0);
names=fieldnames(results);assert(numel(names)==10);
report=struct('release',version('-release'),'status','passed','model_cases',10,'results',results);
fid=fopen(fullfile(outputFolder,'bus_results.json'),'w');assert(fid>=0);
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
disp('BRIDGE_BUS_VALIDATION_PASSED_10_CASES');
end
function verifyCircuit(r)
c=r.columns;bus=r.stimulus.signals.values(:,6);
power=bus.*r.trace(:,c.dc_current);
terminal=sum(r.trace(:,c.phase_voltage).*r.trace(:,c.next_phase_current),2);
error=max(abs(power-terminal-r.trace(:,c.bridge_loss)));
assert(error<1e-8*max(1,max(abs(power))));
assert(max(abs(sum(r.trace(:,c.phase_current),2)))<1e-10);
assert(max(abs(r.trace(:,c.equation_residual)))<1e-5);
end
function verifyStateContinuity(r)
c=r.columns;
error=max(abs(r.trace(2:end,c.phase_current)-r.trace(1:end-1,c.next_phase_current)),[],'all');
assert(error<1e-11);
end
function defect=energyDefect(r)
c=r.columns;cfg=r.parameters.bridgeCfg;h=cfg.Ts;index=1:numel(r.time)-1;
power=r.stimulus.signals.values(index,6).*r.trace(index,c.dc_current);
copper=1.5*cfg.Rs*sum(r.trace(index,c.next_phase_current).^2,2)*(2/3);
speed=r.trace(index,c.speed_mechanical);
loss=r.trace(index,c.bridge_loss)+copper+cfg.B*speed.^2+ ...
    r.stimulus.signals.values(index,5).*speed;
energy=r.trace(:,c.magnetic_energy)+r.trace(:,c.kinetic_energy);
defect=abs(energy(end)-energy(1)-h*sum(power-loss));
end
