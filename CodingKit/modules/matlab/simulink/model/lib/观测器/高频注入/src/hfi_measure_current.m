function measured=hfi_measure_current(raw,noise,settings)
%HFI_MEASURE_CURRENT Three phase ADC fixture: offset, noise, clipping, rounding.
% settings=[offset_a;offset_b;offset_c;resolution_A;range_A].
%#codegen
measured=min(max(raw+noise+settings(1:3),-settings(5)),settings(5));
if settings(4)>0
    measured=round(measured/settings(4))*settings(4);
end
end
