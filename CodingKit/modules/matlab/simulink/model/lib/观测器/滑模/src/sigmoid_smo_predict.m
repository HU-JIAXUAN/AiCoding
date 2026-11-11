function next=sigmoid_smo_predict(state,voltage,direction,enable,reset,active,injection,immediateFault,settings)
%SIGMOID_SMO_PREDICT Advance current state with this interval's voltage only.
%#codegen
next=zeros(4,1,'like',state);s=cast(settings,'like',state);
if (isfinite(reset) && reset>.5) || (isfinite(enable) && enable<.5),return;end
if immediateFault>0,next(4)=immediateFault;return;end
if state(4)>0,next(4)=state(4);return;end
if direction==0,return;end
next(3)=cast(direction,'like',state);
if active<.5,return;end
u=cast(voltage,'like',state);
if ~all(isfinite(u)) || any(abs(u)>s(5)),next(4)=1;return;end
prediction=s(1)*state(1:2)+s(2)*(u-injection);
if ~all(isfinite(prediction)) || any(abs(prediction)>s(7)),next(4)=3;return;end
next(1:2)=prediction;
end
