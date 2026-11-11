function [next,output]=flying_capture_step(state,input,parameter)
%FLYING_CAPTURE_STEP App sequence, using measured dq currents and estimates.
%#codegen
% state=[mode;qualificationN;stageN;lossN;fault;speedI;referenceD;referenceQ].
% input=[id;iq;omegaE;valid;fluxResidual;voltageMagnitude;speedRefM;enable;reset].
% output=[idRef;iqRef;bridgeMode;piEnable;piReset;precharge;mode;fault;
%         qualificationN;lossN;speedI;iqTarget]. No plant truth is an input.
p=cast(parameter,'like',state);u=cast(input,'like',state);
next=state;output=zeros(12,1,'like',state);mode=state(1);
if u(8)<0.5 || u(9)>0.5
    next(:)=0;output(5)=1;return
end
if ~all(isfinite(u))
    next(:)=0;next(1)=5;next(5)=7;output(5)=1;output(7)=5;output(8)=7;return
end
output(7:11)=[mode;state(5);state(2);state(4);state(6)];
if mode==5,output(5)=1;return,end
if mode==0,next(1)=1;output(5)=1;return,end
current=hypot(u(1),u(2));speedError=u(7)-u(3)/p(2);
healthy=u(4)>0.5 && abs(u(3))>=p(3) && u(5)>=0 && u(5)<=p(4);
output(4)=1;
if mode==1 || mode==2
    % PWM remains off while PI total voltage follows passive terminal voltage.
    output(1:2)=u(1:2);output(6)=1;
    next(6)=-p(12)*speedError;next(7:8)=u(1:2);
    if mode==1
        next(3)=state(3)+1;
        if healthy,next(2)=min(state(2)+1,p(5));else,next(2)=0;end
        if next(2)>=p(5)
            if u(7)*u(3)<=0,next(1)=5;next(5)=2;
            elseif u(6)>p(10),next(1)=5;next(5)=3;
            elseif current>p(9),next(1)=5;next(5)=4;
            else,next(1)=2;next(3)=0;next(4)=0;end
        elseif next(3)>=p(8),next(1)=5;next(5)=1;
        end
    else
        if healthy,next(4)=0;next(3)=state(3)+1;
        else,next(4)=state(4)+1;next(3)=0;end
        if healthy && u(7)*u(3)<=0,next(1)=5;next(5)=2;
        elseif u(6)>p(10),next(1)=5;next(5)=3;
        elseif current>p(9),next(1)=5;next(5)=4;
        elseif next(4)>=p(7),next(1)=5;next(5)=5;
        elseif next(3)>=p(6),next(1)=3;end
    end
elseif mode==3
    output(1:2)=state(7:8);output(3)=1;
    iqRaw=p(12)*speedError+state(6);
    iqTarget=min(max(iqRaw,-p(15)),p(15));output(12)=iqTarget;
    step=p(1)*p(16);
    next(7)=state(7)+min(max(-state(7),-step),step);
    next(8)=state(8)+min(max(iqTarget-state(8),-step),step);
    next(6)=state(6)+p(1)*(p(13)*speedError+p(14)*(state(8)-iqRaw));
    if healthy,next(4)=0;else,next(4)=state(4)+1;end
    if healthy && u(7)*u(3)<=0,next(1)=5;next(5)=2;
    elseif next(4)>=p(7),next(1)=5;next(5)=5;end
else
    next(1)=5;next(5)=7;
end
if current>p(11),next(1)=5;next(5)=6;end
end
