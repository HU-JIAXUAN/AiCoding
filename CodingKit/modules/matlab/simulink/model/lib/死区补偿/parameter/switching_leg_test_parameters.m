function cfg=switching_leg_test_parameters()
%SWITCHING_LEG_TEST_PARAMETERS Editable switching fixture; timing from module defaults.
deadtime=deadtime_parameters();inverter=inverter_parameters();
cfg.Ts=deadtime.SwitchingStep;cfg.Duration=0.001;cfg.SolverStep=cfg.Ts;
cfg.Duty=0.5;cfg.Current=3;cfg.PwmPeriod=inverter.PwmTs;
sample=(0:round(cfg.Duration/cfg.Ts))';period=round(cfg.PwmPeriod/cfg.Ts);
assert(period>0 && cfg.Duty>=0 && cfg.Duty<=1);
cfg.Inputs=[double(mod(sample,period)<period*cfg.Duty),cfg.Current*ones(size(sample))];
end
