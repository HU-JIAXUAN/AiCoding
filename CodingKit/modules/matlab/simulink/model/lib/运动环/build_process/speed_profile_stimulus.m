function stimulus=speed_profile_stimulus(cfg)
%SPEED_PROFILE_STIMULUS Exact grid: requested speed, enable and synchronous reset.
sample=(0:round(cfg.Duration/cfg.Ts))';time=sample*cfg.Ts;
reference=repmat(cfg.ReferenceInitial,numel(time),1);reference(time>=cfg.CommandTime)=cfg.Reference;
reference(time>=cfg.ReverseTime)=cfg.ReverseReference;
enable=ones(size(time));enable(time>=cfg.DisableStart & time<cfg.DisableEnd)=0;
reset=double(sample==round(cfg.ResetTime/cfg.Ts));
stimulus.time=time;stimulus.signals.values=[reference,enable,reset];stimulus.signals.dimensions=3;
end
