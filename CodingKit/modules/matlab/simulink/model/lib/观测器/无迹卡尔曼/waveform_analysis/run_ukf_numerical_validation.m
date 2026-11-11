function report=run_ukf_numerical_validation()
%RUN_UKF_NUMERICAL_VALIDATION Closed-form moments, public reference and guards.
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'build_process'));initialize_ukf_paths();
assert(strcmp(version('-release'),'2026b'));checks=struct('name',{},'state_difference',{},'scaled_covariance_difference',{},'status',{});
names={'positive','negative','wrap_positive','wrap_negative','alpha_point_two','kappa_two','unit_scales','half_time'};
for k=1:numel(names)
    cfg=ukf_parameters();x=[.2;1;600;.3];v=[10;-5];variance=[.1;.2;5;.1].^2;
    switch names{k}
        case 'negative',x(3)=-600;
        case 'wrap_positive',x(4)=pi-.001;
        case 'wrap_negative',x(4)=-pi+.001;x(3)=-600;
        case 'alpha_point_two',cfg.Alpha=.2;
        case 'kappa_two',cfg.Kappa=2;
        case 'unit_scales',cfg.StateScales=ones(4,1);
        case 'half_time',cfg.Model.Ts=cfg.Model.Ts/2;
    end
    cfg=refresh_ukf_parameters(cfg);memory=pack(x,diag(variance));actual=ukf_predict(memory,v,1,0,cfg.UnscentedSettings);
    [expectedX,expectedP]=diagonal_moments(x,v,variance,cfg);
    compare(names{k},actual,expectedX,expectedP,1e-10);
end
for k=1:2
    cfg=ukf_parameters();cfg.Beta=1;cfg=refresh_ukf_parameters(cfg);
    factor=[.1,0,0,0;.02,.2,0,0;.3,-.2,5,0;.01,.02,.001,.08];p=factor*factor';x=[.2;1;600;.3];
    if k==2,x(4)=pi-.001;end
    memory=pack(x,p);v=[10;-5];actual=ukf_predict(memory,v,1,0,cfg.UnscentedSettings);
    reference=unscentedKalmanFilter(@(state,voltage)unwrapped_process(state,voltage,cfg.Settings(1:4)), ...
        @pmsm_sensorless_measurement,x,'Alpha',1,'Beta',1,'Kappa',0);
    reference.StateCovariance=p;reference.ProcessNoise=diag(cfg.ProcessVariance);
    [expectedX,expectedP]=predict(reference,v);expectedX(4)=atan2(sin(expectedX(4)),cos(expectedX(4)));
    compare(sprintf('public_reference_beta_one_%d',k),actual,expectedX,expectedP,1e-9);
    % Raising beta by one changes only the central covariance weight by one.
    cfg.Beta=2;cfg=refresh_ukf_parameters(cfg);central=pmsm_sensorless_step(x,v,cfg.Settings(1:4))-expectedX;
    central(4)=atan2(sin(central(4)),cos(central(4)));
    actual=ukf_predict(memory,v,1,0,cfg.UnscentedSettings);
    compare(sprintf('beta_two_from_public_weight_delta_%d',k),actual,expectedX,expectedP+central*central',1e-9);
end
cfg=ukf_parameters();x=[.2;1;600;.3];p=diag([.1;.2;5;.1].^2);memory=pack(x,p);current=x(1:2)+[.01;-.02];
[posterior,~]=kalman_current_update(memory,current,1,1,0,cfg.Settings);
reference=unscentedKalmanFilter(@(state)state,@pmsm_sensorless_measurement,x,'Alpha',1,'Beta',2,'Kappa',0);
reference.StateCovariance=p;reference.MeasurementNoise=diag(cfg.MeasurementVariance);
[expectedX,expectedP]=correct(reference,current);compare('shared_linear_current_correction',posterior,expectedX,expectedP,1e-9);
p=diag([.01,.04,25,.01]);p(1:2,1:2)=[1e-6,1e-6+5e-13;1e-6+5e-13,1e-6];
memory=pack(x,p);[roundoffPosterior,~]=kalman_current_update(memory,x(1:2),1,1,0,cfg.Settings);
assert(roundoffPosterior(26)==0);[~,flag]=chol(reshape(roundoffPosterior(5:20),4,4));assert(flag~=0);
actual=ukf_predict(roundoffPosterior,[10;-5],1,0,cfg.UnscentedSettings);
assert(actual(26)==0 && actual(28)==1);assert_positive(actual);add_guard('roundoff_covariance_repaired_after_shared_correction');
memory=pack(x,diag([.01,.04,25,.01]));p=reshape(memory(5:20),4,4);p(1,1)=-1e-4;memory(5:20)=p(:);
actual=ukf_predict(memory,[10;-5],1,0,cfg.UnscentedSettings);assert(actual(26)==3 && actual(21)==0);assert_positive(actual);add_guard('indefinite_covariance_rejected');
memory=pack(x,diag([.01,.04,25,1]));actual=ukf_predict(memory,[10;-5],1,0,cfg.UnscentedSettings);
assert(actual(26)==3);assert_positive(actual);add_guard('excessive_sigma_angle_rejected');
ambiguous=cfg;ambiguous.MaximumSigmaAngleDeviation=pi-.0001;ambiguous=refresh_ukf_parameters(ambiguous);
factor=diag([.1,.1,5,1e-5]);factor(4,1)=(pi-.0002)/2;factor(4,2)=(pi-.0002)/2;
memory=pack(x,factor*factor');actual=ukf_predict(memory,[10;-5],1,0,ambiguous.UnscentedSettings);
assert(actual(26)==3);assert_positive(actual);add_guard('ambiguous_circular_mean_rejected');
memory=pack(x,diag([.01,.04,25,.01]));bad=cfg.UnscentedSettings;bad(28)=0;
actual=ukf_predict(memory,[10;-5],1,0,bad);assert(actual(26)==2);add_guard('invalid_sigma_configuration');
actual=ukf_predict(memory,[10;-5],0,0,cfg.UnscentedSettings);assert(isequal(actual,memory));add_guard('disabled_predictor_does_not_advance');
actual=ukf_predict(memory,[NaN;-5],1,0,cfg.UnscentedSettings);assert(actual(26)==1 && all(isfinite(actual)));add_guard('nonfinite_voltage_fault');
actualSingle=ukf_predict(single(memory),single([10;-5]),single(1),single(0),single(cfg.UnscentedSettings));
actual=ukf_predict(memory,[10;-5],1,0,cfg.UnscentedSettings);
assert(isa(actualSingle,'single') && actualSingle(26)==0 && all(isfinite(actualSingle)));
assert(max(abs(double(actualSingle(1:4))-actual(1:4)))<3e-5);add_guard('single_precision_kernel_smoke');
behavior=struct([]);
for beta=[0,2]
    toy=unscentedKalmanFilter(@(state)[state(1)^2;state(2:4)],@(state)state(1:2),zeros(4,1),'Alpha',1,'Beta',beta,'Kappa',0);
    toy.StateCovariance=eye(4);toy.ProcessNoise=zeros(4);[meanValue,covariance]=predict(toy);
    assert(abs(meanValue(1)-1)<1e-12 && isfinite(covariance(1,1)));
    entry=struct('Alpha',1,'Beta',beta,'Kappa',0,'states',4,'function','[x1^2;x2;x3;x4]', ...
        'expected_mean_first_state',1,'expected_variance_first_state',3+beta, ...
        'observed_mean_first_state',meanValue(1),'observed_variance_first_state',covariance(1,1), ...
        'matches_published_weights',abs(covariance(1,1)-(3+beta))<1e-10);
    if isempty(behavior),behavior=entry;else,behavior(end+1)=entry;end %#ok<AGROW>
end
report=struct('status','passed','release',version('-release'),'version',version,'matlabroot',matlabroot, ...
    'kind','pure M numerical checks; not physical drive MIL or target timing', ...
    'kernel_checks',numel(checks),'checks',checks,'public_reference_behavior',behavior, ...
    'reference_covariance_limit','For nonlinear beta=2, this installation differs from the published central covariance weight. Use closed-form moments; beta=1 public-reference comparisons are separate.');
save(fullfile(module,'waveform_analysis','numerical_results.mat'),'report','-v7.3');
fid=fopen(fullfile(module,'waveform_analysis','numerical_metrics.json'),'w');fwrite(fid,jsonencode(report,PrettyPrint=true));fclose(fid);
    function compare(name,actual,expectedX,expectedP,tolerance)
        assert(actual(26)==0 && actual(28)==0);difference=actual(1:4)-expectedX;
        difference(4)=atan2(sin(difference(4)),cos(difference(4)));
        pDifference=reshape(actual(5:20),4,4)-expectedP;
        scaled=pDifference./([1;1;100;1]*[1;1;100;1]');
        dx=max(abs(difference));dp=max(abs(scaled),[],'all');assert(dx<tolerance && dp<tolerance);assert_positive(actual);
        entry=struct('name',name,'state_difference',dx,'scaled_covariance_difference',dp,'status','passed');
        checks(end+1)=entry;
    end
    function add_guard(name)
        checks(end+1)=struct('name',name,'state_difference',0,'scaled_covariance_difference',0,'status','passed');
    end
end
function memory=pack(x,p)
memory=zeros(28,1);memory(1:4)=x;memory(5:20)=p(:);memory(27)=1;
end
function assert_positive(memory)
p=reshape(memory(5:20),4,4);assert(all(isfinite(memory)) && max(abs(p-p'),[],'all')<1e-10);
[~,flag]=chol(p);assert(flag==0);
end
function next=unwrapped_process(state,voltage,settings)
next=pmsm_sensorless_step(state,voltage,settings);next(4)=state(4)+settings(1)*state(3);
end
function [xNext,pNext]=diagonal_moments(x,voltage,variance,cfg)
% Closed trigonometric moments of the axial sigma distribution, not a point loop.
ts=cfg.Model.Ts;a=1-ts*cfg.Model.Rs/cfg.Model.L;b=ts*cfg.Model.Flux/cfg.Model.L;
c=cfg.SigmaScale;delta=sqrt(c*variance(4));g=[sin(x(4));-cos(x(4))];gd=[cos(x(4));sin(x(4))];
shift=b*x(3)*(cos(delta)-1)/c;
xNext=[a*x(1:2)+ts/cfg.Model.L*voltage+b*x(3)*g+shift*g; x(3);atan2(sin(x(4)+ts*x(3)),cos(x(4)+ts*x(3)))];
pNext=zeros(4);radial=b^2*variance(3)+(b*x(3))^2*(cos(delta)-1)^2/c+(cfg.Beta-cfg.Alpha^2)*shift^2;
pNext(1:2,1:2)=a^2*diag(variance(1:2))+radial*(g*g')+(b*x(3))^2*sin(delta)^2/c*(gd*gd');
pNext(1:2,3)=b*variance(3)*g;pNext(3,1:2)=pNext(1:2,3)';
pNext(1:2,4)=ts*b*variance(3)*g+b*x(3)*sin(delta)*delta/c*gd;pNext(4,1:2)=pNext(1:2,4)';
pNext(3,3)=variance(3);pNext(3,4)=ts*variance(3);pNext(4,3)=pNext(3,4);pNext(4,4)=variance(4)+ts^2*variance(3);
pNext=pNext+diag(cfg.ProcessVariance);
end
