function cfg=pmsm_hf_parameters()
%PMSM_HF_PARAMETERS Synthetic salient PMSM with magnet-biased d saturation.
% This is an illustrative differential-inductance model, not identified data.
cfg=pmsm_parameters();
cfg.Lq=1.5e-3;
cfg.SaturationDepth=0.25;
cfg.SaturationCurrent=1;
cfg.CrossInductance=0;
cfg.MechanicalEnabled=1;
cfg=refresh_pmsm_hf_parameters(cfg);
end
