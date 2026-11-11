function next=hfi_hybrid_direction(previous,omega,enable,reset,settings)
%HFI_HYBRID_DIRECTION Hold direction near zero; consume estimated speed only.
% Settings: explicitly configured initial direction and electrical-speed threshold.
%#codegen
next=previous;
if enable<.5 || reset>.5,next=settings(1);return;end
if isfinite(omega) && abs(omega)>=settings(2)
    if omega>0,next=cast(1,'like',previous);else,next=cast(-1,'like',previous);end
end
end
