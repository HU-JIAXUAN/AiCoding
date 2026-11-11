function definitions=observer_foc_channels(scope,kind)
%OBSERVER_FOC_CHANNELS Actual logged names, units, widths and block sources.
kind=char(validatestring(kind,{'eemf','flux'}));
if ~strcmp(scope,'observer')
    definitions=sensorless_foc_channels(scope);return
end
definitions={'theta_hat','electrical rad',1,'#Estimator.y1'; ...
    'omega_hat','electrical rad/s',1,'#Estimator.y2';'valid','1',1,'#Estimator.y3'};
if strcmp(kind,'eemf')
    names={'emf_alpha','emf_beta','i_hat_alpha','i_hat_beta', ...
        'residual_alpha','residual_beta','phase_measured','emf_magnitude','phase_error'};
    units={'V','V','A','A','A','A','rad','V','rad'};
else
    names={'rotor_flux_alpha','rotor_flux_beta','stator_flux_alpha','stator_flux_beta', ...
        'flux_magnitude','torque_hat','phase_measured','phase_error', ...
        'equivalent_residual','filtered_speed','compensation_ready'};
    units={'Wb','Wb','Wb','Wb','Wb','N*m','rad','rad','A-equivalent','electrical rad/s','1'};
end
for k=1:numel(names)
    definitions(end+1,:)={names{k},units{k},1,sprintf('#Estimator.y%d',k+3)}; %#ok<AGROW>
end
if strcmp(kind,'eemf'),residual='#ResidualNorm.y1';unit='A';
else,residual='#Estimator.y12';unit='A-equivalent';end
definitions=[definitions;{'current_ab','A',2,'#current_ab.y1'; ...
    'observer_voltage','V',2,'#VoltageAge.y1'; ...
    'observer_residual',unit,1,residual;'enable','1',1,'#enable.y1'; ...
    'reset','1',1,'#reset.y1';'direction','1',1,'#direction.y1'}];
end
