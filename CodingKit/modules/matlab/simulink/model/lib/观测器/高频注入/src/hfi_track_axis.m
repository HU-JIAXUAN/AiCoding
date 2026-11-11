function [theta,omega,valid,next]=hfi_track_axis(tracker,state,quality,active,settings)
%HFI_TRACK_AXIS Unwrap doubled PLL phase without introducing pi jumps.
% tracker=[theta_double;omega_double;phase_error_double;pll_valid].
% state=[last_continuous_axis;last_tracker_phase]. No polarity is identified.
% settings=[initial_axis;initial_tracker_phase;max_electrical_speed].
%#codegen
theta=settings(1);omega=zeros(1,'like',state);valid=zeros(1,'like',state);
next=[settings(1);settings(2)];
if ~active,return;end
delta=0.5*atan2(sin(tracker(1)-state(2)),cos(tracker(1)-state(2)));
theta=atan2(sin(state(1)+delta),cos(state(1)+delta));
omega=0.5*tracker(2);next=[theta;tracker(1)];
valid=cast(tracker(4)>0.5 && quality>0.5 && abs(omega)<=settings(3),'like',state);
end
