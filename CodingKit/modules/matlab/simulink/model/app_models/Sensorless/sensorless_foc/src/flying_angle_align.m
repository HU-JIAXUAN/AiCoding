function [theta,voltage]=flying_angle_align(rawTheta,omega,measuredVoltage,age)
%FLYING_ANGLE_ALIGN First-order age compensation of completed-interval sample.
%#codegen
advance=omega*age;theta=atan2(sin(rawTheta+advance),cos(rawTheta+advance));
c=cos(advance);s=sin(advance);
voltage=[c*measuredVoltage(1)-s*measuredVoltage(2); ...
    s*measuredVoltage(1)+c*measuredVoltage(2)];
end
