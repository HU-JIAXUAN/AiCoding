function stimulus=bridge_bus_stimulus(p)
%BRIDGE_BUS_STIMULUS Sample-aligned duty/mode/load and independent DC bus.
stimulus=bridge_plant_stimulus(p);
times=p.bridgeTestCfg.BusTimes;values=p.bridgeTestCfg.BusValues;
assert(isvector(times) && numel(times)==numel(values) && times(1)==0);
assert(all(isfinite(times)) && all(diff(times)>0));
assert(all(isfinite(values)) && all(values>0));
assert(all(abs(times/p.bridgeCfg.Ts-round(times/p.bridgeCfg.Ts))<1e-8));
bus=values(1)*ones(size(stimulus.time));
for k=2:numel(times),bus(stimulus.time>=times(k)-p.bridgeCfg.Ts/4)=values(k);end
stimulus.signals.values(:,6)=bus;
stimulus.signals.dimensions=6;
end
