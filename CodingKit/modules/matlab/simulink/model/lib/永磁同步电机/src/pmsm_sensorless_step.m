function [next,jacobian]=pmsm_sensorless_step(state,voltage,settings)
%PMSM_SENSORLESS_STEP Euler SPMSM [i_alpha;i_beta;omega_e;theta_e] process model.
% settings=[Ts;Rs;L;Flux], voltage acts over the current sampling interval.
% Speed is locally constant; observer process noise represents unknown changes.
%#codegen
s=cast(settings,'like',state);ts=s(1);resistance=s(2);inductance=s(3);flux=s(4);
omega=state(3);theta=state(4);sine=sin(theta);cosine=cos(theta);
next=state;
next(1)=state(1)+(ts/inductance)*(voltage(1)-resistance*state(1)+omega*flux*sine);
next(2)=state(2)+(ts/inductance)*(voltage(2)-resistance*state(2)-omega*flux*cosine);
next(4)=atan2(sin(theta+ts*omega),cos(theta+ts*omega));
jacobian=eye(4,'like',state);
jacobian(1,1)=1-ts*resistance/inductance;jacobian(2,2)=jacobian(1,1);
jacobian(1,3)=ts*flux*sine/inductance;jacobian(1,4)=ts*omega*flux*cosine/inductance;
jacobian(2,3)=-ts*flux*cosine/inductance;jacobian(2,4)=ts*omega*flux*sine/inductance;
jacobian(4,3)=ts;
end
