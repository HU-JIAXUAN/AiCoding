function stimulus=sensorless_fw_stimulus(p)
%SENSORLESS_FW_STIMULUS speed,load,enable,reset,direction,observer_enable,Vdc.
stimulus=sensorless_foc_stimulus(p);
bus=zeros(size(stimulus.time));
for k=1:numel(p.fwCfg.BusTimes)
    bus(stimulus.time>=p.fwCfg.BusTimes(k)-p.currentCfg.Ts/4)=p.fwCfg.BusValues(k);
end
assert(all(bus>0));stimulus.signals.values(:,7)=bus;stimulus.signals.dimensions=7;
end
