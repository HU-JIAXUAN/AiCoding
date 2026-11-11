function [voltage,integralBase,history,integralState]=frame_pi_compute(state,input,parameter)
%#codegen
%FRAME_PI_COMPUTE Retain physical-error P response while transferring coordinates.
% state=[Iprev(2);Eprev(2);Pprev(2);FFprev(2)]
% input=[error(2);FFnow(2);deltaExtra;track;enable;reset], parameter=[Kpd;Kpq]
u=cast(input,'like',state);p=cast(parameter,'like',state);
voltage=zeros(2,1,'like',state);integralBase=voltage;integralState=voltage;
history=zeros(6,1,'like',state);
if u(7)<0.5 || u(8)>0.5,return,end
error=[u(1);u(2)];feedforward=[u(3);u(4)];
proportional=p.*error;integralState=[state(1);state(2)];
integralBase=integralState;
if u(6)>0.5
    cosine=cos(u(5));sine=sin(u(5));rotation=[cosine,sine;-sine,cosine];
    previousError=[state(3);state(4)];previousP=[state(5);state(6)];
    previousFF=[state(7);state(8)];
    coordinateOnlyP=p.*(rotation*previousError);
    integralBase=rotation*(integralState+previousP+previousFF)-coordinateOnlyP-feedforward;
end
voltage=integralBase+proportional;history=[error;proportional;feedforward];
end
