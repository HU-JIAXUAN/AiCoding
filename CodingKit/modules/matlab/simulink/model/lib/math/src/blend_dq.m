function reference=blend_dq(startCurrent,closedCurrent,thetaStart,thetaControl,beta,enable,reset)
%#codegen
%BLEND_DQ Mix two current references after transforming to a common frame.
reference=zeros(2,1,'like',startCurrent);
if enable<0.5 || reset>0.5,return,end
delta=cast(thetaStart-thetaControl,'like',startCurrent);
fraction=min(max(cast(beta,'like',startCurrent),0),1);
rotation=[cos(delta),-sin(delta);sin(delta),cos(delta)];
start=[startCurrent(1);startCurrent(2)];
closed=cast([closedCurrent(1);closedCurrent(2)],'like',startCurrent);
reference=(1-fraction)*(rotation*start)+fraction*closed;
end
