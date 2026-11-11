function [stimulus,truth]=emf_fixture(time,omega,theta0,id,iq,motor)
%EMF_FIXTURE Analytic dq voltage balance independent of observer equations.
time=time(:);omega=omega(:);id=id(:);iq=iq(:);
assert(numel(time)==numel(omega) && numel(id)==numel(time) && numel(iq)==numel(time));
assert(max(abs(diff(time)-motor.Ts))<1e-12,'The fixture must use a uniform motor.Ts grid.');
theta=theta0+cumtrapz(time,omega);did=gradient(id,time);diq=gradient(iq,time);
vd=motor.Rs*id+motor.Ld*did-omega.*motor.Lq.*iq;
vq=motor.Rs*iq+motor.Lq*diq+omega.*(motor.Ld*id+motor.Flux);
c=cos(theta);s=sin(theta);ia=c.*id-s.*iq;ib=s.*id+c.*iq;
ua=c.*vd-s.*vq;ub=s.*vd+c.*vq;
direction=sign(omega);direction(abs(omega)<motor.MinOmega)=0;
stimulus.time=[];stimulus.signals.values=[ua,ub,ia,ib,direction,ones(size(time)), ...
    zeros(size(time)),atan2(sin(theta),cos(theta)),omega];stimulus.signals.dimensions=9;
amplitude=(motor.Ld-motor.Lq).*(omega.*id-diq)+omega*motor.Flux;
truth=struct('time',time,'theta',theta,'omega',omega,'current',[ia,ib], ...
    'extended_emf',[-s.*amplitude,c.*amplitude],'motor',motor,'id',id,'iq',iq);
end
