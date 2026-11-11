function cfg = svpwm_test_parameters()
%SVPWM_TEST_PARAMETERS Reference vectors for the linked SVPWM comparison.
cfg.Ts = 1e-4;                       % s, held stimulus interval
vdc = [48; 24];                     % V
angle = pi/6 + (0:5)'*pi/3;         % rad, interior of each sector
radius = 0.4*vdc;
unit = [cos(angle),sin(angle)];
inputs = [radius(1)*unit,repmat(vdc(1),6,1); ...
          radius(2)*unit,repmat(vdc(2),6,1); ...
          0,0,vdc(1); vdc(1),0,vdc(1)];
time = (0:size(inputs,1)-1)'*cfg.Ts;
cfg.Stimulus = [time,inputs];
cfg.StopTime = time(end);
end
