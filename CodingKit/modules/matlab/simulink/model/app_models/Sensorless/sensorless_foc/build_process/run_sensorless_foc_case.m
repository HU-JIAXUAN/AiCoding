function record=run_sensorless_foc_case(parameters,stimulus)
%RUN_SENSORLESS_FOC_CASE Simulate an App using explicit local M-file configuration.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'waveform_analysis'));
if nargin<1 || isempty(parameters),parameters=sensorless_foc_parameters();end
p=parameters;
assert(p.pmsmCfg.Ld==p.pmsmCfg.Lq,'This App currently uses the basic SPMSM SMO.');
assert(p.pmsmCfg.Rs>0 && p.pmsmCfg.J>0 && p.pmsmCfg.B>=0);
assert(p.inverterCfg.Vdc>0 && p.currentCfg.Ts>0 && p.refCfg.SpeedKaw>0);
assert(abs(p.timingCfg.Ts-p.currentCfg.Ts)<1e-12 && abs(p.smoCfg.Ts-p.currentCfg.Ts)<1e-12);
assert(abs(p.pllCfg.Ts-p.currentCfg.Ts)<1e-12 && abs(p.startupCfg.Ts-p.currentCfg.Ts)<1e-12 && abs(p.handoverCfg.Ts-p.currentCfg.Ts)<1e-12);
assert(abs(p.refCfg.SpeedTs/p.currentCfg.Ts-round(p.refCfg.SpeedTs/p.currentCfg.Ts))<1e-9);
assert(abs(p.currentCfg.Ts/p.experimentCfg.Step-round(p.currentCfg.Ts/p.experimentCfg.Step))<1e-9);
assert(p.currentCfg.Kaw>=0 && (p.focCfg.VoltageAlignmentEnable==0 || p.currentCfg.Kaw>0));
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.smoCfg=refresh_smo_parameters(p.smoCfg);
p.startupCfg=refresh_startup_parameters(p.startupCfg);
p.handoverCfg=refresh_handover_parameters(p.handoverCfg);
if nargin<2 || isempty(stimulus),stimulus=sensorless_foc_stimulus(p);end
assert(size(stimulus.signals.values,2)==6 && all(isfinite(stimulus.signals.values),'all'));
assert(numel(stimulus.time)==round(p.experimentCfg.Duration/p.currentCfg.Ts)+1);
model='SensorlessFOC';if ~bdIsLoaded(model),open_system(fullfile(module,'src',[model,'.slx']));end
input=Simulink.SimulationInput(model);names=fieldnames(p);
for index=1:numel(names),input=input.setVariable(names{index},p.(names{index}),'Workspace',model);end
input=input.setVariable('testStim',stimulus,'Workspace',model);
timer=tic;output=sim(input);wallTime=toc(timer);
record=read_sensorless_foc_result(output,p);record.wall_time_s=wallTime;
assert(isequal(record.actuation.trace(:,record.actuation.columns.stimulus),stimulus.signals.values));
record.stimulus=stimulus;
end
