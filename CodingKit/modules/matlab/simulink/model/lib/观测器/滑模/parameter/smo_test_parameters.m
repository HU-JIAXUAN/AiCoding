function cfg=smo_test_parameters()
%SMO_TEST_PARAMETERS Default independent analytic SPMSM fixture.
cfg.Duration=0.3;cfg.ElectricalSpeed=200;cfg.InitialAngle=0.4;cfg.Iq=2;
cfg.Enable=1;cfg.Reset=0;cfg.Direction=[]; % [] follows analytic speed sign
end
