function p=sensorless_fw_parameters()
%SENSORLESS_FW_PARAMETERS Executable IPMSM EEMF/MTPA/FW MIL configuration.
% All values are SI; the motor is a synthetic fixture, not board identification.
module=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(fileparts(fileparts(fileparts(module))));
entry=fullfile(project,'docs','scripts','initialize_motor_paths.m');
if ~isfile(entry)
    entry=which('initialize_motor_paths');assert(~isempty(entry),'Initialize the engineering project paths first.');
    project=fileparts(fileparts(fileparts(entry)));
end
addpath(fullfile(project,'docs','scripts'));initialize_motor_paths();
base=fullfile(project,'model','app_models','Sensorless','sensorless_foc');
addpath(fullfile(base,'parameter'),fullfile(base,'build_process'),fullfile(base,'waveform_analysis'));
p=observer_foc_parameters('eemf');
% Restore the independently configured salient motor (the common App is SPMSM).
p.pmsmCfg.Lq=1.2e-3;
p.currentCfg=current_parameters(p.pmsmCfg);p.currentCfg.Ts=50e-6;
p.currentCfg.Kaw=1/p.currentCfg.Ts;
p.inverterCfg.PwmTs=p.currentCfg.Ts;
p.motionCfg.SpeedLimit=260;
speed=p.refCfg;
p.refCfg=mtpa_fw_parameters(p.pmsmCfg,p.inverterCfg,p.motionCfg);
for field={'SpeedTs','SpeedKp','SpeedKi','SpeedKaw'},p.refCfg.(field{1})=speed.(field{1});end
p.emfCfg.Ld=p.pmsmCfg.Ld;p.emfCfg.Lq=p.pmsmCfg.Lq;
p.emfCfg.Rs=p.pmsmCfg.Rs;p.emfCfg.Flux=p.pmsmCfg.Flux;
p.focCfg.SpeedReference=210;
p.experimentCfg.Duration=2.2;
p.fwCfg=struct('BusTimes',0,'BusValues',48);
p.startGuardCfg=struct('Enable',1,'ObserveTime',0.05,'MaxStartEmf',0.25);
p.bridgeCfg=pmsm_bridge_parameters();
p=refresh_sensorless_fw_parameters(p);
end
