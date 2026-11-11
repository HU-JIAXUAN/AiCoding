function next=hfi_probe_update(state,current,voltage,active,settings)
%HFI_PROBE_UPDATE Fit actual interval voltage changes to second current changes.
% state=[tick,count,i1(2),i2(2),u1(2),u2(2),XX11,XX12,XX22,YX(4),YY,fault].
% i[k] closes u[k-1]; current applied u[k] is stored ONLY for the next sample.
% The completed snapshot is held until disable/reset, not a running protection.
%#codegen
next=state;
if ~active,next(:)=0;return;end
total=settings(3)+settings(4);
if state(1)>=total || state(19)>0,return;end
if ~all(isfinite([current;voltage]))
    next(19)=2;return;
end
if hypot(current(1),current(2))>settings(12)
    next(19)=1;return;
end
if state(1)>=settings(3)
    x=state(7:8)-state(9:10);
    y=(current-2*state(3:4)+state(5:6))/settings(1);
    next(2)=state(2)+1;
    next(11)=state(11)+x(1)*x(1);next(12)=state(12)+x(1)*x(2);next(13)=state(13)+x(2)*x(2);
    next(14)=state(14)+y(1)*x(1);next(15)=state(15)+y(1)*x(2);
    next(16)=state(16)+y(2)*x(1);next(17)=state(17)+y(2)*x(2);
    next(18)=state(18)+dot(y,y);
end
next(1)=state(1)+1;
next(5:6)=state(3:4);next(3:4)=current;
next(9:10)=state(7:8);next(7:8)=voltage;
end
