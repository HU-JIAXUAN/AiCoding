function stimulus=hfi_stimulus(cfg)
%HFI_STIMULUS Exact-grid load/scale/enable/reset and independent phase noise.
time=(0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;
stream=RandStream('mt19937ar','Seed',cfg.NoiseSeed);
noise=cfg.MeasurementNoise*randn(stream,numel(time),3);
stimulus.time=time;
stimulus.signals.values=[repmat([cfg.LoadTorque,cfg.InjectionScale,cfg.Enable,cfg.Reset],numel(time),1),noise];
stimulus.signals.dimensions=7;
end
