function definitions=bridge_bus_trace_channels()
%BRIDGE_BUS_TRACE_CHANNELS Extend the physical trace with the actual bus.
definitions=bridge_trace_channels();
definitions{1,3}=6;
definitions{1,2}='duty_abc,mode,load_Nm,bus_V';
end
