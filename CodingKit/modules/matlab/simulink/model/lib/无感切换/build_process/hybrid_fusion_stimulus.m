function stimulus=hybrid_fusion_stimulus(test,cfg)
%HYBRID_FUSION_STIMULUS Two analytic estimates plus independent truth for scoring.
t=(0:round(test.Duration/cfg.Ts))'*cfg.Ts;
rise=min(max((t-test.RampStart)/(test.RampEnd-test.RampStart),0),1);
fall=min(max((t-test.DownStart)/(test.DownEnd-test.DownStart),0),1);
omega=test.InitialOmega+(test.PeakOmega-test.InitialOmega)*(rise-fall);
theta=test.InitialAngle+cumtrapz(t,omega);
low=theta+test.LowPhaseBias+pi*test.ReturnPi*double(t>=test.ReturnTime);
high=theta+test.HighPhaseBias;
stimulus.time=t;
stimulus.signals.values=[wrap(low),omega,double(abs(omega)<=cfg.LowMaxOmega), ...
    wrap(high),omega,double(abs(omega)>=cfg.HighMinOmega), ...
    test.Enable*ones(size(t)),test.Reset*ones(size(t)),wrap(theta),omega];
stimulus.signals.dimensions=10;
end
function result=wrap(angle)
result=atan2(sin(angle),cos(angle));
end
