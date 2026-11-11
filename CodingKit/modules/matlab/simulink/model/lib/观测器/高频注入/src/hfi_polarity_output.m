function output=hfi_polarity_output(state,saliencyQualified,active,settings)
%HFI_POLARITY_OUTPUT State-only requests; external wrap/validity use HFI lock.
% [pulseAB(2),hfiScale,thetaOffset,ready,known,flip,stage,peaks(2),difference,
%  doses(2),fault,frozenAxis,speedLP]. Positive d saturation lowers Ld.
%#codegen
output=zeros(16,1,'like',state);
if ~active || ~isfinite(saliencyQualified),return;end
stage=state(1);if stage==0,stage=1;end
if (stage==1 || stage==7) && saliencyQualified>.5,output(3)=1;end
amplitude=zeros(1,'like',state);
if stage==3,amplitude=settings(2);elseif stage==5,amplitude=-settings(2);end
output(1:2)=amplitude*[cos(state(6));sin(state(6))];
output(4)=pi*state(14);
output(5)=cast(stage==7 && state(15)>.5 && saliencyQualified>.5,'like',state);
output(6)=state(15);output(7)=state(14);output(8)=stage;
output(9:10)=state(7:8);output(11)=state(7)-state(8);output(12:13)=state(9:10);
output(14)=state(16);output(15)=state(6);output(16)=state(17);
end
