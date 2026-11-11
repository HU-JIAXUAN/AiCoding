function report=run_sensorless_process_validation()
%RUN_SENSORLESS_PROCESS_VALIDATION Finite-difference process/measurement Jacobians.
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'src'),fullfile(module,'parameter'));
cfg=pmsm_sensorless_parameters();settings=[cfg.Ts;cfg.Rs;cfg.L;cfg.Flux];
states=[-1,2,600,3.13;2,-1,-600,-3.13;0,0,0,.5;1,1,2000,pi-.1-1e-9].';
voltages=[10,-5;-5,10;0,0;20,10].';steps=[1e-5;1e-5;.01;1e-6];checks=struct([]);
for k=1:size(states,2)
    state=states(:,k);voltage=voltages(:,k);[next,a]=pmsm_sensorless_step(state,voltage,settings);
    [measurement,h]=pmsm_sensorless_measurement(state);numericA=zeros(4);numericH=zeros(2,4);
    for j=1:4
        delta=zeros(4,1);delta(j)=steps(j);
        plus=pmsm_sensorless_step(state+delta,voltage,settings);minus=pmsm_sensorless_step(state-delta,voltage,settings);
        difference=plus-minus;difference(4)=atan2(sin(plus(4)-minus(4)),cos(plus(4)-minus(4)));
        numericA(:,j)=difference/(2*steps(j));
        numericH(:,j)=(pmsm_sensorless_measurement(state+delta)-pmsm_sensorless_measurement(state-delta))/(2*steps(j));
    end
    errorA=max(abs(a-numericA),[],'all');errorH=max(abs(h-numericH),[],'all');
    assert(errorA<1e-6 && errorH<1e-8 && isequal(measurement,state(1:2)));
    assert(next(3)==state(3) && abs(next(4))<=pi);
    item=struct('state',state,'voltage',voltage,'step',settings,'maximum_process_jacobian_error',errorA, ...
        'maximum_measurement_jacobian_error',errorH,'status','passed');
    if k==1,checks=item;else,checks(k)=item;end
end
report=struct('release',version('-release'),'matlabroot',matlabroot,'status','passed', ...
    'kind','pure M process and linear-measurement checks; not physical motor MIL', ...
    'process_jacobian_points',4,'measurement_jacobian_points',4,'method','central differences; circular angle difference', ...
    'checks',checks);
handle=fopen(fullfile(module,'waveform_analysis/sensorless_process_metrics.json'),'w');fwrite(handle,jsonencode(report,PrettyPrint=true));fclose(handle);
end
