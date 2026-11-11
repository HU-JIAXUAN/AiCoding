function report=run_kalman_qualification_check()
%RUN_KALMAN_QUALIFICATION_CHECK Reject a plausible opposite-speed convergence.
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'build_process'));initialize_ekf_paths();
cfg=ekf_parameters();ts=cfg.Model.Ts;memory=zeros(28,1);
memory(1:4)=[0;2;-600;.5];p=diag([1e-4,1e-4,1,.01^2]);memory(5:20)=p(:);
memory(21)=cfg.QualificationSamples-1;memory(22)=.5-600*ts;
memory(23)=600;memory(24)=1;memory(25)=-1;memory(27)=1;
% Current innovation is exactly zero, covariance is small and direction agrees
% with the negative speed. Estimated angle history advances positively.
[guarded,guardedOutput]=kalman_current_update(memory,[0;2],-1,1,0,cfg.Settings);
relaxed=cfg;relaxed.MaxRateMismatch=1e6;relaxed=refresh_kalman_parameters(relaxed);
[withoutGuard,relaxedOutput]=kalman_current_update(memory,[0;2],-1,1,0,relaxed.Settings);
assert(guardedOutput(8)==0 && guardedOutput(9)<cfg.MaxThetaStd && guardedOutput(10)<cfg.MaxOmegaStd);
assert(guardedOutput(12)>1000 && guardedOutput(3)==0 && guarded(21)==0);
assert(relaxedOutput(3)==1 && withoutGuard(21)==cfg.QualificationSamples);
report=struct('release',version('-release'),'matlabroot',matlabroot,'status','passed','checks',2, ...
    'kind','synthetic public correction-state input; not a physical motor trajectory', ...
    'source_book','12.4.3 printed317/PDF346: opposite-speed convergence and angle derivative', ...
    'state_speed_rad_s',guardedOutput(2),'angle_rate_rad_s',guardedOutput(11), ...
    'NIS',guardedOutput(8),'theta_std_rad',guardedOutput(9),'guarded_valid',guardedOutput(3), ...
    'guard_relaxed_valid',relaxedOutput(3));
save(fullfile(module,'waveform_analysis/qualification_results.mat'),'memory','cfg','relaxed','guarded','guardedOutput','withoutGuard','relaxedOutput','report');
handle=fopen(fullfile(module,'waveform_analysis/qualification_metrics.json'),'w');fwrite(handle,jsonencode(report,PrettyPrint=true));fclose(handle);
end
