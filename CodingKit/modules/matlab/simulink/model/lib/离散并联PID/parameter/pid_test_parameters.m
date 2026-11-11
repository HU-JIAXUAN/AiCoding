function cfg=pid_test_parameters()
%PID_TEST_PARAMETERS Editable default command and enable/reset fixture.
cfg.Duration=3;cfg.CommandInitial=0;cfg.CommandHigh=2;cfg.CommandFinal=0.2;
cfg.CommandTime=0.1;cfg.ReleaseTime=1;cfg.Enable=true;cfg.Reset=false;
end
