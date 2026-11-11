function stimulus=hfi_startup_stimulus(cfg)
%HFI_STARTUP_STIMULUS Load, enable, reset, three phase noise and quality gate.
time=(0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;
stream=RandStream('mt19937ar','Seed',cfg.NoiseSeed);
stimulus.time=time;stimulus.signals.values=[repmat([cfg.LoadTorque,cfg.Enable,cfg.Reset],numel(time),1), ...
    cfg.MeasurementNoise*randn(stream,numel(time),3),repmat(cfg.QualificationGate,numel(time),1)];
stimulus.signals.dimensions=7;
end
