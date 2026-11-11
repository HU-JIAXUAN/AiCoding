function [phase,magnitude,responseDQ,voltageStep,quality,nextFilter,usedAverage]=hfi_demodulate(current,oldCurrent,olderCurrent,oldVoltage,olderVoltage,oldAxis,oldScale,olderScale,active,settings,filterState,externalAverage)
%HFI_DEMODULATE Two-interval demodulation with measured applied voltages.
% current[k] closes interval u[k-1]; u[k] must NOT feed this calculation.
% settings=[Ts;Vh;inverse_average;cross_phase;min_voltage_step;max_cross_fraction;min_response;max_response;min_scale;filter_a;use_external_average].
%#codegen
phase=zeros(1,'like',current);magnitude=zeros(1,'like',current);
responseDQ=zeros(2,1,'like',current);voltageStep=zeros(1,'like',current);quality=zeros(1,'like',current);
nextFilter=zeros(2,1,'like',current);
usedAverage=zeros(1,'like',current);
if ~active || ~all(isfinite([current;oldCurrent;olderCurrent;oldVoltage;olderVoltage;oldAxis;oldScale;olderScale;filterState]))
    return;
end
if oldScale<settings(9) || olderScale<settings(9),return;end
cosine=cos(oldAxis);sine=sin(oldAxis);deltaVoltage=oldVoltage-olderVoltage;
projection=cosine*deltaVoltage(1)+sine*deltaVoltage(2);
cross=-sine*deltaVoltage(1)+cosine*deltaVoltage(2);
voltageStep=projection;
if abs(projection)<settings(5) || abs(cross)>settings(6)*abs(projection),return;end
average=settings(3);
if settings(11)>0.5
    if ~isfinite(externalAverage) || externalAverage<=0,return;end
    average=externalAverage;
end
usedAverage=average;
secondDifference=current-2*oldCurrent+olderCurrent;
response=secondDifference/(settings(1)*projection);
responseDQ=[cosine*response(1)+sine*response(2);-sine*response(1)+cosine*response(2)];
saliency=[responseDQ(1)-average;responseDQ(2)];
rotation=2*oldAxis-settings(4);rotationCos=cos(rotation);rotationSin=sin(rotation);
stationary=[rotationCos*saliency(1)-rotationSin*saliency(2);rotationSin*saliency(1)+rotationCos*saliency(2)];
nextFilter=settings(10)*filterState+(1-settings(10))*stationary;
phase=atan2(nextFilter(2),nextFilter(1));
magnitude=hypot(nextFilter(1),nextFilter(2))*settings(1)*abs(projection)/2;
quality=cast(magnitude>=settings(7) && magnitude<=settings(8),'like',current);
if quality<0.5,magnitude(:)=0;end
end
