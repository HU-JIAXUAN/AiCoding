function [next,y]=hybrid_fusion_step(state,input,parameter)
%HYBRID_FUSION_STEP Qualified bidirectional fusion; no motor truth inputs.
% input: thetaLow,omegaLow,lowValid,thetaHigh,omegaHigh,highValid,enable,reset.
% y: theta,omegaBase,omegaFrame,valid,beta,injection,mode,fault,lowQ,highQ,
%    lowPiFlip,phaseGap,lowN,highN,lossN,phaseCorrection,lowBranchReady.
% Modes: 0 wait,1 low,2 blend,3 high,4 latched fault.
%#codegen
p=cast(parameter,'like',state);u=cast(input,'like',state);
next=state;y=zeros(17,1,'like',state);
if ~isfinite(u(7)) || ~isfinite(u(8))
    next(10)=2;next(4)=0;y(1)=state(1);y(7)=4;y(8)=2;return
end
if u(7)<.5 || u(8)>.5
    next(:)=0;next(4)=1;next(18)=1;return
end
if state(10)>0
    next(4)=0;y(1)=state(1);y(7)=4;y(8)=state(10);return
end

rawLow=all(isfinite(u(1:3))) && u(3)>.5 && abs(u(2))<=p(4) && state(4)>=p(17);
rawHigh=all(isfinite(u(4:6))) && u(6)>.5 && abs(u(5))>=p(16);
if rawLow && state(15)>.5
    rawLow=abs(wrap(u(1)-state(11)-p(1)*state(12)))<=p(14);
end
if rawHigh && state(16)>.5
    rawHigh=abs(wrap(u(4)-state(13)-p(1)*state(14)))<=p(14);
end
if rawLow
    next(11)=u(1);next(12)=u(2);next(15)=1;
elseif state(15)>.5
    next(11)=wrap(state(11)+p(1)*state(12));
end
if rawHigh
    next(13)=u(4);next(14)=u(5);next(16)=1;
elseif state(16)>.5
    next(13)=wrap(state(13)+p(1)*state(14));
end

flip=state(5);branch=state(17);gap=cast(0,'like',state);
if state(4)<p(17),branch=cast(0,'like',state);end
highWasQualified=state(7)>=p(7) && rawHigh;
if state(9)>.5 && state(3)>=1 && highWasQualified && rawLow && (branch<.5 || state(6)<1)
    ordinary=abs(wrap(u(1)-u(4)));opposite=abs(wrap(u(1)+pi-u(4)));
    candidate=cast(opposite<ordinary,'like',state);
    candidateGap=wrap(u(4)-u(1)-pi*candidate);
    if abs(candidateGap)<=p(5) && abs(u(2)-u(5))<=p(6)
        flip=candidate;branch=cast(1,'like',state);
    else
        branch=cast(0,'like',state);
    end
end
thetaLow=cast(0,'like',state);
if rawLow,thetaLow=wrap(u(1)+pi*flip);end
agree=false;
if rawLow && rawHigh
    gap=wrap(u(4)-thetaLow);
    agree=abs(gap)<=p(5) && abs(u(2)-u(5))<=p(6);
end
lowEligible=rawLow && (state(9)<.5 || branch>.5);
if state(9)>.5 && state(3)>0 && rawHigh,lowEligible=lowEligible && agree;end
highEligible=rawHigh;
if state(6)>=p(7) && rawLow,highEligible=highEligible && agree;end
if lowEligible
    next(6)=min(state(6)+1,p(7));next(19)=0;
else
    next(19)=min(state(19)+1,p(8));
    if state(6)<p(7) || next(19)>=p(8),next(6)=0;end
    if ~rawLow && next(19)>=p(8),next(15)=0;end
end
if highEligible
    next(7)=min(state(7)+1,p(7));next(20)=0;
else
    next(20)=min(state(20)+1,p(8));
    if state(7)<p(7) || next(20)>=p(8),next(7)=0;end
    if ~rawHigh && next(20)>=p(8),next(16)=0;end
end
lowQ=lowEligible && next(6)>=p(7);highQ=highEligible && next(7)>=p(7);
next(5)=flip;next(17)=branch;

beta=state(3);omega=state(2);theta=state(1);frameOmega=omega;correction=cast(0,'like',state);
valid=false;mode=cast(0,'like',state);fault=cast(0,'like',state);
if state(9)<.5
    if lowQ
        next(9)=1;branch=cast(1,'like',state);next(17)=branch;
        beta=cast(0,'like',state);theta=thetaLow;omega=u(2);frameOmega=omega;valid=true;
    elseif highQ && p(15)>.5 && abs(u(5))>=p(3)
        next(9)=1;beta=cast(1,'like',state);theta=wrap(u(4));omega=u(5);frameOmega=omega;valid=true;
    end
else
    available=lowQ || highQ;
    if available
        next(8)=0;
        if lowQ && highQ
            speed=abs((1-beta)*u(2)+beta*u(5));
            target=min(max((speed-p(2))/(p(3)-p(2)),0),1);
            beta=beta+min(max(target-beta,-p(9)),p(9));
            omega=(1-beta)*u(2)+beta*u(5);
            rawTheta=wrap(thetaLow+beta*gap);
        elseif lowQ
            beta=cast(0,'like',state);omega=u(2);rawTheta=thetaLow;
        else
            beta=cast(1,'like',state);omega=u(5);rawTheta=wrap(u(4));
        end
        prediction=wrap(state(1)+p(1)*omega);
        error=wrap(rawTheta-prediction);
        correction=min(max(error,-p(13)*p(1)),p(13)*p(1));
        theta=wrap(prediction+correction);
        frameOmega=wrap(theta-state(1))/p(1);valid=true;
    else
        next(8)=state(8)+1;
        theta=wrap(state(1)+p(1)*omega);frameOmega=omega;
        valid=next(8)<p(8);
        if ~valid,next(10)=1;fault=cast(1,'like',state);end
    end
end

if fault>0
    valid=false;mode=cast(4,'like',state);next(4)=0;next(18)=1;
elseif next(9)>.5
    if beta<=0,mode=cast(1,'like',state);
    elseif beta>=1,mode=cast(3,'like',state);
    else,mode=cast(2,'like',state);end
end
injectionTarget=state(18);
if next(9)<.5 || ~highQ || abs(omega)<=p(11)
    injectionTarget=cast(1,'like',state);
elseif beta>=1 && abs(omega)>=p(12)
    injectionTarget=cast(0,'like',state);
end
if fault==0
    next(4)=min(max(state(4)+min(max(injectionTarget-state(4),-p(10)),p(10)),0),1);
end
next(18)=injectionTarget;next(1)=theta;next(2)=omega;next(3)=beta;
y(1)=theta;y(2)=omega;y(3)=frameOmega;y(4)=cast(valid,'like',state);y(5)=beta;
y(6)=state(4);y(7)=mode;y(8)=fault;y(9)=cast(lowQ,'like',state);y(10)=cast(highQ,'like',state);
y(11)=flip;y(12)=gap;y(13)=next(6);y(14)=next(7);y(15)=next(8);y(16)=correction;y(17)=branch;
end
function angle=wrap(angle)
angle=atan2(sin(angle),cos(angle));
end
