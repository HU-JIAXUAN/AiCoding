function [nextState,output]=startup_step(state,input,parameter)
%#codegen
%STARTUP_STEP Stateless sequencing; Unit Delay owns [mode,n,theta,ifN,fault].
% input = [enable;reset;direction;acquired]. Angles are software field angles.
parameter=cast(parameter,'like',state);
nextState=state;output=zeros(8,1,'like',state);
sampleTime=parameter(1);theta=state(3);mode=state(1);count=state(2);
omega=cast(0,'like',state);id=omega;ready=omega;fault=state(5);
if input(1)<0.5 || input(2)>0.5
    nextState(:)=0;nextState(3)=parameter(2);output(1)=parameter(2);
    return
end
if mode==7
    output(1)=theta;output(6)=7;output(7)=fault;output(8)=count*sampleTime;
    return
end
direction=cast(input(3),'like',state);
if abs(direction)~=1
    nextState(1)=7;nextState(2)=0;nextState(5)=2;
    output(1)=theta;output(6)=7;output(7)=2;
    return
end
if input(4)>0.5
    nextState(1)=6;nextState(2)=0;nextState(5)=0;
    output(1)=theta;output(6)=6;
    return
end
nextState(2)=count+1;
if mode==0
    nextState(1)=1;nextState(2)=0;
elseif mode==1
    if count+1>=parameter(6),nextState(1)=2;nextState(2)=0;end
elseif mode==2
    theta=-direction*pi/2;
    id=parameter(3)*min(count/parameter(8),1);
    if count+1>=parameter(7),nextState(1)=3;nextState(2)=0;end
elseif mode==3
    theta=-direction*pi/2*(1-min(count/parameter(10),1));
    id=parameter(3);
    if count<parameter(10),omega=direction*pi/(2*sampleTime*parameter(10));end
    if count+1>=parameter(9)
        nextState(1)=4;nextState(2)=0;nextState(4)=0;
    end
elseif mode==4 || mode==5
    if mode==4
        omega=direction*parameter(5)*min(count/parameter(11),1);
        id=parameter(3)+(parameter(4)-parameter(3))*min(count/parameter(12),1);
        if count+1>=parameter(11),nextState(1)=5;nextState(2)=0;end
    else
        omega=direction*parameter(5);id=parameter(4);
    end
    ready=cast(abs(omega)>=parameter(14),'like',state);
    nextState(4)=state(4)+1;
    if nextState(4)>=parameter(13)
        nextState(1)=7;nextState(2)=0;nextState(5)=1;
    end
elseif mode==6
    nextState(2)=0;
else
    nextState(1)=7;nextState(2)=0;nextState(5)=3;
end
if mode==4 || mode==5
    nextTheta=theta+sampleTime*omega;
    nextState(3)=atan2(sin(nextTheta),cos(nextTheta));
else
    nextState(3)=theta;
end
output(1)=theta;output(2)=omega;output(3)=id;output(4)=0;
output(5)=ready;output(6)=mode;output(7)=fault;output(8)=count*sampleTime;
end
