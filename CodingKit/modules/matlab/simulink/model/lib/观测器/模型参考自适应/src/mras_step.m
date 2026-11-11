function next=mras_step(state,voltage,current,direction,enable,reset,s)
%MRAS_STEP One-step measured-current model and PI speed adaptation (SPMSM).
% State and settings indices are documented in parameter/README.md.
% No integrated current estimate replaces the previous measured dq current.
%#codegen
next=state;
if isfinite(enable) && isfinite(reset) && (enable<.5 || reset>.5)
    next=zeros(21,1,'like',state);next(1)=s(9);return;
end
if ~all(isfinite(s)) || s(1)<=0 || s(3)<=0 || s(4)<=0 || ...
        ~isfinite(enable) || ~isfinite(reset) || ~isfinite(direction) || ...
        (direction~=0 && abs(direction)~=1)
    next=zeros(21,1,'like',state);next(20)=2;return;
end
if direction==0
    next=zeros(21,1,'like',state);next(1)=s(9);return;
end
if state(20)>0,next(11)=0;next(3)=0;return;end
if ~all(isfinite(voltage)) || ~all(isfinite(current))
    next(20)=1;next(11)=0;next(3)=0;return;
end
if state(12)~=direction
    next=zeros(21,1,'like',state);next(1)=s(9);
    next(2)=direction*s(10);next(3)=direction*s(10);next(12)=direction;return;
end
ts=s(1);resistance=s(2);inductance=s(3);flux=s(4);
theta=state(1);cosine=cos(theta);sine=sin(theta);
measured=[cosine*current(1)+sine*current(2);-sine*current(1)+cosine*current(2)];
applied=[cosine*voltage(1)+sine*voltage(2);-sine*voltage(1)+cosine*voltage(2)];
omega=state(3);integral=state(2);count=cast(0,'like',state);
if state(8)>.5
    previous=state(4:5);previousVoltage=state(6:7);
    predicted=previous+(ts/inductance)*(previousVoltage-resistance*previous+ ...
        omega*inductance*[previous(2);-previous(1)]-[0;omega*flux]);
    residual=measured-predicted;
    filtered=state(9:10)+s(8)*(residual-state(9:10));
    denominator=ts*omega*flux/inductance;
    floorValue=ts*s(11)*flux/inductance;
    denominator=direction*max(abs(denominator),floorValue);
    normalizedD=filtered(1)/denominator;normalizedQ=filtered(2)/denominator;
    error=min(max(normalizedD,-1),1);
    unlimited=integral+s(5)*error;
    omega=direction*min(max(direction*unlimited,s(11)),s(12));
    integral=integral+ts*(s(6)*error+s(7)*(omega-unlimited));
    integral=min(max(integral,-s(12)),s(12));
    emf=[0;state(3)*flux]-(inductance/ts)*filtered;
    magnitude=hypot(emf(1),emf(2));
    qualified=abs(omega)>=s(13) && magnitude>=s(14) && ...
        abs(normalizedD)<=s(15) && abs(normalizedQ)<=s(16);
    if qualified,count=min(state(11)+1,s(17));end
    next(9:10)=filtered;next(13:14)=predicted;next(15:16)=residual;
    next(17)=normalizedD;next(18)=normalizedQ;next(19)=magnitude;next(21)=denominator;
end
next(1)=atan2(sin(theta+ts*omega),cos(theta+ts*omega));
next(2)=integral;next(3)=omega;next(4:5)=measured;next(6:7)=applied;
next(8)=1;next(11)=count;next(12)=direction;
end
