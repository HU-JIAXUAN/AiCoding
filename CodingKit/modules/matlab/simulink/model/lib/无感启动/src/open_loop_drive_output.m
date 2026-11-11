function y=open_loop_drive_output(state,enable,reset,s)
%OPEN_LOOP_DRIVE_OUTPUT Held-state output; measured voltage never feeds through.
% y: theta,frequency,amplitude,pwm_enable,stage,fault,elapsed,voltage_limited.
%#codegen
y=[state(3);state(4);state(5);cast(0,'like',state);state(1);state(6);state(2)*s(1);state(8)];
if ~isfinite(enable)||~isfinite(reset)||enable~=1||reset~=0
    y(1)=s(18);y(2:8)=0;return
end
if state(1)==2||state(1)==3,y(4)=1;else,y(2:3)=0;end
end
