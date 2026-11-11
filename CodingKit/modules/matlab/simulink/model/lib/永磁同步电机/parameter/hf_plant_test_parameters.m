function cfg=hf_plant_test_parameters()
%HF_PLANT_TEST_PARAMETERS Sampled voltage pulses applied to a continuous plant.
cfg.Ts=50e-6;cfg.PlantStep=cfg.Ts/20;cfg.Duration=0.1;
cfg.PulseVoltage=4;cfg.PositiveStart=0.02;cfg.NegativeStart=0.065;cfg.PulseWidth=1e-3;
cfg.VoltageAxis=0;cfg.LoadTorque=0;
end
