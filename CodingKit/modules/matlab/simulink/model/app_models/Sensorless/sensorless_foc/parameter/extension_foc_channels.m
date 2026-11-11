function definitions=extension_foc_channels(scope,kind)
%EXTENSION_FOC_CHANNELS Actual linked-estimator outputs plus measured inputs.
spec=extension_foc_spec(kind);
if ~strcmp(scope,'observer')
    definitions=sensorless_fw_channels(scope);
    if strcmp(scope,'guard')
        definitions{4,1}='terminal_voltage_magnitude';definitions{4,4}='#voltage_magnitude.y1';
    end
    return
end
switch spec.kind
    case 'mras'
        names={'theta_hat','omega_hat','valid','predicted_id','predicted_iq','measured_id','measured_iq', ...
            'residual_d','residual_q','normalized_d','normalized_q','emf_magnitude','qualification_count', ...
            'speed_integral','fault','normalization_denominator'};
        units={'electrical rad','electrical rad/s','1','A','A','A','A','A','A','1','1','V','samples','electrical rad/s','code','A'};
    case {'ekf','ukf'}
        names={'theta_hat','omega_hat','valid','i_hat_alpha','i_hat_beta','innovation_alpha','innovation_beta', ...
            'normalized_innovation','theta_std','omega_std','angle_rate','rate_mismatch','qualification_count', ...
            'fault','variance_i_alpha','variance_i_beta','variance_omega','variance_theta', ...
            'gain_theta_alpha','gain_theta_beta','gain_omega_alpha','gain_omega_beta','emf_magnitude','numeric_repairs','covariance'};
        units={'electrical rad','electrical rad/s','1','A','A','A','A','1','electrical rad','electrical rad/s', ...
            'electrical rad/s','electrical rad/s','samples','code','A^2','A^2','(electrical rad/s)^2', ...
            '(electrical rad)^2','rad/A','rad/A','rad/(s*A)','rad/(s*A)','V','count','mixed covariance'};
    case 'sigmoid'
        names={'theta_hat','omega_hat','valid','emf_alpha','emf_beta','i_hat_alpha','i_hat_beta', ...
            'residual_alpha','residual_beta','phase_measured','emf_magnitude','phase_error','fault','residual_norm'};
        units={'electrical rad','electrical rad/s','1','V','V','A','A','A','A','rad','V','rad','code','A'};
end
definitions=cell(numel(names),4);
for k=1:numel(names),definitions(k,:)={names{k},units{k},1,sprintf('#Estimator.y%d',k)};end
if ismember(spec.kind,{'ekf','ukf'}),definitions{25,3}=16;end
definitions=[definitions;{'current_ab','A',2,'#current_ab.y1';'observer_voltage','V',2,'#VoltageAge.y1'; ...
    'observer_residual','A',1,'#ResidualNorm.y1';'enable','1',1,'#enable.y1';'reset','1',1,'#reset.y1'; ...
    'direction','-1/+1',1,'#direction.y1';'terminal_voltage_magnitude','V',1,'#TerminalVoltageMagnitude.y1'}];
end
