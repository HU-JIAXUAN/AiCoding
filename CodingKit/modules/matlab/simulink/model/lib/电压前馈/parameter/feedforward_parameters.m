function cfg = feedforward_parameters()
%FEEDFORWARD_PARAMETERS Applied at one sum before final voltage limitation.
cfg.Enable = 0;
cfg.ParameterScale = 1;  % multiply model Ld/Lq/Flux for mismatch experiments
end
