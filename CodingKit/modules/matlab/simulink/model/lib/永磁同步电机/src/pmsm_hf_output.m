function signals=pmsm_hf_output(state,settings)
%PMSM_HF_OUTPUT State-only sensor outputs, with no applied-voltage feedthrough.
% Reuse the identical magnetic equations; discard the dummy-voltage derivative.
%#codegen
[~,signals]=pmsm_hf_dynamics(state,zeros(2,1,'like',state),zeros(1,'like',state),settings);
end
