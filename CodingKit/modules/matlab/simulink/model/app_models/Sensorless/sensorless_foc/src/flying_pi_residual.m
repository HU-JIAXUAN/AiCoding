function residual=flying_pi_residual(request,limited,passiveVoltage,error,precharge,settings)
%FLYING_PI_RESIDUAL Prepare PI while off, or use actuator feasibility while on.
%#codegen
residual=limited-request;
if precharge>0.5
    % With Kaw=1/Ts this makes I[k+1]=passiveVoltage-P[k].
    residual=passiveVoltage-request-settings(1)*settings(2:3).*error;
end
end
