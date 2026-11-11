function settings=bridge_bus_settings(nominalSettings,busVoltage)
%#codegen
%BRIDGE_BUS_SETTINGS Apply the measured/specified DC rail for this interval.
assert(isfinite(busVoltage) && busVoltage>0, ...
    'Positive finite DC bus voltage required.');
settings=nominalSettings;
settings(9)=busVoltage;
end
