function cfg=emf_parameters(kind)
%EMF_PARAMETERS SI defaults for linear SPMSM or extended-EMF IPMSM observers.
if nargin==0,kind='ipmsm';end
assert(ismember(kind,{'spmsm','ipmsm'}));
cfg.Ts=50e-6;cfg.Rs=0.5;cfg.Ld=1e-3;cfg.Lq=1.2e-3;
if strcmp(kind,'spmsm'),cfg.Lq=cfg.Ld;end
cfg.Flux=0.035; % Wb, fixture parameter; not needed in the state observer
cfg.PolePairs=4;
cfg.BandwidthHz=300; % nominal repeated continuous observer poles
cfg.MinEmf=1;       % V, PLL magnitude qualification
cfg.MinOmega=30;    % signed-direction electrical rad/s qualification
cfg.MaxResidual=1.5;% A, estimated-minus-measured current norm
end
