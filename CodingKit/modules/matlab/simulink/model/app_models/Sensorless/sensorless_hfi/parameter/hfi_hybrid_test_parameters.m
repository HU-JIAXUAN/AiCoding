function cfg=hfi_hybrid_test_parameters()
%HFI_HYBRID_TEST_PARAMETERS Physical HFI/EEMF speed excursion and fault controls.
cfg=hfi_foc_test_parameters();
cfg.Duration=2.3;cfg.SpeedReference=25;cfg.CommandTime=.14;
cfg.ReturnTime=1.4;cfg.ReturnSpeed=8;
cfg.LoadTime=.9;cfg.LoadTorque=.02;
cfg.HighQualificationGate=1;
end
