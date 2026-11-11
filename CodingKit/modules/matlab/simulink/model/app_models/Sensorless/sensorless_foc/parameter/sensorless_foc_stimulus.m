function stimulus=sensorless_foc_stimulus(p)
%SENSORLESS_FOC_STIMULUS Columns: speed_m,load,enable,reset,direction,observer_en.
sample=(0:round(p.experimentCfg.Duration/p.currentCfg.Ts))';time=sample*p.currentCfg.Ts;
speed=p.focCfg.SpeedInitial*ones(size(sample));
speed(sample>=round(p.focCfg.CommandTime/p.currentCfg.Ts))=p.focCfg.SpeedReference;
load=zeros(size(sample));load(sample>=round(p.focCfg.LoadTime/p.currentCfg.Ts))=p.focCfg.LoadTorque;
stimulus.time=time;stimulus.signals.values=[speed,load, ...
    p.focCfg.Enable*ones(size(sample)),p.focCfg.Reset*ones(size(sample)), ...
    p.focCfg.Direction*ones(size(sample)),p.focCfg.ObserverEnable*ones(size(sample))];
stimulus.signals.dimensions=6;
end
