function pll=sigmoid_smo_pll_parameters(cfg)
%SIGMOID_SMO_PLL_PARAMETERS Local PLL settings aligned to this SMO instance.
if nargin==0,cfg=sigmoid_smo_parameters();end
pll=angle_tracking_parameters();pll.Ts=cfg.Ts;pll.MinMagnitude=cfg.MinEmf;
end
