function next=flux_predict(state,voltage,current,active,settings)
%FLUX_PREDICT Leaky stator-flux integration and DC washout next states.
% state=[leaky_flux_ab;dc_flux_ab], each pair in Wb.
% settings=[Ts;Rs;L;p;LeakA;LeakB;DcA;MinCompOmega;FullCompOmega;MaxCompGain;Flux].
%#codegen
next=zeros(4,1,'like',state);
if ~active,return;end
z=state(1:2);dc=state(3:4);
next(1:2)=settings(5)*z+settings(6)*(voltage-settings(2)*current);
next(3:4)=settings(7)*dc+(1-settings(7))*z;
end
