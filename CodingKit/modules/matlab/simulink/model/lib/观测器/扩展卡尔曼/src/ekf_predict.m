function next=ekf_predict(posterior,voltage,enable,reset,settings)
%EKF_PREDICT Advance posterior and covariance to the next current-measurement time.
%#codegen
next=posterior;s=cast(settings,'like',posterior);
if enable<.5 || reset>.5 || posterior(26)>0 || posterior(27)<.5,return;end
applied=cast(voltage,'like',posterior);
if ~all(isfinite(applied)) || any(abs(applied)>s(27))
    next(26)=1;next(21)=0;next(3)=0;return;
end
if abs(posterior(3))>s(25)
    next(26)=3;next(21)=0;next(3)=0;return;
end
[state,a]=pmsm_sensorless_step(posterior(1:4),applied,s(1:4));
p=reshape(posterior(5:20),4,4);p=a*p*a'+diag(s(11:14));p=.5*(p+p');
if ~all(isfinite(state)) || ~all(isfinite(p),'all') || any(diag(p)<0)
    next(26)=3;next(21)=0;next(3)=0;return;
end
next(1:4)=state;next(5:20)=p(:);
end
