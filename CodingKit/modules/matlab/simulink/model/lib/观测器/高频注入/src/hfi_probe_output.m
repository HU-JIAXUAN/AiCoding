function output=hfi_probe_output(state,active,settings)
%HFI_PROBE_OUTPUT Causal excitation plus measured-tensor qualification.
% outputs=[requestAB(2),axis,ratio,qualified,done,inverseAverage,tensor(3),residual,count,fault,eigenMin,eigenMax,qualityCode].
% qualityCode:0 collecting,1 qualified,2 weak voltage,3 eigen range,4 saliency,
%             5 fit residual,6 asymmetry,7 input/current fault.
%#codegen
output=zeros(16,1,'like',state);
if ~active,return;end
done=state(1)>=settings(3)+settings(4) || state(19)>0;
output(6)=cast(done,'like',state);output(12)=state(2);output(13)=state(19);
if state(19)>0,output(16)=7;return;end
if ~done
    phase=mod(state(1),4);axis=settings(13);amplitude=settings(2);
    if phase>=2,axis=axis+pi/2;end
    if mod(phase,2)==1,amplitude=-amplitude;end
    output(1:2)=amplitude*[cos(axis);sin(axis)];
end
if state(2)<4,return;end
xx11=state(11);xx12=state(12);xx22=state(13);determinant=xx11*xx22-xx12*xx12;
if determinant<=0
    if done,output(16)=2;end
    return;
end
a11=(state(14)*xx22-state(15)*xx12)/determinant;
a12=(state(15)*xx11-state(14)*xx12)/determinant;
a21=(state(16)*xx22-state(17)*xx12)/determinant;
a22=(state(17)*xx11-state(16)*xx12)/determinant;
cross=0.5*(a12+a21);average=0.5*(a11+a22);
radius=hypot(0.5*(a11-a22),cross);eigenMin=average-radius;eigenMax=average+radius;
ratio=radius/max(abs(average),eps);
angle=0.5*atan2(2*cross,a11-a22)-0.5*settings(14);
residualEnergy=max(state(18)-(a11*state(14)+a12*state(15)+a21*state(16)+a22*state(17)),0);
residual=sqrt(residualEnergy/max(state(18),eps));
asymmetry=sqrt(2)*abs(a12-a21)/max(abs(a11+a22),eps);
voltageMinEigen=0.5*(xx11+xx22)-hypot(0.5*(xx11-xx22),xx12);
voltageRms=sqrt(max(voltageMinEigen,0)/state(2));
output(3)=atan2(sin(angle),cos(angle));output(4)=ratio;output(7)=average;
output(8:10)=[a11;cross;a22];output(11)=residual;output(14:15)=[eigenMin;eigenMax];
if ~done,return;end
code=1;
if voltageRms<settings(11),code=2;
elseif eigenMin<settings(7) || eigenMax>settings(8),code=3;
elseif ratio<settings(5) || ratio>settings(6),code=4;
elseif residual>settings(9),code=5;
elseif asymmetry>settings(10),code=6;
end
output(16)=code;output(5)=cast(code==1,'like',state);
end
