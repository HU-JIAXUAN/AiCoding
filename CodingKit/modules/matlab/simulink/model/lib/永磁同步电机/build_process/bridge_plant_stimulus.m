function stimulus=bridge_plant_stimulus(p)
%BRIDGE_PLANT_STIMULUS Five held columns: dutyABC, bridge mode, load torque.
if nargin==0,p=bridge_test_parameters();end
cfg=p.bridgeTestCfg;step=p.bridgeCfg.Ts;
assert(isfinite(cfg.Duration) && cfg.Duration>0 && abs(cfg.Duration/step-round(cfg.Duration/step))<1e-8);
assert(numel(cfg.ModeTimes)==numel(cfg.ModeValues) && cfg.ModeTimes(1)==0);
assert(all(isfinite(cfg.ModeTimes)) && all(diff(cfg.ModeTimes)>0) && all(cfg.ModeTimes<=cfg.Duration));
assert(all(ismember(cfg.ModeValues,[0 1 2])));
assert(all(abs(cfg.ModeTimes/step-round(cfg.ModeTimes/step))<1e-8));
assert(numel(cfg.Duty)==3 && all(isfinite(cfg.Duty)) && all(cfg.Duty>=0 & cfg.Duty<=1));
assert(isscalar(cfg.LoadTorque) && isfinite(cfg.LoadTorque));
count=round(cfg.Duration/step)+1;time=(0:count-1)'*step;
values=[repmat(reshape(cfg.Duty,1,3),count,1),zeros(count,1),repmat(cfg.LoadTorque,count,1)];
for k=1:numel(cfg.ModeTimes),values(round(cfg.ModeTimes(k)/step)+1:end,4)=cfg.ModeValues(k);end
stimulus=struct('time',time,'signals',struct('values',values,'dimensions',5));
end
