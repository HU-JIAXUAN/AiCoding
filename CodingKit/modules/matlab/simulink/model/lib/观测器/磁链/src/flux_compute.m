function [rotorFlux,statorFlux,torque,residual,ready]=flux_compute(state,current,omega,active,settings)
%FLUX_COMPUTE Causal frequency-compensated SPMSM rotor flux from saved states.
% omega is a separate filtered PREVIOUS estimate, not the current PLL output.
% No voltage feedthrough, true angle, true speed or rotation-direction input.
%#codegen
rotorFlux=zeros(2,1,'like',state);statorFlux=zeros(2,1,'like',state);
torque=zeros(1,'like',state);residual=zeros(1,'like',state);ready=zeros(1,'like',state);
if ~active,return;end
filtered=state(1:2)-state(3:4);
coefficient=complex(ones(1,'like',state),zeros(1,'like',state));
if abs(omega)>settings(8)
    weight=min(1,(abs(omega)-settings(8))/(settings(9)-settings(8)));
    angle=omega*settings(1);unit=complex(cos(angle),sin(angle));
    raw=(unit-settings(5))*(unit-settings(7))/ ...
        (complex(omega*0,omega*settings(6))*(unit-1));
    gain=abs(raw);limited=gain>settings(10);
    if limited,raw=raw*(settings(10)/gain);end
    coefficient=1+weight*(raw-1);ready=cast(weight>=0.99 && ~limited,'like',state);
end
statorFlux=real(coefficient)*filtered+imag(coefficient)*[-filtered(2);filtered(1)];
rotorFlux=statorFlux-settings(3)*current;
torque=1.5*settings(4)*(rotorFlux(1)*current(2)-rotorFlux(2)*current(1));
residual=abs(hypot(rotorFlux(1),rotorFlux(2))-settings(11))/settings(3);
end
