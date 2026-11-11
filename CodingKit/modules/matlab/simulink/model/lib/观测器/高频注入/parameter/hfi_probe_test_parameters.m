function cfg=hfi_probe_test_parameters()
%HFI_PROBE_TEST_PARAMETERS Compose the shared physical/ADC test fixture locally.
cfg=hfi_test_parameters();cfg.Duration=0.05;
end
