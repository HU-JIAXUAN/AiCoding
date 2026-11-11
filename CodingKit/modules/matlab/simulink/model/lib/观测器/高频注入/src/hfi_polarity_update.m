function next=hfi_polarity_update(state,current,voltage,axis,omega,axisValid,saliencyQualified,active,settings)
%HFI_POLARITY_UPDATE Stop HFI, apply equal dual pulses and compare decay peaks.
% state=[stage,ticks,total,axisCount,decayCount,frozenAxis,peakP,peakN,doseP,
%        doseN,crossDose,baselineP,baselineN,flip,known,fault,speedLP,uOld(2)].
% stages0init1wait2settle3positive4decay5negative6decay7track8fault.
% Current[k] closes stored actual voltage[k-1], including execution delay.
%#codegen
next=state;
if ~active,next(:)=0;return;end
stage=state(1);
if stage==8,return;end
if ~all(isfinite([current;voltage;axis;omega;axisValid;saliencyQualified]))
    next(1)=8;next(16)=7;return;
end
if stage<7 && hypot(current(1),current(2))>settings(11)
    next(1)=8;next(16)=1;return;
end
next(17)=settings(19)*state(17)+(1-settings(19))*omega;
next(18:19)=voltage;
if stage>=2 && saliencyQualified<.5,next(1)=8;next(16)=6;return;end
if stage==7,return;end
next(3)=state(3)+1;next(2)=state(2)+1;
if stage==0,next(1)=1;next(2)=0;return;end
if next(3)>settings(9),next(1)=8;next(16)=8;return;end
cosine=cos(state(6));sine=sin(state(6));id=cosine*current(1)+sine*current(2);
u=cosine*state(18)+sine*state(19);uq=-sine*state(18)+cosine*state(19);
if stage==3 || stage==4
    next(7)=max(state(7),id-state(12));
    if abs(u)>=settings(18)
        if u<0,next(1)=8;next(16)=4;return;end
        next(9)=state(9)+settings(1)*u;next(11)=state(11)+settings(1)*abs(uq);
    end
elseif stage==5 || stage==6
    next(8)=max(state(8),state(13)-id);
    if abs(u)>=settings(18)
        if u>0,next(1)=8;next(16)=4;return;end
        next(10)=state(10)-settings(1)*u;next(11)=state(11)+settings(1)*abs(uq);
    end
end
switch stage
    case 1
        good=axisValid>.5 && saliencyQualified>.5 && abs(next(17))<=settings(12);
        if good,next(4)=state(4)+1;else,next(4)=0;end
        if next(4)>=settings(4)
            next(1)=2;next(2)=0;next(5)=0;next(6)=axis;
        elseif next(2)>=settings(7),next(1)=8;next(16)=2;
        end
    case {2,4,6}
        if hypot(current(1),current(2))<=settings(10),next(5)=state(5)+1;else,next(5)=0;end
        if next(2)>=settings(5) && next(5)>=settings(6)
            next(2)=0;next(5)=0;
            if stage==2,next(1)=3;next(12)=id;
            elseif stage==4,next(1)=5;next(13)=id;
            else
                meanDose=.5*(next(9)+next(10));mismatch=abs(next(9)-next(10))/max(meanDose,eps);
                crossFraction=next(11)/max(next(9)+next(10),eps);
                difference=next(7)-next(8);relative=abs(difference)/max(.5*(next(7)+next(8)),eps);
                if min(next(9),next(10))<settings(15) || mismatch>settings(16) || crossFraction>settings(17)
                    next(1)=8;next(16)=4;
                elseif abs(difference)<settings(13) || relative<settings(14)
                    next(1)=8;next(16)=5;
                else
                    next(1)=7;next(14)=cast(difference<0,'like',state);next(15)=1;
                end
            end
        elseif next(2)>=settings(8),next(1)=8;next(16)=3;
        end
    case {3,5}
        if next(2)>=settings(3),next(1)=stage+1;next(2)=0;next(5)=0;end
end
end
