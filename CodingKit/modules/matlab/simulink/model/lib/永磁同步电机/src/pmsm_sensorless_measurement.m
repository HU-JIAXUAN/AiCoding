function [current,jacobian]=pmsm_sensorless_measurement(state)
%PMSM_SENSORLESS_MEASUREMENT Current measurement for the shared four-state model.
%#codegen
current=state(1:2);jacobian=zeros(2,4,'like',state);
jacobian(1,1)=1;jacobian(2,2)=1;
end
