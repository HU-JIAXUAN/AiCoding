function definitions=bridge_trace_channels()
%BRIDGE_TRACE_CHANNELS Actual saved vector fields, SI units, widths and wires.
names={'current_ab','phase_current','phase_voltage','voltage_ab','speed_mechanical','theta_e', ...
    'torque','dc_current','diode_states','magnetic_energy','kinetic_energy','bridge_loss', ...
    'equation_residual','next_phase_current','neutral_voltage','pole_voltage'};
units={'A','A','V','V','mechanical rad/s','electrical rad','N*m','A','-1/0/+1','J','J','W','V','A','V','V'};
widths=[2,3,3,2,1,1,1,1,3,1,1,1,1,3,1,3];
definitions=cell(17,4);definitions(1,:)={'stimulus','mixed',5,'#Stimulus.y1'};
for k=1:numel(names),definitions(k+1,:)={names{k},units{k},widths(k),sprintf('#Plant.y%d',k)};end
end
