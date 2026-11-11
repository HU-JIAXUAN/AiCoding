function report = run_angle_tracking_validation()
%RUN_ANGLE_TRACKING_VALIDATION Run twelve R2026b phase-PLL MIL scenarios.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'build_process'));
open_system(fullfile(module,'src','AngleTrackingTest.slx'));
cfg=angle_tracking_parameters();t=(0:cfg.Ts:0.3)';
names={'positive','negative','wrap','acceleration','speed_step','phase_noise', ...
    'amplitude_dropout','reset','disable','speed_limit','initial_error','no_amplitude'};
records=struct(); metrics=struct([]);
for n=1:numel(names)
    name=names{n};omega=200*ones(size(t));theta0=0.4;mag=ones(size(t));en=ones(size(t));rst=zeros(size(t));
    switch name
        case 'negative',omega=-omega;
        case 'wrap',theta0=3.1;
        case 'acceleration',omega=50+min(t,0.2)*1750;
        case 'speed_step',omega=100+250*(t>=0.15);
        case 'amplitude_dropout',mag(t>=0.12 & t<0.17)=0;
        case 'reset',rst(t>=0.15 & t<0.1501)=1;
        case 'disable',en(t>=0.10 & t<0.15)=0;
        case 'speed_limit',omega=2500*ones(size(t));
        case 'initial_error',theta0=2.5;
        case 'no_amplitude',mag(:)=0;
    end
    theta=theta0+cumtrapz(t,omega);phase=wrap(theta);
    if strcmp(name,'phase_noise'),rng(17);phase=wrap(phase+0.015*randn(size(t)));end
    u=[phase,mag,en,rst,wrap(theta),omega];
    stim.time=t;stim.signals.values=u;stim.signals.dimensions=6;
    in=Simulink.SimulationInput('AngleTrackingTest');
    in=in.setVariable('pllCfg',cfg,'Workspace','AngleTrackingTest');
    in=in.setVariable('testStim',stim,'Workspace','AngleTrackingTest');
    in=in.setModelParameter('StopTime',num2str(t(end),16));out=sim(in);
    v=out.trace.signals.values;time=out.trace.time;
    assert(size(v,2)==12 && all(isfinite(v),'all'));
    assert(max(abs(v(:,8)))<=cfg.OmegaMax+1e-9);
    assert(max(abs(v(:,11)))<=cfg.OmegaMax+1e-9);
    idx=time>=0.25;err=wrap(v(:,7)-v(:,5));
    m=struct('name',name,'angle_rms_rad',sqrt(mean(err(idx).^2)), ...
        'angle_max_rad',max(abs(err(idx))),'speed_rms_rad_s',sqrt(mean((v(idx,8)-v(idx,6)).^2)), ...
        'valid_fraction',mean(v(idx,10)),'window_start_s',0.25,'window_end_s',0.3,'passed',false);
    if ~ismember(name,{'speed_limit','no_amplitude'})
        assert(m.angle_rms_rad<0.04 && m.speed_rms_rad_s<10,'%s: tracking tolerance exceeded.',name);
        assert(m.valid_fraction>0.95,'%s: PLL did not qualify.',name);
    end
    if strcmp(name,'amplitude_dropout')
        q=time>=0.121 & time<0.169;assert(all(v(q,10)==0) && all(v(q,8)==0));
        assert(max(v(q,7))-min(v(q,7))<1e-12,'Low-amplitude angle state changed.');
    elseif ismember(name,{'reset','disable'})
        q=v(:,3)<0.5 | v(:,4)>0.5;
        assert(all(v(q,7)==cfg.Theta0) && all(v(q,8)==0) && all(v(q,10)==0));
    elseif strcmp(name,'no_amplitude')
        assert(all(v(:,10)==0) && all(v(:,7)==0) && all(v(:,8)==0));
    end
    m.passed=true;
    if n==1,metrics=m;else,metrics(n)=m;end
    records.(name)=struct('model','AngleTrackingTest','configuration',cfg,'inputs',u, ...
        'time',time,'trace',v,'angle_error',err,'metrics',m);
end
channels={'phase','magnitude','enable','reset','theta_true','omega_true', ...
    'theta_e_hat','omega_e_hat','phase_error','valid','integral','lock_count'};
report=struct('matlab_version',version,'release',version('-release'),'tests',numel(names), ...
    'passed',sum([metrics.passed]),'metrics',metrics,'channels',{channels});
folder=fullfile(module,'waveform_analysis');save(fullfile(folder,'results.mat'),'records','report');
fid=fopen(fullfile(folder,'metrics.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
plotCase(records.positive,folder,'tracking');plotCase(records.amplitude_dropout,folder,'dropout');
disp(struct2table(metrics));
end
function y=wrap(x)
y=atan2(sin(x),cos(x));
end
function plotCase(r,folder,name)
f=figure('Visible','off','Position',[100 100 1100 760]);t=r.time;v=r.trace;
tiledlayout(3,1);nexttile;plot(t,[v(:,6),v(:,8)]);ylabel('electrical rad/s');legend('true','PLL');grid on;
nexttile;plot(t,r.angle_error);ylabel('angle error / rad');grid on;
nexttile;stairs(t,[v(:,2),v(:,10)]);ylabel('magnitude / valid');xlabel('time / s');legend('magnitude','valid');grid on;
exportgraphics(f,fullfile(folder,[name,'.png']));exportgraphics(f,fullfile(folder,[name,'.svg']),'ContentType','vector');close(f);
end
