function stimulus=open_loop_app_stimulus(p)
%OPEN_LOOP_APP_STIMULUS [electrical Hz, enable, reset, signed load Nm, bus V].
time=(0:p.currentCfg.Ts:p.experimentCfg.Duration)';values=zeros(numel(time),5);
values(:,1)=p.experimentCfg.Frequency;values(:,2)=1;
values(time>=p.experimentCfg.LoadTime,4)=p.experimentCfg.LoadTorque;values(:,5)=p.powerCfg.Vdc;
stimulus=struct('time',time,'signals',struct('values',values,'dimensions',5));
end
