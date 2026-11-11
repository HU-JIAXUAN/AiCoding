function report=run_mras_host_validation(outputDir)
%RUN_MRAS_HOST_VALIDATION Compare real generated MEX/SIL to the MRAS M kernel.
% outputDir is a new, explicit work folder; no engineering model is modified.
arguments
    outputDir (1,:) char
end
assert(~isfolder(outputDir),'Use a new output folder to preserve earlier evidence.');
mkdir(outputDir);[ok,attributes]=fileattrib(outputDir);assert(ok);outputDir=attributes.Name;
previous=pwd;previousPath=path;cleanup=onCleanup(@()finish(previous,previousPath));cd(outputDir);
cfg=mras_parameters();test=mras_host_test_parameters();source=which('mras_step');
assert(test.CheckStart>0&&test.CheckStart<test.Duration&&sign(test.ElectricalSpeed)==test.Direction);
report=struct('status','running','release',version('-release'),'matlabroot',matlabroot, ...
    'source',source,'scope','MRAS state-update M kernel; excludes output adapter, full Simulink App and C2000', ...
    'compiler',struct(),'stages',struct());
try
compiler=mex.getCompilerConfigurations('C','Selected');assert(isscalar(compiler));
report.compiler=struct('name',compiler.Name,'version',compiler.Version,'location',compiler.Location);
res=coder.screener('mras_step');
report.screener=struct('unsupported_calls',numel(res.UnsupportedCalls),'messages',numel(res.Messages));
report.test_parameters=test;
assert(isempty(res.UnsupportedCalls)&&isempty(res.Messages));writeReport(outputDir,report);
time=(0:cfg.Ts:test.Duration)';theta=test.InitialAngle+test.ElectricalSpeed*time;
current=[test.Id*cos(theta)-test.Iq*sin(theta),test.Id*sin(theta)+test.Iq*cos(theta)];
derivative=test.ElectricalSpeed*[-test.Id*sin(theta)-test.Iq*cos(theta),test.Id*cos(theta)-test.Iq*sin(theta)];
emf=test.ElectricalSpeed*cfg.Flux*[-sin(theta),cos(theta)];
voltage=cfg.Rs*current+cfg.L*derivative+emf;
reference=trajectory(@mras_step,time,current,voltage,cfg.Settings,test,'double');
singleReference=trajectory(@mras_step,time,current,voltage,cfg.Settings,test,'single');
report.interpreted_double=physical(reference,time,theta,cfg,test);
report.interpreted_single=physical(singleReference,time,theta,cfg,test);
assert(report.interpreted_double.passed&&report.interpreted_single.passed);
save(fullfile(outputDir,'physical_fixture.mat'),'time','theta','current','voltage','cfg','test','reference','singleReference');
for precision={'double','single'}
    type=precision{1};buildDir=fullfile(outputDir,['mex_' type]);name=['mras_step_host_' type];
    args={zeros(21,1,type),zeros(2,1,type),zeros(2,1,type),cast(1,type),cast(1,type),cast(0,type),cast(cfg.Settings,type)};
    config=coder.config('mex');config.TargetLang='C';
    codegen('mras_step','-config',config,'-args',args,'-d',buildDir,'-o',name);
    addpath(buildDir);rehash;
    assert(~isempty(which(name))&&endsWith(which(name),['.' mexext]));
    actual=trajectory(str2func(name),time,current,voltage,cfg.Settings,test,type);
    if strcmp(type,'double'),expected=reference;tolerance=test.MexDoubleRelativeLimit;else,expected=singleReference;tolerance=test.MexSingleRelativeLimit;end
    difference=max(abs(double(actual)-double(expected))./max(1,abs(double(expected))),[],'all');
    flagsEqual=isequal(actual(:,[11,12,20]),expected(:,[11,12,20]));
    metrics=physical(actual,time,theta,cfg,test);
    stageStatus='failed';if difference<=tolerance&&flagsEqual&&metrics.passed,stageStatus='passed';end
    report.stages.(['mex_' type])=struct('status',stageStatus,'relative_state_error',difference,'limit',tolerance, ...
        'qualifier_direction_fault_exact',flagsEqual,'physical',metrics,'binary',which(name));
    save(fullfile(outputDir,['mex_' type '_trace.mat']),'actual','expected');
    writeReport(outputDir,report);
    assert(difference<=tolerance&&flagsEqual&&metrics.passed);
    fprintf('MRAS_HOST_MEX_%s_PASSED relative=%g\n',upper(type),difference);
end
config=coder.config('lib');config.TargetLang='C';config.VerificationMode='SIL';
report.production_device=config.HardwareImplementation.ProdHWDeviceType;
report.test_device=config.HardwareImplementation.TargetHWDeviceType;
args={zeros(21,1),zeros(2,1),zeros(2,1),1,1,0,cfg.Settings};
buildDir=fullfile(outputDir,'sil_double');
codegen('mras_step','-config',config,'-args',args,'-d',buildDir);
addpath(genpath(outputDir));rehash;binary=which('mras_step_sil');
assert(~isempty(binary)&&endsWith(binary,['.' mexext]));
actual=trajectory(@mras_step_sil,time,current,voltage,cfg.Settings,test,'double');
difference=max(abs(actual-reference)./max(1,abs(reference)),[],'all');
flagsEqual=isequal(actual(:,[11,12,20]),reference(:,[11,12,20]));metrics=physical(actual,time,theta,cfg,test);
stageStatus='failed';if difference<=test.SilDoubleRelativeLimit&&flagsEqual&&metrics.passed,stageStatus='passed';end
report.stages.sil_double=struct('status',stageStatus,'relative_state_error',difference,'limit',test.SilDoubleRelativeLimit, ...
    'qualifier_direction_fault_exact',flagsEqual,'physical',metrics,'binary',binary);
save(fullfile(outputDir,'sil_double_trace.mat'),'actual','reference');writeReport(outputDir,report);
assert(difference<=test.SilDoubleRelativeLimit&&flagsEqual&&metrics.passed);
report.status='passed';report.samples=numel(time);writeReport(outputDir,report);
fprintf('MRAS_HOST_SIL_PASSED relative=%g samples=%d\n',difference,numel(time));
catch exception
    report.status='failed';report.failure=struct('identifier',exception.identifier,'message',exception.message);
    writeReport(outputDir,report);rethrow(exception);
end
clear cleanup
end
function states=trajectory(kernel,time,current,voltage,settings,test,type)
state=zeros(21,1,type);states=zeros(numel(time),21,type);
for k=1:numel(time)
    states(k,:)=state';
    state=kernel(state,cast(voltage(k,:)','like',state),cast(current(k,:)','like',state), ...
        cast(test.Direction,'like',state),cast(1,'like',state),cast(0,'like',state),cast(settings,'like',state));
end
assert(all(isfinite(states),'all'));
end
function result=physical(states,time,theta,cfg,test)
window=time>=test.CheckStart;error=atan2(sin(double(states(:,1))-theta),cos(double(states(:,1))-theta));
angle=sqrt(mean(error(window).^2));speed=sqrt(mean((double(states(window,3))-test.ElectricalSpeed).^2));
valid=mean(states(window,11)>=cfg.QualificationSamples);
result=struct('angle_rms_rad',angle,'speed_rms_electrical_rad_s',speed,'valid_fraction',valid, ...
    'angle_limit_rad',test.AngleRmsLimit,'speed_limit_electrical_rad_s',test.SpeedRmsLimit,'valid_min',test.ValidFractionMinimum, ...
    'passed',angle<test.AngleRmsLimit&&speed<test.SpeedRmsLimit&&valid>=test.ValidFractionMinimum);
end
function writeReport(folder,report)
fid=fopen(fullfile(folder,'host_verification.json'),'w','n','UTF-8');
fwrite(fid,jsonencode(report,PrettyPrint=true),'char');fclose(fid);
end
function finish(folder,previousPath)
clear mras_step_sil mras_step_host_double mras_step_host_single
cd(folder);path(previousPath);
end
