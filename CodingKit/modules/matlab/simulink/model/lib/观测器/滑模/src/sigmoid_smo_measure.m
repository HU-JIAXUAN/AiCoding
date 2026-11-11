function [injection,currentHat,residual,phase,magnitude,active,trackerReset,fault,residualNorm]=sigmoid_smo_measure(state,current,direction,enable,reset,settings)
%SIGMOID_SMO_MEASURE Smooth current-error injection; no applied voltage input.
% State=[prior estimated current(2);previous direction;latched fault].
% Settings=[A;B;SlidingGain;Slope;MaxVoltage;MaxCurrent;MaxEstimate].
%#codegen
s=cast(settings,'like',state);injection=zeros(2,1,'like',state);currentHat=injection;residual=injection;
phase=cast(0,'like',state);magnitude=phase;active=phase;trackerReset=cast(1,'like',state);fault=phase;residualNorm=phase;
if (isfinite(reset) && reset>.5) || (isfinite(enable) && enable<.5),return;end
if ~all(isfinite(s)) || s(1)<=0 || s(1)>1 || any(s(2:7)<=0) || ...
        ~isfinite(enable) || ~isfinite(reset) || ~isfinite(direction) || (direction~=0 && abs(direction)~=1)
    fault=cast(2,'like',state);return;
end
if ~all(isfinite(state)),fault=cast(3,'like',state);return;end
if state(4)>0,fault=state(4);return;end
if direction==0 || direction~=state(3),return;end
i=cast(current,'like',state);
if ~all(isfinite(i)) || any(abs(i)>s(6)),fault=cast(1,'like',state);return;end
currentHat=state(1:2);residual=currentHat-i;
injection=s(3)*tanh((s(4)/2)*residual);
phase=atan2(-direction*injection(1),direction*injection(2));
magnitude=hypot(injection(1),injection(2));residualNorm=hypot(residual(1),residual(2));
active=cast(1,'like',state);trackerReset=cast(0,'like',state);
end
