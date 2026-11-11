function report = run_motor_validation(group)
%RUN_MOTOR_VALIDATION Verify saved step 06-14 models and retain real traces.
%   REPORT = RUN_MOTOR_VALIDATION() runs all eight module groups.
%   REPORT = RUN_MOTOR_VALIDATION('inverter') runs just one group.
%   Tests use SimulationInput plus explicit assertions (Simulink Test absent).
if nargin==0,group='all';end
modelRoot=initialize_motor_paths();
groups={'pmsm_plant','current_loop','inverter','timing','motion_loop', ...
    'experiment','feedforward','deadtime'};
if ~strcmp(group,'all'),assert(ismember(group,groups));groups={char(group)};end
previous=Simulink.fileGenControl('getConfig');
cache=tempname;mkdir(cache);
cleanup=onCleanup(@()restoreCache(previous,cache));
Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'cache'), ...
    'CodeGenFolder',fullfile(cache,'code'),'createDir',true);
channels=jsondecode(fileread(fullfile(modelRoot,'app_models','Sensor','experiment','build_process','model_channels.json')));
report=struct();
for k=1:numel(groups)
    module=groups{k};records=struct();o=struct();
    switch module
        case 'pmsm_plant'
            t=(0:1e-4:0.03)';z=zeros(size(t));
            r=run_motor_case('PMSMPlantTest',struct(),[2+z,1+z,z,z,z],0.03);
            v=r.trace.signals.values;tm=r.trace.time;
            reference=[4*(1-exp(-0.5/1e-3*tm)),2*(1-exp(-0.5/1.2e-3*tm))];
            r.metrics.analytic_error_A=max(abs(v(:,6:7)-reference),[],'all');
            assert(r.metrics.analytic_error_A<1e-8,'RL analytical response');
            records.rl_response=r;
            o.pmsmCfg=struct('Id0',-1,'Iq0',3);we=600;
            vd=-0.5-we*1.2e-3*3;vq=0.5*3+we*(0.035-0.001);
            r=run_motor_case('PMSMPlantTest',o,[vd+z,vq+z,we+z,z,z],0.03);
            v=r.trace.signals.values;
            r.metrics.equilibrium_error_A=max(abs(v(:,6:7)-[-1,3]),[],'all');
            r.metrics.torque_error_Nm=max(abs(v(:,8)-1.5*4*(0.035+(0.001-0.0012)*(-1))*3));
            assert(r.metrics.equilibrium_error_A<1e-9&&r.metrics.torque_error_Nm<1e-10);
            records.salient_equilibrium=r;
            for direction=[1,-1]
                r=run_motor_case('PMSMPlantTest',struct(),[z,z,z,0.1*direction+z,0.02*direction+z],0.03);
                v=r.trace.signals.values;tm=r.trace.time;
                w=direction*800*(1-exp(-0.2*tm));
                theta=direction*800*(tm-5*(1-exp(-0.2*tm)));
                r.metrics.speed_error_rad_s=max(abs(v(:,9)-w));
                r.metrics.position_error_rad=max(abs(v(:,10)-theta));
                assert(r.metrics.speed_error_rad_s<1e-8&&r.metrics.position_error_rad<1e-8);
                if direction>0,records.mechanical_positive=r;else,records.mechanical_negative=r;end
            end
            o=struct();o.experimentCfg=struct('LogTs',5e-6);
            r=run_motor_case('PMSMPlantTest',o,[2+z,1+z,z,z,z],0.03);
            v=r.trace.signals.values;tm=r.trace.time;
            supplied=trapz(tm,1.5*(v(:,1).*v(:,6)+v(:,2).*v(:,7)-0.5*(v(:,6).^2+v(:,7).^2)));
            stored=0.75*(1e-3*v(end,6)^2+1.2e-3*v(end,7)^2);
            r.metrics.energy_balance_error_J=abs(supplied-stored);
            assert(r.metrics.energy_balance_error_J<1e-7,'Electrical energy conservation');
            records.energy_balance=r;
        case 'current_loop'
            t=(0:1e-4:0.06)';z=zeros(size(t));on=ones(size(t));
            u=[double(t>=0.003),2*double(t>=0.003),z,on,z];
            r=run_motor_case('CurrentLoopTest',struct(),u,0.06);
            r.metrics=currentMetrics(r);assert(r.metrics.final_error_A<0.01);
            records.dq_step=r;
            u(:,1)=0;u(:,2)=-2*double(t>=0.003);
            r=run_motor_case('CurrentLoopTest',struct(),u,0.06);
            r.metrics=currentMetrics(r);assert(r.metrics.final_error_A<0.01);records.negative_step=r;
            u(:,2)=100*double(t>=0.003 & t<0.012)+2*double(t>=0.012);
            r=run_motor_case('CurrentLoopTest',struct(),u,0.06);r.metrics=currentMetrics(r);
            v=r.trace.signals.values;assert(max(vecnorm(v(:,7:8),2,2))<r.parameters.inverterCfg.LinearLimit+1e-9);
            assert(r.metrics.final_error_A<0.02);records.saturation_aw_on=r;
            o.currentCfg=struct('Kaw',0);
            r=run_motor_case('CurrentLoopTest',o,u,0.06);r.metrics=currentMetrics(r);records.saturation_aw_off=r;
            assert(records.saturation_aw_on.metrics.recovery_iae_A_s<r.metrics.recovery_iae_A_s,'Anti-windup must improve recovery');
            u(:,2)=2;u(:,4)=double(~(t>=0.012 & t<0.018));u(:,5)=double(t>=0.03 & t<0.031);
            r=run_motor_case('CurrentLoopTest',struct(),u,0.06);v=r.trace.signals.values;
            inactive=v(:,16)==0|v(:,17)~=0;
            r.metrics.inactive_voltage_V=max(abs(v(inactive,5:6)),[],'all');
            assert(r.metrics.inactive_voltage_V==0&&all(v(inactive,9:10)==0,'all'));
            records.enable_reset=r;
            o=struct();o.experimentCfg=struct('Step',2.5e-6);
            r=run_motor_case('CurrentLoopTest',o,[double(t>=0.003),2*double(t>=0.003),z,on,z],0.06);
            r.metrics.half_step_difference_A=max(abs(r.trace.signals.values(:,3:4)-records.dq_step.trace.signals.values(:,3:4)),[],'all');
            assert(r.metrics.half_step_difference_A<1e-5);records.solver_convergence=r;
        case 'inverter'
            t=(0:1e-4:0.03)';phase=2*pi*50*t;
            for amplitude=[0,20,60]
                r=run_motor_case('InverterTest',struct(),amplitude*[cos(phase),sin(phase)],0.03);v=r.trace.signals.values;
                r.metrics.voltage_error_V=max(abs(v(:,1:2)-v(:,10:11)),[],'all');
                r.metrics.neutral_error_V=max(abs(sum(v(:,7:9),2)));
                assert(all(v(:,3:5)>=0.02-1e-12 & v(:,3:5)<=0.98+1e-12,'all'));
                assert(r.metrics.neutral_error_V<1e-11);
                if amplitude<=20,assert(r.metrics.voltage_error_V<1e-11);else,assert(r.metrics.voltage_error_V>1);end
                records.(sprintf('voltage_%d',amplitude))=r;
            end
            o.inverterCfg=struct('Vdc',24);
            r=run_motor_case('InverterTest',o,10*[cos(phase),sin(phase)],0.03);
            r.metrics.voltage_error_V=max(abs(r.trace.signals.values(:,1:2)-r.trace.signals.values(:,10:11)),[],'all');
            assert(r.metrics.voltage_error_V<1e-11);records.bus_24V=r;
        case 'timing'
            t=(0:1e-4:0.03)';u=[double(t>=0.003),2*double(t>=0.005)];
            delays=[0,0;1,1;2,3];
            for j=1:size(delays,1)
                o.timingCfg=struct('FeedbackTicks',delays(j,1),'ActuationTicks',delays(j,2));
                r=run_motor_case('TimingTest',o,u,0.03);v=r.trace.signals.values;
                expectedFb=[zeros(delays(j,1),1);u(1:end-delays(j,1),1)];
                expectedAct=[zeros(delays(j,2),1);u(1:end-delays(j,2),2)];
                assert(isequal(v(:,3),expectedFb)&&isequal(v(:,6),expectedAct),'Exact tick delay');
                r.metrics.feedback_delay_s=delays(j,1)*1e-4;r.metrics.actuation_delay_s=delays(j,2)*1e-4;
                records.(sprintf('delay_%d_%d',delays(j,:)))=r;
            end
        case 'motion_loop'
            t=(0:1e-4:0.3)';z=zeros(size(t));
            u=[100+z,z,20*double(t>=0.003 & t<0.1),z,z];
            r=run_motor_case('MotionLoopTest',struct(),u,0.3);v=r.trace.signals.values;
            r.metrics.peak_current_A=max(abs(v(:,7)));
            sampled=1:10:size(v,1);
            r.metrics.maximum_acceleration_rad_s2=max(abs(diff(v(sampled,6))))/1e-3;
            assert(r.metrics.peak_current_A<=8+1e-9&&r.metrics.maximum_acceleration_rad_s2<=200+1e-6);
            records.controller_limits=r;
            o.experimentCfg=struct('Mode',1,'CommandTime',0.02,'LoadTime',0.5);
            r=run_motor_case('MotorExperiment',o,[],1.2);r.metrics=experimentMetrics(r);
            assert(r.metrics.final_speed_error_rad_s<0.05&&r.metrics.peak_current_A<8.1);
            records.speed_load_step=r;
            r=run_motor_case('MotorExperiment',struct(),[],1.5);r.metrics=experimentMetrics(r);
            assert(r.metrics.final_position_error_rad<0.005&&abs(r.trace.signals.values(end,31))<0.05);
            records.position_load_step=r;
        case 'experiment'
            base=struct('Mode',0,'UseMechanical',0,'LoadTorque',0,'CommandTime',0.003);
            o.experimentCfg=base;o.experimentCfg.UseInverter=0;o.experimentCfg.UseTiming=0;
            r=run_motor_case('MotorExperiment',o,[],0.06);r.metrics=experimentMetrics(r);assert(r.metrics.final_current_error_A<0.01);records.ideal_current=r;
            o.experimentCfg.UseInverter=1;
            r=run_motor_case('MotorExperiment',o,[],0.06);r.metrics=experimentMetrics(r);assert(r.metrics.final_current_error_A<0.01);records.average_current=r;
            o.experimentCfg.UseTiming=1;
            r=run_motor_case('MotorExperiment',o,[],0.06);r.metrics=experimentMetrics(r);assert(r.metrics.final_current_error_A<0.01);records.timed_current=r;
            o.timingCfg=struct('FeedbackTicks',2,'ActuationTicks',1);
            r=run_motor_case('MotorExperiment',o,[],0.06);r.metrics=experimentMetrics(r);assert(r.metrics.final_current_error_A<0.02&&r.metrics.peak_current_A<4);records.extra_delay=r;
            o=struct();o.experimentCfg=struct('Mode',1,'CommandTime',0.5,'SpeedInitial',20,'SpeedReference',-20,'LoadTorque',0);
            r=run_motor_case('MotorExperiment',o,[],1.3);r.metrics=experimentMetrics(r);assert(r.metrics.final_speed_error_rad_s<0.1);records.speed_reversal=r;
            o=struct();o.pmsmCfg=struct('Rs',0.7,'Ld',1.3e-3,'Lq',1.5e-3,'J',7e-4);o.experimentCfg=struct('Mode',1,'LoadTime',0.5);
            r=run_motor_case('MotorExperiment',o,[],1.2);r.metrics=experimentMetrics(r);assert(r.metrics.final_speed_error_rad_s<0.2);records.parameter_change=r;
            o=struct();o.experimentCfg=base;o.experimentCfg.IqInitial=100;o.experimentCfg.IqReference=2;o.experimentCfg.CommandTime=0.025;
            r=run_motor_case('MotorExperiment',o,[],0.15);r.metrics=experimentMetrics(r);
            assert(min(r.trace.signals.values(:,27))<0.5&&r.metrics.final_current_error_A<0.02);records.voltage_limit_recovery=r;
            for reset=[0,1]
                o=struct();o.experimentCfg=base;o.experimentCfg.ImposedElectricalSpeed=500;
                o.experimentCfg.Enable=reset;o.experimentCfg.Reset=reset;o.feedforwardCfg=struct('Enable',1);
                r=run_motor_case('MotorExperiment',o,[],0.01);v=r.trace.signals.values;
                r.metrics.request_voltage_V=max(abs(v(:,7:14)),[],'all');
                assert(r.metrics.request_voltage_V==0,'Disable/reset must gate both PI and feedforward');
                if reset,records.reset_with_feedforward=r;else,records.disable_with_feedforward=r;end
            end
        case 'feedforward'
            t=(0:1e-4:0.03)';z=zeros(size(t));u=[1+z,2+z,500*sin(2*pi*50*t)];
            r=run_motor_case('FeedforwardTest',struct(),u,0.03);v=r.trace.signals.values;
            expected=[-1.2e-3*u(:,2).*u(:,3),(1e-3*u(:,1)+0.035).*u(:,3)];
            r.metrics.formula_error_V=max(abs(v(:,4:5)-expected),[],'all');assert(r.metrics.formula_error_V<1e-11);records.sign_and_units=r;
            o.feedforwardCfg=struct('Enable',0);
            r=run_motor_case('FeedforwardTest',o,u,0.03);assert(all(r.trace.signals.values(:,4:5)==0,'all'));r.metrics.disabled_voltage_V=0;records.disabled=r;
            base=struct('Mode',0,'UseMechanical',0,'ImposedElectricalSpeed',500,'UseTiming',0,'LoadTorque',0,'CommandTime',0.005);
            o=struct();o.experimentCfg=base;o.feedforwardCfg=struct('Enable',0);
            r=run_motor_case('MotorExperiment',o,[],0.06);r.metrics=experimentMetrics(r);records.loop_ff_off=r;
            o.feedforwardCfg.Enable=1;r=run_motor_case('MotorExperiment',o,[],0.06);r.metrics=experimentMetrics(r);
            assert(r.metrics.current_iae_A_s<records.loop_ff_off.metrics.current_iae_A_s,'Feedforward same-scenario current error');
            assert(max(abs(r.trace.signals.values(:,15:16)),[],'all')<1e-10,'No false residual for unsaturated feedforward');records.loop_ff_on=r;
            o.feedforwardCfg.ParameterScale=0.8;
            r=run_motor_case('MotorExperiment',o,[],0.06);r.metrics=experimentMetrics(r);assert(r.metrics.final_current_error_A<0.02);records.parameter_mismatch=r;
        case 'deadtime'
            t=(0:1e-4:0.03)';u=3*cos(2*pi*50*t+[0,-2*pi/3,2*pi/3]);
            r=run_motor_case('DeadtimeTest',struct(),u,0.03);v=r.trace.signals.values;
            away=all(abs(u)>=0.1,2);
            r.metrics.away_zero_residual_V=max(abs(v(away,10:12)),[],'all');
            r.metrics.zero_sum_error_V=max(abs(sum(v(:,4:6),2)));
            assert(r.metrics.away_zero_residual_V<1e-12&&r.metrics.zero_sum_error_V<1e-12);records.average_compensation=r;
            o.deadtimeCfg=struct('ModelEnable',0,'CompensationEnable',0);
            r=run_motor_case('DeadtimeTest',o,u,0.03);assert(all(r.trace.signals.values(:,4:12)==0,'all'));r.metrics.disabled_voltage_V=0;records.disabled=r;
            base=struct('Mode',0,'UseMechanical',0,'ImposedElectricalSpeed',80,'UseTiming',0,'LoadTorque',0,'CommandTime',0.005,'IqReference',0.5);
            o=struct();o.experimentCfg=base;o.feedforwardCfg=struct('Enable',1);o.deadtimeCfg=struct('ModelEnable',1,'CompensationEnable',0);
            r=run_motor_case('MotorExperiment',o,[],0.3);r.metrics=experimentMetrics(r);records.loop_comp_off=r;
            o.deadtimeCfg.CompensationEnable=1;
            r=run_motor_case('MotorExperiment',o,[],0.3);r.metrics=experimentMetrics(r);
            assert(r.metrics.tail_current_rms_A<records.loop_comp_off.metrics.tail_current_rms_A,'Dead-time compensation must reduce same-scenario RMS');records.loop_comp_on=r;
            o.deadtimeCfg.CurrentBlend=0.01;
            r=run_motor_case('MotorExperiment',o,[],0.3);r.metrics=experimentMetrics(r);
            assert(r.metrics.tail_current_rms_A<records.loop_comp_on.metrics.tail_current_rms_A,'Blend-width sensitivity');records.loop_comp_narrow_blend=r;
            dt=1e-7;duration=0.001;t=(0:dt:duration)';period=1000;q=double(mod((0:numel(t)-1)',period)<500);
            for direction=[1,-1]
                r=run_motor_case('SwitchingLegTest',struct(),[q,3*direction+zeros(size(t))],duration);v=r.trace.signals.values;
                use=(2001:10000)';expected=24-direction*48*2e-6/1e-4;
                r.metrics.mean_pole_voltage_V=mean(v(use,3));r.metrics.mean_voltage_error_V=abs(r.metrics.mean_pole_voltage_V-expected);
                r.metrics.shoot_through_count=sum(v(:,4)~=0 & v(:,5)~=0);
                assert(r.metrics.mean_voltage_error_V<0.06&&r.metrics.shoot_through_count==0);
                if direction>0,records.switching_positive=r;else,records.switching_negative=r;end
            end
            o=struct();o.deadtimeCfg=struct('DeadTime',0);
            r=run_motor_case('SwitchingLegTest',o,[q,3+zeros(size(t))],duration);r.metrics.pole_error_V=max(abs(r.trace.signals.values(:,3)-48*q));assert(r.metrics.pole_error_V==0);records.switching_zero_deadtime=r;
            q=zeros(size(t));q(2001:2010)=1;
            r=run_motor_case('SwitchingLegTest',struct(),[q,3+zeros(size(t))],duration);r.metrics.high_gate_count=sum(r.trace.signals.values(:,4));assert(r.metrics.high_gate_count==0);records.switching_short_pulse=r;
            q=double(mod((0:numel(t)-1)',period)<500);current=0.15*sin(2*pi*1000*t+0.2);
            r=run_motor_case('SwitchingLegTest',struct(),[q,current],duration);v=r.trace.signals.values;
            bothOff=v(:,4)==0 & v(:,5)==0;
            r.metrics.diode_selection_error_V=max(abs(v(bothOff,3)-48*double(current(bothOff)<0)));
            r.metrics.shoot_through_count=sum(v(:,4)~=0 & v(:,5)~=0);
            assert(r.metrics.diode_selection_error_V==0&&r.metrics.shoot_through_count==0);
            records.switching_zero_crossing=r;
    end
    names=fieldnames(records);metrics=struct();
    for j=1:numel(names)
        record=records.(names{j});record.channels=flattenChannels(channels.(record.model).entries);
        assert(size(record.trace.signals.values,2)==numel(record.channels),'Channel table mismatch');
        records.(names{j})=record;metrics.(names{j})=record.metrics;
    end
    if strcmp(module,'experiment')
        folder=fullfile(modelRoot,'app_models','Sensor',module,'waveform_analysis');
    else
        folders=struct('pmsm_plant','永磁同步电机', ...
            'current_loop','电流环', ...
            'inverter','逆变器', ...
            'timing','采样执行时序', ...
            'motion_loop','运动环', ...
            'feedforward','电压前馈', ...
            'deadtime','死区补偿');
        folder=fullfile(modelRoot,'lib',folders.(module),'waveform_analysis');
    end
    if ~isfolder(folder),mkdir(folder);end
    summary.status='passed';summary.scenario_count=numel(names);summary.scenario_names=names;
    summary.metrics=metrics;summary.matlab_release=version('-release');
    summary.executed_at_utc=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss Z'));
    save(fullfile(folder,'results.mat'),'records','summary','-v7');
    fid=fopen(fullfile(folder,'metrics.json'),'w','n','UTF-8');assert(fid>=0);
    fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true));fclose(fid);
    plotModule(module,records,folder,channels);
    report.(module)=summary;
    fprintf('%s: %d cases passed\n',module,numel(names));
end
end

function metrics=currentMetrics(r)
v=r.trace.signals.values;t=r.trace.time;
metrics.final_error_A=max(abs(v(end,1:2)-v(end,3:4)));
metrics.peak_current_A=max(abs(v(:,3:4)),[],'all');
metrics.peak_voltage_V=max(vecnorm(v(:,7:8),2,2));
use=t>=0.012;metrics.recovery_iae_A_s=trapz(t(use),sum(abs(v(use,1:2)-v(use,3:4)),2));
end

function metrics=experimentMetrics(r)
v=r.trace.signals.values;t=r.trace.time;
metrics.final_current_error_A=max(abs(v(end,1:2)-v(end,3:4)));
metrics.peak_current_A=max(abs(v(:,3:4)),[],'all');
metrics.control_mode=r.parameters.experimentCfg.Mode;
metrics.final_speed_error_rad_s=NaN;metrics.final_position_error_rad=NaN;
if metrics.control_mode~=0,metrics.final_speed_error_rad_s=abs(v(end,30)-v(end,31));end
if metrics.control_mode==2,metrics.final_position_error_rad=abs(v(end,33)-v(end,34));end
metrics.current_iae_A_s=trapz(t,sum(abs(v(:,1:2)-v(:,3:4)),2));
use=t>=max(0,t(end)-0.1);
metrics.rms_window_start_s=t(find(use,1));metrics.rms_window_end_s=t(end);
metrics.tail_current_rms_A=sqrt(mean(sum((v(use,1:2)-v(use,3:4)).^2,2)));
metrics.minimum_duty=min(v(:,21:26),[],'all');metrics.maximum_duty=max(v(:,21:26),[],'all');
assert(metrics.minimum_duty>=-1e-12&&metrics.maximum_duty<=1+1e-12);
end

function result=flattenChannels(entries)
result={};
for k=1:numel(entries)
    for j=1:entries(k).width
        if entries(k).width==1,name=entries(k).name;else,name=sprintf('%s_%d',entries(k).name,j);end
        result{end+1}=name; %#ok<AGROW>
    end
end
end

function plotModule(module,records,folder,metadata)
names=fieldnames(records);name=names{1};
if strcmp(module,'motion_loop'),name='position_load_step';end
if strcmp(module,'experiment'),name='speed_reversal';end
r=records.(name);groups=metadata.(r.model).groups;
if strcmp(r.model,'MotorExperiment'),selected=[1,5,6];else,selected=1:min(3,numel(groups));end
f=figure('Visible','off','Color','w','Position',[80,80,1100,780]);
cleanup=onCleanup(@()close(f));
tiledlayout(numel(selected),1);
offsets=[0,cumsum([metadata.(r.model).entries.width])];
for j=selected
    columns=[];
    for entry=groups(j).columns(:)'
        columns=[columns,offsets(entry)+1:offsets(entry+1)]; %#ok<AGROW>
    end
    index=unique([1:ceil(numel(r.trace.time)/5000):numel(r.trace.time),numel(r.trace.time)]);
    nexttile;plot(r.trace.time(index),r.trace.signals.values(index,columns),'LineWidth',1);
    grid on;xlabel('Time (s)');ylabel(groups(j).unit);title([module,' / ',name,' / ',groups(j).name],'Interpreter','none');
    legend(r.channels(columns),'Interpreter','none','Location','best');
end
exportgraphics(f,fullfile(folder,'summary.png'),'Resolution',150);
exportgraphics(f,fullfile(folder,'summary.svg'),'ContentType','vector');
if strcmp(module,'feedforward')||strcmp(module,'deadtime')
    if strcmp(module,'feedforward'),off=records.loop_ff_off;on=records.loop_ff_on;else,off=records.loop_comp_off;on=records.loop_comp_on;end
    clf(f);tiledlayout(2,1);
    for axis=1:2
        nexttile;plot(off.trace.time,off.trace.signals.values(:,axis+2)-off.trace.signals.values(:,axis),on.trace.time,on.trace.signals.values(:,axis+2)-on.trace.signals.values(:,axis));
        if strcmp(module,'deadtime')
            hold on;narrow=records.loop_comp_narrow_blend;
            plot(narrow.trace.time,narrow.trace.signals.values(:,axis+2)-narrow.trace.signals.values(:,axis));
            legend({'disabled','enabled, blend 0.1 A','enabled, blend 0.01 A'});
        else
            legend({'disabled','enabled'});
        end
        axisNames={'d','q'};
        grid on;ylabel(sprintf('%s current error (A)',axisNames{axis}));
        title([module,' same-scenario comparison'],'Interpreter','none');xlabel('Time (s)');
    end
    exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',150);
    exportgraphics(f,fullfile(folder,'comparison.svg'),'ContentType','vector');
end
if strcmp(module,'deadtime')
    clf(f);tiledlayout(3,1);
    r=records.switching_positive;use=r.trace.time<3e-4;v=r.trace.signals.values;
    nexttile;stairs(r.trace.time(use),v(use,[1,4,5]));grid on;ylabel('gate');
    legend({'command','high gate','low gate'});
    nexttile;stairs(r.trace.time(use),v(use,3));grid on;ylabel('pole V');
    r=records.switching_zero_crossing;v=r.trace.signals.values;
    nexttile;yyaxis left;plot(r.trace.time,v(:,2));ylabel('current A');
    yyaxis right;stairs(r.trace.time,v(:,3));ylabel('pole V');grid on;xlabel('Time (s)');
    exportgraphics(f,fullfile(folder,'switching.png'),'Resolution',150);
    exportgraphics(f,fullfile(folder,'switching.svg'),'ContentType','vector');
end
end

function restoreCache(previous,folder)
Simulink.fileGenControl('setConfig','config',previous);
assert(startsWith(folder,tempdir)&&isfolder(folder));
rmdir(folder,'s');
end
