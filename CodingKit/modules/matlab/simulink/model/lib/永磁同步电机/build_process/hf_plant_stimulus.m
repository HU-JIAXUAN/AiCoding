function stimulus=hf_plant_stimulus(cfg)
%HF_PLANT_STIMULUS Make zero-order-held positive/negative voltage pulses.
sample=(0:round(cfg.Duration/cfg.Ts))';time=sample*cfg.Ts;
positive=sample>=round(cfg.PositiveStart/cfg.Ts) & sample<round((cfg.PositiveStart+cfg.PulseWidth)/cfg.Ts);
negative=sample>=round(cfg.NegativeStart/cfg.Ts) & sample<round((cfg.NegativeStart+cfg.PulseWidth)/cfg.Ts);
voltage=cfg.PulseVoltage*(double(positive)-double(negative));
values=[cos(cfg.VoltageAxis)*voltage,sin(cfg.VoltageAxis)*voltage,cfg.LoadTorque*ones(size(time))];
stimulus=struct('time',time,'signals',struct('values',values,'dimensions',3));
end
