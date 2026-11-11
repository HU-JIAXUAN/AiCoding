function report=run_frame_pi_validation()
%RUN_FRAME_PI_VALIDATION Verify coordinate transfer, feedback, AW and state reset.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
model='FrameTrackingPITest';
if ~bdIsLoaded(model),open_system(fullfile(module,'src',[model,'.slx']));end
names={'normal_equivalence','pure_frame_change','proportional_during_tracking', ...
    'feedforward_transfer','positive_aw','negative_aw','without_aw','reset','disable','sample_time'};
records=struct();metrics=cell(1,numel(names));
for test=1:numel(names)
    name=names{test};[cfg,inverterCfg,testCfg]=frame_pi_test_parameters();
    if strcmp(name,'sample_time'),cfg.Ts=100e-6;end
    sample=(0:round(testCfg.StopTime/cfg.Ts))';time=sample*cfg.Ts;
    event=@(seconds)sample>=round(seconds/cfg.Ts);
    u=zeros(numel(time),10);u(:,9)=1;u(:,1)=0.2*sin(70*time);u(:,2)=0.3*cos(110*time);
    u(:,3)=0.01*cos(90*time);u(:,4)=0.02*sin(60*time);
    switch name
        case 'pure_frame_change'
            cfg.Kid=0;cfg.Kiq=0;cfg.Kaw=0;u(:,1:6)=repmat([0.3,-0.2,0,0,2,-1],numel(time),1);
            delta=0.8;rotation=[cos(delta),sin(delta);-sin(delta),cos(delta)];after=event(0.01);
            u(after,1:2)=u(after,1:2)*rotation';u(after,5:6)=u(after,5:6)*rotation';
            jump=round(0.01/cfg.Ts)+1;u(jump,7)=delta;u(jump,8)=1;
        case 'proportional_during_tracking'
            cfg.Kid=0;cfg.Kiq=0;cfg.Kaw=0;u(:,1:6)=0;u(:,1)=0.1;u(:,2)=-0.1;
            u(event(0.01),1)=0.6;u(event(0.01),2)=0.4;u(:,8)=1;
        case 'feedforward_transfer'
            cfg.Kid=0;cfg.Kiq=0;cfg.Kaw=0;u(:,1:6)=0;
            u(event(0.01),5)=3;u(event(0.01),6)=-2;u(event(0.01) & ~event(0.02),8)=1;
        case {'positive_aw','negative_aw','without_aw'}
            u(:,1:6)=0;signValue=1;if strcmp(name,'negative_aw'),signValue=-1;end
            u(event(0.002) & ~event(0.02),1)=signValue;
            inverterCfg.LinearLimit=2;testCfg.UseInternalLimit=1;
            if strcmp(name,'without_aw'),cfg.Kaw=0;end
        case 'reset'
            u(:,5)=0.4;u(:,6)=-0.6;u(event(0.03) & ~event(0.0301),10)=1;
        case 'disable'
            u(:,5)=0.4;u(:,6)=-0.6;u(event(0.03) & ~event(0.04),9)=0;
    end
    stimulus.time=time;stimulus.signals.values=u;stimulus.signals.dimensions=10;
    input=Simulink.SimulationInput(model);
    input=input.setVariable('currentCfg',cfg,'Workspace',model);
    input=input.setVariable('inverterCfg',inverterCfg,'Workspace',model);
    input=input.setVariable('testCfg',testCfg,'Workspace',model);
    input=input.setVariable('testStim',stimulus,'Workspace',model);
    result=sim(input);
    % The vector Mux contains 2x1 MATLAB Function outputs, hence the logger
    % stores 30x1xN. Preserve sample order while presenting an N-by-30 table.
    assert(prod(result.trace.signals.dimensions)==30);
    trace=reshape(result.trace.signals.values,30,[])';
    assert(size(trace,2)==30 && all(isfinite(trace),'all'));
    assert(isequal(trace(:,1:10),u),'Recorded samples differ from requested inputs.');
    inactive=u(:,9)<0.5 | u(:,10)>0.5;
    assert(all(trace(inactive,11:22)==0,'all') && all(trace(inactive,30)==0));
    expectedResidual=trace(:,21:22)-trace(:,19:20);
    assert(max(vecnorm(trace(:,21:22),2,2))<=inverterCfg.LinearLimit+1e-10);
    assert(all(trace(:,29)>=0 & trace(:,29)<=1));
    metric=struct('name',name,'passed',true,'Ts_s',cfg.Ts,'maximum_error',0, ...
        'peak_requested_voltage_V',max(vecnorm(trace(:,19:20),2,2)), ...
        'peak_limited_voltage_V',max(vecnorm(trace(:,21:22),2,2)), ...
        'peak_integral_V',max(vecnorm(trace(:,15:16),2,2)));
    if ismember(name,{'normal_equivalence','sample_time','reset','disable'})
        metric.maximum_error=max(abs(trace(:,11:12)-trace(:,25:26)),[],'all');
        assert(metric.maximum_error<1e-10);
        assert(max(abs(trace(:,15:16)-trace(:,27:28)),[],'all')<1e-10);
    end
    switch name
        case 'pure_frame_change'
            before=trace(jump-1,19:20)';afterVoltage=trace(jump:end,19:20)';
            physicalVoltage=rotation'*afterVoltage;
            metric.maximum_error=max(abs(physicalVoltage-before),[],'all');
            assert(metric.maximum_error<1e-12);
            naive=diag([cfg.Kpd,cfg.Kpq])*u(jump,1:2)'+u(jump,5:6)';
            assert(norm(rotation'*naive-before)>0.1,'Fixture must expose anisotropic-gain coordinate error.');
        case 'proportional_during_tracking'
            expected=u(:,1:2).*[cfg.Kpd,cfg.Kpq];
            metric.maximum_error=max(abs(trace(:,11:12)-expected),[],'all');
            assert(metric.maximum_error<1e-12);
            assert(norm(trace(round(0.01/cfg.Ts)+1,11:12)-trace(round(0.01/cfg.Ts),11:12))>1);
        case 'feedforward_transfer'
            metric.maximum_error=max(abs(trace(:,19:20)),[],'all');assert(metric.maximum_error<1e-12);
            assert(norm(trace(end,13:14)-[-3,2])<1e-12);
        case {'positive_aw','negative_aw','without_aw'}
            assert(max(abs(trace(:,23:24)-expectedResidual),[],'all')<1e-12);
            lastForced=round(0.02/cfg.Ts);integral=trace(lastForced,15);
            if cfg.Kaw>0
                expectedIntegral=signValue*(2-cfg.Kpd+cfg.Kid/cfg.Kaw);
                metric.maximum_error=abs(integral-expectedIntegral);assert(metric.maximum_error<1e-6);
                assert(abs(integral)<1);
            else
                assert(integral>25,'The no-AW comparison should show accumulation under forced error.');
            end
        case {'reset','disable'}
            firstActive=find(~inactive & sample>round(0.03/cfg.Ts),1);
            assert(all(trace(firstActive,15:16)==0),'Integral must restart from zero.');
    end
    records.(name)=struct('time',result.trace.time,'trace',trace,'input',u, ...
        'currentCfg',cfg,'inverterCfg',inverterCfg,'testCfg',testCfg);
    metrics{test}=metric;
    fprintf('%s: PASS (maximum error %.3g)\n',name,metric.maximum_error);
end
metrics=[metrics{:}];
report=struct('release',version('-release'),'passed',all([metrics.passed]), ...
    'case_count',numel(names),'cases',metrics,'physical_plant_included',false);
save(fullfile(module,'waveform_analysis','frame_pi_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','frame_pi_metrics.json'),'w');
cleanup=onCleanup(@()fclose(file));fwrite(file,jsonencode(report,PrettyPrint=true));clear cleanup
plotCase(records.pure_frame_change,'frame_transfer',module);
plotCase(records.proportional_during_tracking,'frame_proportional',module);
plotCase(records.positive_aw,'frame_aw',module);
disp(report);
end
function plotCase(record,name,module)
figureHandle=figure('Visible','off','Position',[100,100,1100,850]);
cleanup=onCleanup(@()close(figureHandle));
tiledlayout(4,1);time=record.time;x=record.trace;
nexttile;plot(time,x(:,1:2));ylabel('error (A)');legend('e_d','e_q');grid on
nexttile;plot(time,x(:,19:22));ylabel('voltage (V)');legend('request d','request q','limited d','limited q');grid on
nexttile;plot(time,x(:,13:16));ylabel('integral (V)');legend('base d','base q','state d','state q');grid on
nexttile;plot(time,x(:,[7,8,30]));ylabel('rad / flag');legend('extra angle','tracking','active');xlabel('time (s)');grid on
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.png']));
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.svg']),ContentType='vector');
end
