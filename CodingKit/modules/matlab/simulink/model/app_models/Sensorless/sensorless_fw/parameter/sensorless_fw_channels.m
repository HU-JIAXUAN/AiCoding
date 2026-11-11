function definitions=sensorless_fw_channels(scope)
%SENSORLESS_FW_CHANNELS name, unit, vector width, actual block source alias.
switch char(scope)
    case 'plant'
        definitions=bridge_trace_channels();definitions=definitions(2:end,:);
        for k=1:size(definitions,1),definitions{k,4}=strrep(definitions{k,4},'#Plant.','#Motor.');end
        definitions=[definitions;{'load_torque','N*m',1,'#load_torque.y1'; ...
            'bus_voltage','V',1,'#bus_voltage.y1';'bridge_mode','0/1/2',1,'#mode.y1'; ...
            'duty','1',3,'#duty.y1';'id_true','A',1,'#RotorPark.y1';'iq_true','A',1,'#RotorPark.y2'}];
    case 'observer'
        definitions=observer_foc_channels('observer','eemf');
    case 'controller'
        definitions=sensorless_foc_channels('controller');
        for k=1:size(definitions,1)
            if strcmp(definitions{k,1},'torque_allocated'),definitions{k,4}='#CurrentAllocator.y3';end
            if strcmp(definitions{k,1},'iq_closed'),definitions{k,4}='#CurrentAllocator.y2';end
        end
    case 'allocation'
        names={'id_reference','iq_reference','allocated_torque','id_mtpa','iq_mtpa', ...
            'id_fw','filtered_voltage','voltage_available','predicted_voltage', ...
            'current_margin','voltage_margin','torque_residual','current_limited', ...
            'voltage_limited','feasible','fw_active','voltage_error', ...
            'model_voltage_demand','effective_voltage_demand'};
        units={'A','A','N*m','A','A','A','V','V','V','A','V','N*m','1','1','1','1','V','V','V'};
        definitions=cell(25,4);
        for k=1:19,definitions(k,:)={names{k},units{k},1,sprintf('#CurrentAllocator.y%d',k)};end
        casts={'CurrentLimitFlagDouble','VoltageLimitFlagDouble','FeasibleFlagDouble','WeakeningFlagDouble'};
        for k=1:4,definitions{12+k,4}=['#' casts{k} '.y1'];end
        definitions(20:end,:)={'torque_request','N*m',1,'#SpeedPI.y1'; ...
            'omega_e','electrical rad/s',1,'#Handover.y2';'bus_voltage','V',1,'#bus_voltage.y1'; ...
            'voltage_demand_prev','V',1,'#VoltageDemandPrevious.y1'; ...
            'drive_enable','1',1,'#Handover.y8';'reset','1',1,'#reset.y1'};
    case 'guard'
        definitions={'request_enable','1',1,'#request_enable.y1';'reset','1',1,'#reset.y1'; ...
            'observer_enable','1',1,'#observer_enable.y1';'emf_magnitude','V',1,'#emf_magnitude.y1'; ...
            'direction','-1/+1',1,'#direction.y1';'warm_count','samples',1,'#WarmCount.y1'; ...
            'permit','1',1,'#PermitSelected.y1';'qualified','1',1,'#QualifiedDouble.y1'; ...
            'direction_changed','1',1,'#DirectionChangedDouble.y1'};
    case 'actuation'
        definitions=sensorless_foc_channels('actuation');definitions{1,3}=7;
        definitions{4,4}='#VoltageStage.y6';definitions{5,4}='#VoltageStage.y1';
        definitions{6,4}='#VoltageStage.y2';definitions{7,4}='#VoltageStage.y3';
        definitions{8,4}='#VoltageStage.y4';
    otherwise,error('Unknown FW trace scope: %s',scope);
end
end
