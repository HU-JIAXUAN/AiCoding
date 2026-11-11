function next=open_loop_drive_update(state,input,s)
%OPEN_LOOP_DRIVE_UPDATE State-only oscillator; no rotor angle or speed input.
% state: stage,count,theta,frequency,amplitude,fault,low_count,voltage_limited.
% input: electrical_frequency_Hz,enable,reset,current_norm,terminal_voltage,bus.
%#codegen
next=state;s=cast(s,'like',state);u=cast(input,'like',state);
if (isfinite(u(2))&&u(2)==0)||(isfinite(u(3))&&u(3)==1)
    next=zeros(8,1,'like',state);next(3)=s(18);return
end
if ~all(isfinite(u))||u(6)<=0||u(4)<0||u(5)<0|| ...
        (u(2)~=0&&u(2)~=1)||(u(3)~=0&&u(3)~=1)
    next(1)=7;next(6)=2;next(4:5)=0;return
end
if state(1)==7,return;end
if u(4)>s(17),next(1)=7;next(6)=1;next(4:5)=0;return;end
stage=state(1);count=state(2)+1;next(2)=count;next(8)=0;
if stage==0
    next(1)=1;next(2)=0;
elseif stage==1
    low=cast(0,'like',state);
    if u(5)<=s(6)&&u(4)<=s(7),low=state(7)+1;end
    next(7)=low;
    if low>=s(5),next(1)=2;next(2)=0;
    elseif count>=s(8),next(1)=7;next(6)=3;end
elseif stage==2
    next(3)=s(18);next(4)=0;next(5)=s(11)*min(count/s(10),1);
    if count>=s(9),next(1)=3;next(2)=0;end
elseif stage==3
    requested=min(max(u(1),-s(3)),s(3));step=s(4)*s(1);
    next(4)=state(4)+min(max(requested-state(4),-step),step);
    next(3)=atan2(sin(state(3)+2*pi*s(1)*state(4)),cos(state(3)+2*pi*s(1)*state(4)));
    if s(2)==1,amplitude=s(12);
    else
        requestedAmplitude=s(15)+s(14)*abs(next(4));
        amplitude=min(requestedAmplitude,u(6)*s(16));
        next(8)=cast(requestedAmplitude>amplitude,'like',state);
    end
    step=s(13)*s(1);next(5)=state(5)+min(max(amplitude-state(5),-step),step);
else
    next(1)=7;next(6)=4;next(4:5)=0;
end
end
