function y=mras_output(state,direction,enable,reset,s)
%MRAS_OUTPUT State-only observer outputs; voltage is consumed by next-state only.
% Diagnostics describe the previous processed measurement (one Ts old).
%#codegen
y=zeros(16,1,'like',state);
if ~all(isfinite(s)) || s(1)<=0 || s(3)<=0 || s(4)<=0 || ...
        ~isfinite(enable) || ~isfinite(reset) || ~isfinite(direction) || ...
        (direction~=0 && abs(direction)~=1)
    y(15)=2;return;
end
y(1)=s(9);
if enable<.5 || reset>.5 || direction==0 || direction~=state(12),return;end
y(1)=state(1);y(2)=state(3);
y(3)=double(state(11)>=s(17) && state(20)==0);
y(4:5)=state(13:14);y(6:7)=state(4:5);y(8:9)=state(15:16);
y(10:11)=state(17:18);y(12)=state(19);y(13)=state(11);
y(14)=state(2);y(15)=state(20);y(16)=state(21);
end
