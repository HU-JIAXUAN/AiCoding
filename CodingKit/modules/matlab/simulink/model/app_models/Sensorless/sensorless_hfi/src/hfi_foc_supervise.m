function next=hfi_foc_supervise(state,positionValid,current,enable,reset,settings)
%HFI_FOC_SUPERVISE App-specific held fault; no plant angle or speed is consumed.
% state=[everAcquired;lossSamples;faultCode], fault1=current, fault2=position.
% Output is a separate UnitDelay; this function only prepares the next sample.
%#codegen
next=state;
if enable<.5 || reset>.5,next(:)=0;return;end
if state(3)>.5,return;end
if ~all(isfinite([positionValid;current])) || hypot(current(1),current(2))>settings(1)
    next(3)=1;return;
end
if positionValid>.5,next(1)=1;next(2)=0;
elseif state(1)>.5
    next(2)=state(2)+1;
    if next(2)>=settings(2),next(3)=2;end
end
end
