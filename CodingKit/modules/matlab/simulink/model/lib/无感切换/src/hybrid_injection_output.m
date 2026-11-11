function scale=hybrid_injection_output(state,enable,reset)
%HYBRID_INJECTION_OUTPUT State-only scheduler avoids an observer algebraic loop.
%#codegen
scale=cast(0,'like',state);
if isfinite(enable) && isfinite(reset) && enable>.5 && reset<.5 && state(10)==0
    scale=state(4);
end
end
