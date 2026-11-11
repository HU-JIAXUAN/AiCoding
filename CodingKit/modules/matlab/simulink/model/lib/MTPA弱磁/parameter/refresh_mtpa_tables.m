function cfg = refresh_mtpa_tables(cfg,motor)
%REFRESH_MTPA_TABLES Validate parameters and rebuild the monotonic MTPA map.
%   Supports constant linear parameters with Lq>=Ld, including Lq==Ld.
assert(all(isfinite([motor.Rs,motor.Ld,motor.Lq,motor.Flux,motor.PolePairs])));
assert(motor.Rs>0&&motor.Ld>0&&motor.Lq>=motor.Ld&&motor.Flux>0);
assert(motor.PolePairs>=1&&mod(motor.PolePairs,1)==0);
assert(cfg.CurrentMax>0&&cfg.IdMin>=-cfg.CurrentMax&&cfg.IdMin<=0);
assert(cfg.VoltageReserve>0&&cfg.VoltageReserve<=1&&cfg.MinDuty>=0&&cfg.MinDuty<0.5);
assert(isfinite(cfg.FwVoltageMargin)&&cfg.FwVoltageMargin>=0);
assert(cfg.FwTs>0&&cfg.FilterTau>=0&&cfg.FwKi>=0&&cfg.IdSlew>0);
assert(cfg.SpeedTs>0&&cfg.SpeedKaw>=0);
assert(cfg.TablePoints>=33&&mod(cfg.TablePoints,1)==0);
assert(ismember(cfg.MtpaEnable,[0,1])&&ismember(cfg.FwEnable,[0,1]));
current=linspace(0,cfg.CurrentMax,cfg.TablePoints);
delta=motor.Lq-motor.Ld;
% Rationalized expression avoids cancellation when saliency tends to zero.
id=-2*delta*current.^2./(motor.Flux+sqrt(motor.Flux^2+8*delta^2*current.^2));
if ~cfg.MtpaEnable,id(:)=0;end
id=max(id,cfg.IdMin); % constrained MTPA if the declared negative-id bound binds
iq=sqrt(max(0,current.^2-id.^2));
torque=1.5*motor.PolePairs*(motor.Flux-delta*id).*iq;
assert(all(diff(torque)>0),'Torque map must be strictly monotonic.');
cfg.IdTable=id;cfg.TorqueGrid=torque;cfg.MaxTorque=torque(end);
cfg.Kt=1.5*motor.PolePairs*motor.Flux;
cfg.VoltageFactor=cfg.VoltageReserve*(1-2*cfg.MinDuty)/sqrt(3);
cfg.FilterAlpha=cfg.FilterTau/(cfg.FilterTau+cfg.FwTs);
end
