function [currentAB,phaseCurrent,speed,theta,torque,magneticEnergy,kineticEnergy]=pmsm_bridge_output(state,settings)
%PMSM_BRIDGE_OUTPUT State-only physical outputs at the beginning of a step.
% state=[i_alpha;i_beta;omega_mechanical;theta_mechanical]. SI peak convention.
%#codegen
currentAB=state(1:2);speed=state(3);
angle=settings(6)*state(4);cosine=cos(angle);sine=sin(angle);
theta=atan2(sine,cosine);
id=cosine*currentAB(1)+sine*currentAB(2);
iq=-sine*currentAB(1)+cosine*currentAB(2);
torque=1.5*settings(6)*(settings(5)*iq+(settings(3)-settings(4))*id*iq);
phaseCurrent=[currentAB(1);-0.5*currentAB(1)+sqrt(3)/2*currentAB(2); ...
    -0.5*currentAB(1)-sqrt(3)/2*currentAB(2)];
magneticEnergy=0.75*(settings(3)*id*id+settings(4)*iq*iq);
kineticEnergy=0.5*settings(7)*speed*speed;
end
