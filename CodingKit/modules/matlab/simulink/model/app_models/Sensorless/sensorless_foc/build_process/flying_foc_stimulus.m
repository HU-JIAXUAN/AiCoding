function stimulus=flying_foc_stimulus(p)
%FLYING_FOC_STIMULUS Columns: speedM, loadNm, enable, reset, observerEnable.
c=p.experimentCfg;t=(0:p.currentCfg.Ts:c.Duration)';
values=zeros(numel(t),5);values(:,1)=c.SpeedReference;
values(:,2)=c.LoadTorque*(t>=c.LoadTime);values(:,3)=c.Enable;
values(t>=c.DisableTime & t<c.ReenableTime,3)=0;
values(:,4)=double(t>=c.ResetTime & t<c.ResetTime+c.ResetDuration);
values(:,5)=double(~(t>=c.ObserverOffTime & t<c.ObserverOnTime));
stimulus=struct('time',t,'signals',struct('values',values,'dimensions',5));
end
