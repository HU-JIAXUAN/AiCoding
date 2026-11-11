function [stim,truth] = smo_fixture(t,omega,theta0,iq,motor)
%SMO_FIXTURE Independent continuous-equation SPMSM voltage/current trajectory.
% No observer equations are used. Voltage is sampled at interval starts (ZOH).
t=t(:);omega=omega(:);assert(numel(t)==numel(omega));
theta=theta0+cumtrapz(t,omega);
ia=-iq*sin(theta);ib=iq*cos(theta);
ea=-motor.Flux*omega.*sin(theta);eb=motor.Flux*omega.*cos(theta);
ua=motor.Rs*ia-motor.L*omega.*ib+ea;
ub=motor.Rs*ib+motor.L*omega.*ia+eb;
direction=sign(omega);direction(abs(omega)<motor.MinOmega)=0;
u=[ua,ub,ia,ib,direction,ones(size(t)),zeros(size(t)),atan2(sin(theta),cos(theta)),omega];
stim.time=t;stim.signals.values=u;stim.signals.dimensions=9;
truth=struct('theta',theta,'omega',omega,'emf',[ea,eb], ...
    'motor',motor,'iq',iq,'theta0',theta0);
end
