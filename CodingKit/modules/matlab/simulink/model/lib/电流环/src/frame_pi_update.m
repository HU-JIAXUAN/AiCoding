function nextIntegral=frame_pi_update(integralBase,input,parameter)
%#codegen
%FRAME_PI_UPDATE Residual affects only next Unit Delay state, not present voltage.
% input=[error(2);finalVoltageResidual(2);enable;reset]
% parameter=[Ts;Kid;Kiq;Kaw]
u=cast(input,'like',integralBase);p=cast(parameter,'like',integralBase);
nextIntegral=zeros(2,1,'like',integralBase);
if u(5)<0.5 || u(6)>0.5,return,end
error=[u(1);u(2)];residual=[u(3);u(4)];
nextIntegral=integralBase+p(1)*([p(2);p(3)].*error+p(4)*residual);
end
