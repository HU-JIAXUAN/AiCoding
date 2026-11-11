function stimulus=hfi_hybrid_stimulus(cfg)
%HFI_HYBRID_STIMULUS Original ten columns plus online high-qualification gate.
stimulus=hfi_foc_stimulus(cfg);t=stimulus.time;
stimulus.signals.values(t>=cfg.ReturnTime,8)=cfg.ReturnSpeed;
stimulus.signals.values(:,11)=cfg.HighQualificationGate;
stimulus.signals.dimensions=11;
end
