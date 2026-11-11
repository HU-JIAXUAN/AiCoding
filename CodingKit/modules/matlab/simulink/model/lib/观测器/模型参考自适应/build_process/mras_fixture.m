function [stimulus,truth]=mras_fixture(time,omega,theta0,id,iq,motor,direction)
%MRAS_FIXTURE Continuous SPMSM dq voltage balance, independent of MRAS updates.
time=time(:);omega=omega(:);id=id(:);iq=iq(:);
assert(numel(time)==numel(omega) && numel(time)==numel(id) && numel(time)==numel(iq));
assert(max(abs(diff(time)-motor.Ts))<1e-12);
theta=theta0+cumtrapz(time,omega);did=gradient(id,time);diq=gradient(iq,time);
vd=motor.Rs*id+motor.L*did-omega.*motor.L.*iq;
vq=motor.Rs*iq+motor.L*diq+omega.*(motor.L*id+motor.Flux);
c=cos(theta);s=sin(theta);current=[c.*id-s.*iq,s.*id+c.*iq];
voltage=[c.*vd-s.*vq,s.*vd+c.*vq];
if isscalar(direction),direction=repmat(direction,size(time));else,direction=direction(:);end
stimulus.time=time;stimulus.signals.values=[voltage,current,direction,ones(size(time)), ...
    zeros(size(time)),atan2(sin(theta),cos(theta)),omega];stimulus.signals.dimensions=9;
truth=struct('time',time,'theta',theta,'omega',omega,'current',current,'voltage',voltage, ...
    'id',id,'iq',iq,'motor',motor,'direction_prior',direction);
end
