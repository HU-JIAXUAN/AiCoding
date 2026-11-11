function record=run_observer_foc_case(kind,p,stimulus)
%RUN_OBSERVER_FOC_CASE Run an EMF/flux physical closed loop without editors.
kind=char(validatestring(kind,{'eemf','flux'}));
if nargin<2 || isempty(p),p=observer_foc_parameters(kind);end
if nargin<3,stimulus=sensorless_foc_stimulus(p);end
assert(p.pmsmCfg.Ld==p.pmsmCfg.Lq,'The common comparison fixture is SPMSM.');
assert(p.pmsmCfg.Rs>0 && p.pmsmCfg.J>0 && p.pmsmCfg.B>=0);
assert(p.inverterCfg.Vdc>0 && p.currentCfg.Ts>0 && p.refCfg.SpeedKaw>0);
periods=[p.timingCfg.Ts,p.pllCfg.Ts,p.startupCfg.Ts,p.handoverCfg.Ts];
if strcmp(kind,'eemf')
    model='EemfSensorlessFOC';periods(end+1)=p.emfCfg.Ts;
else
    model='FluxSensorlessFOC';p.fluxCfg=refresh_flux_parameters(p.fluxCfg);periods(end+1)=p.fluxCfg.Ts;
end
assert(all(abs(periods-p.currentCfg.Ts)<eps(p.currentCfg.Ts)));
assert(abs(p.refCfg.SpeedTs/p.currentCfg.Ts-round(p.refCfg.SpeedTs/p.currentCfg.Ts))<1e-10);
assert(abs(p.currentCfg.Ts/p.experimentCfg.Step-round(p.currentCfg.Ts/p.experimentCfg.Step))<1e-10);
assert(p.currentCfg.Kaw>=0 && (~p.focCfg.VoltageAlignmentEnable || p.currentCfg.Kaw>0));
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.startupCfg=refresh_startup_parameters(p.startupCfg);
p.handoverCfg=refresh_handover_parameters(p.handoverCfg);
assert(size(stimulus.signals.values,2)==6 && all(isfinite(stimulus.signals.values),'all'));
assert(numel(stimulus.time)==round(p.experimentCfg.Duration/p.currentCfg.Ts)+1);
module=fileparts(fileparts(mfilename('fullpath')));
alreadyLoaded=bdIsLoaded(model);
if ~alreadyLoaded,load_system(fullfile(module,'src',[model,'.slx']));end
cleanup=onCleanup(@()finishModel(model,alreadyLoaded));
input=Simulink.SimulationInput(model);names=fieldnames(p);
for k=1:numel(names),input=input.setVariable(names{k},p.(names{k}),'Workspace',model);end
input=input.setVariable('testStim',stimulus,'Workspace',model);
clock=tic;output=sim(input);elapsed=toc(clock);
try
    record=read_observer_foc_result(output,p,kind);
catch exception
    save(fullfile(module,'waveform_analysis',[kind,'_failed_output.mat']),'output','p','stimulus','-v7.3');
    rethrow(exception);
end
record.host_seconds=elapsed;
record.stimulus=stimulus;
assert(isequal(record.actuation.trace(:,record.actuation.columns.stimulus),stimulus.signals.values));
end
function finishModel(model,alreadyLoaded)
if ~alreadyLoaded && bdIsLoaded(model),close_system(model,0);end
end
