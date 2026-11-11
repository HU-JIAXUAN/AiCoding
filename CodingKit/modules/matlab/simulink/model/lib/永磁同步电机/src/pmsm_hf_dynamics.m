function [derivative,signals]=pmsm_hf_dynamics(state,voltage,loadTorque,settings)
%PMSM_HF_DYNAMICS Continuous nonlinear salient PMSM in physical rotor dq axes.
% state=[id;iq;omega_mechanical;theta_mechanical], voltage=[u_alpha;u_beta].
% settings=[Rs;Ld0;Lq;Flux;p;J;B;SaturationDepth;SaturationCurrent;M;MechanicalEnabled].
% psi_d=Flux+Ld0*(id-s*Is*log(cosh(id/Is)))+M*iq, psi_q=Lq*iq+M*id.
% The symmetric differential-inductance matrix is the flux Jacobian.
%#codegen
id=state(1);iq=state(2);speed=state(3);theta=settings(5)*state(4);
x=id/settings(9);absolute=abs(x);
logCosh=absolute+log1p(exp(-2*absolute))-log(2);
psiD=settings(4)+settings(2)*(id-settings(8)*settings(9)*logCosh)+settings(10)*iq;
psiQ=settings(3)*iq+settings(10)*id;
ld=settings(2)*(1-settings(8)*tanh(x));lq=settings(3);mutual=settings(10);
cosine=cos(theta);sine=sin(theta);omega=settings(5)*speed;
vd=cosine*voltage(1)+sine*voltage(2);
vq=-sine*voltage(1)+cosine*voltage(2);
balanceD=vd-settings(1)*id+omega*psiQ;
balanceQ=vq-settings(1)*iq-omega*psiD;
determinant=ld*lq-mutual*mutual;
derivative=zeros(4,1,'like',state);
derivative(1)=(lq*balanceD-mutual*balanceQ)/determinant;
derivative(2)=(ld*balanceQ-mutual*balanceD)/determinant;
torque=1.5*settings(5)*(psiD*iq-psiQ*id);
if settings(11)>0.5
    derivative(3)=(torque-loadTorque-settings(7)*speed)/settings(6);
    derivative(4)=speed;
end
signals=[cosine*id-sine*iq;sine*id+cosine*iq;atan2(sine,cosine);omega; ...
    torque;id;iq;ld;psiD;psiQ];
end
