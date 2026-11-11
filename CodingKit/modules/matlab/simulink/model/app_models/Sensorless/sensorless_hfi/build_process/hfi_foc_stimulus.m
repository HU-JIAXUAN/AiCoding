function stimulus=hfi_foc_stimulus(cfg)
%HFI_FOC_STIMULUS Exact Ts grid: load,enable,reset,noiseABC,quality,speed,torque,mode.
stimulus=hfi_startup_stimulus(cfg);time=stimulus.time;
stimulus.signals.values(time<cfg.LoadTime,1)=0;
speed=repmat(cfg.SpeedInitial,numel(time),1);speed(time>=cfg.CommandTime)=cfg.SpeedReference;
torque=zeros(size(time));torque(time>=cfg.CommandTime)=cfg.TorqueReference;
stimulus.signals.values=[stimulus.signals.values,speed,torque,repmat(cfg.Mode,numel(time),1)];
stimulus.signals.dimensions=10;
end
