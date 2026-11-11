function cfg=refresh_pmsm_bridge_parameters(cfg)
%REFRESH_PMSM_BRIDGE_PARAMETERS Validate SI settings and pack solver constants.
names={'Ts','Rs','Ld','Lq','Flux','PolePairs','J','B','Vdc','DiodeVf','DiodeRon', ...
    'MechanicalEnabled','CurrentTolerance','VoltageTolerance','MaxCurrent','MaxSpeed','MaxAngleStep'};
values=zeros(numel(names),1);
for k=1:numel(names)
    value=cfg.(names{k});assert(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value));
    value=double(value);cfg.(names{k})=value;values(k)=value;
end
assert(all(values([1 3 4 6 7 9 13 14 15 16 17])>0));
assert(all(values([2 5 8 10 11])>=0));
assert(cfg.PolePairs==fix(cfg.PolePairs));
assert(ismember(cfg.MechanicalEnabled,[0 1]));
assert(cfg.Ts*cfg.B/cfg.J<1 && cfg.MaxAngleStep<=0.1);
for name={'Id0','Iq0','Speed0','Position0'}
    value=cfg.(name{1});assert(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value));
    cfg.(name{1})=double(value);
end
theta=cfg.PolePairs*cfg.Position0;
cfg.State0=[cos(theta)*cfg.Id0-sin(theta)*cfg.Iq0; ...
    sin(theta)*cfg.Id0+cos(theta)*cfg.Iq0;cfg.Speed0;cfg.Position0];
assert(max(abs(cfg.State0(1:2)))<=cfg.MaxCurrent && abs(cfg.Speed0)<=cfg.MaxSpeed);
assert(abs(cfg.PolePairs*cfg.Speed0*cfg.Ts)<=cfg.MaxAngleStep);
cfg.Vector=values;
end
