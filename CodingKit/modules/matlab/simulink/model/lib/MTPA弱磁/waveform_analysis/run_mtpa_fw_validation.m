function summary = run_mtpa_fw_validation(section)
%RUN_MTPA_FW_VALIDATION Saved-model MTPA, dynamic weakening and motor checks.
%   SECTION is 'all' (default), 'mtpa', 'fw', or 'motor'. Results are real
%   SimulationOutput traces; scalar optimization is an independent oracle.
if nargin==0,section='all';end
assert(ismember(section,{'all','mtpa','fw','motor'}));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'build_process'),fullfile(module,'parameter'));
open_system(fullfile(module,'src','CurrentReferenceTest.slx'));
rejected=checkRejectedParameters();
metadata=jsondecode(fileread(fullfile(module,'build_process','model_channels.json')));
old=Simulink.fileGenControl('getConfig');temporary=tempname;mkdir(temporary);
cleanup=onCleanup(@()restoreCache(old,temporary));
Simulink.fileGenControl('set','CacheFolder',fullfile(temporary,'cache'), ...
    'CodeGenFolder',fullfile(temporary,'code'),'createDir',true);
folder=fullfile(module,'waveform_analysis');records=struct();
if ~strcmp(section,'all')&&isfile(fullfile(folder,'results.mat'))
    previous=load(fullfile(folder,'results.mat'),'records');records=previous.records;
end
groups={'mtpa','fw','motor'};if ~strcmp(section,'all'),groups={char(section)};end
for group=groups
    cases=struct();
    switch group{1}
        case 'mtpa'
            t=(0:1e-4:0.06)';z=zeros(size(t));torque=linspace(-1.5,1.5,numel(t))';
            u=[torque,z,48+z,z,1+z,z];o.refCfg=struct('FwEnable',0);
            r=execute('CurrentReferenceTest',o,u,0.06,metadata);r.metrics.oracle_error_A=oracleError(r);
            assert(r.metrics.oracle_error_A<2e-4);cases.original_bipolar=r;
            o.pmsmCfg=struct('Lq',6e-3);
            r=execute('CurrentReferenceTest',o,u,0.06,metadata);r.metrics.oracle_error_A=oracleError(r);
            assert(r.metrics.oracle_error_A<2e-4);cases.salient_mtpa=r;
            o.refCfg.MtpaEnable=0;
            r=execute('CurrentReferenceTest',o,u,0.06,metadata);
            assert(max(abs(channel(r,'id_reference')))<1e-12);cases.salient_id_zero=r;
            take=abs(torque)>1;
            ratio=mean(hypot(channel(cases.salient_mtpa,'id_reference'),channel(cases.salient_mtpa,'iq_reference'))./ ...
                max(hypot(channel(r,'id_reference'),channel(r,'iq_reference')),1e-9),'omitnan');
            selectedRatio=mean(hypot(channel(cases.salient_mtpa,'id_reference',take),channel(cases.salient_mtpa,'iq_reference',take))./ ...
                hypot(channel(r,'id_reference',take),channel(r,'iq_reference',take)));
            assert(selectedRatio<0.98,'Salient MTPA current benefit');
            cases.salient_mtpa.metrics.mean_current_ratio_all=ratio;
            cases.salient_mtpa.metrics.mean_current_ratio_above_1Nm=selectedRatio;
            o=struct();o.refCfg=struct('FwEnable',0);o.pmsmCfg=struct('Lq',1e-3);
            r=execute('CurrentReferenceTest',o,u,0.06,metadata);
            assert(max(abs(channel(r,'id_reference')))<1e-12);cases.spm_limit=r;
            o.pmsmCfg.Lq=1e-3+1e-12;r=execute('CurrentReferenceTest',o,u,0.06,metadata);
            assert(max(abs(channel(r,'id_reference')))<1e-6);cases.tiny_saliency=r;
            o.pmsmCfg.Lq=6e-3;o.refCfg.IdMin=-1;
            r=execute('CurrentReferenceTest',o,u,0.06,metadata);r.metrics.oracle_error_A=oracleError(r);
            assert(min(channel(r,'id_reference'))>=-1-1e-9&&r.metrics.oracle_error_A<2e-4);cases.negative_id_bound=r;
            o=struct();o.refCfg=struct('FwEnable',1);u(:,1)=100*sign(torque);
            r=execute('CurrentReferenceTest',o,u,0.06,metadata);
            assert(any(channel(r,'current_limited')>0)&&max(abs(channel(r,'id_fw')))<1e-10);
            cases.high_torque_low_speed=r;
        case 'fw'
            t=(0:1e-4:0.5)';z=zeros(size(t));we=300+500*double(t>=0.05 & t<0.25);
            u=[0.2+z,we,48+z,z,1+z,z];
            r=execute('CurrentReferenceTest',struct(),u,0.5,metadata);
            assert(min(channel(r,'id_fw'))<-2&&abs(channel(r,'id_fw',numel(t)))<1e-9);
            cases.entry_exit=r;
            bus=48-4*double(t>=0.1 & t<0.28)+2*double(t>=0.28);
            u=[0.2+z,800+z,bus,z,1+z,z];r=execute('CurrentReferenceTest',struct(),u,0.5,metadata);
            assert(any(channel(r,'voltage_limited',t>=0.1 & t<0.28)>0));
            assert(abs(channel(r,'allocated_torque',numel(t))-0.2)<0.005);cases.bus_step=r;
            for direction=[1,-1]
                for torqueDirection=[1,-1]
                    short=(0:1e-4:0.25)';v=zeros(size(short));
                    u=[0.2*torqueDirection+v,800*direction+v,48+v,v,1+v,v];
                    r=execute('CurrentReferenceTest',struct(),u,0.25,metadata);
                    assert(channel(r,'feasible',numel(short))==1);
                    assert(abs(channel(r,'allocated_torque',numel(short))-0.2*torqueDirection)<0.005);
                    key=sprintf('quadrant_w%d_t%d',direction,torqueDirection);key=strrep(key,'-','m');
                    cases.(key)=r;
                end
            end
            t=(0:1e-4:0.25)';z=zeros(size(t));u=[z,800+z,48+z,z,1+z,z];
            r=execute('CurrentReferenceTest',struct(),u,0.25,metadata);
            assert(max(abs(channel(r,'iq_reference')))<1e-12&&min(channel(r,'id_fw'))<-2);
            assert(channel(r,'feasible',numel(t))==1,'Zero-torque weakening must enter the voltage feasible region');
            cases.zero_torque=r;
            u(:,1)=0.2;u(:,2)=1400;
            r=execute('CurrentReferenceTest',struct(),u,0.25,metadata);
            assert(channel(r,'feasible',numel(t))==0&&abs(channel(r,'id_fw',numel(t))+7)<1e-9);
            assert(channel(r,'allocated_torque',numel(t))==0);cases.infeasible_speed=r;
            u(:,2)=800;u(:,5)=double(~(t>=0.1 & t<0.15));u(:,6)=double(t>=0.2 & t<0.21);
            r=execute('CurrentReferenceTest',struct(),u,0.25,metadata);inactive=u(:,5)==0 | u(:,6)==1;
            assert(all(channel(r,'id_reference',inactive)==0)&&all(channel(r,'iq_reference',inactive)==0));
            assert(all(channel(r,'id_fw',inactive)==0)&&all(channel(r,'filtered_voltage',inactive)==0));cases.disable_reset=r;
            u=[0.2+z,500+z,48+z,28*double(t>=0.03 & t<0.1),1+z,z];
            r=execute('CurrentReferenceTest',struct(),u,0.25,metadata);
            assert(min(channel(r,'id_fw'))<-1&&abs(channel(r,'id_fw',numel(t)))<1e-9);cases.voltage_feedback_branch=r;
            u=[0.2+z,800+z,z,z,1+z,z];r=execute('CurrentReferenceTest',struct(),u,0.25,metadata);
            assert(all(channel(r,'feasible')==0));cases.zero_bus_infeasible=r;
        case 'motor'
            o=struct();o.refCfg=struct('FwEnable',0);
            r=execute('MTPAFWMotor',o,[],2,metadata);cases.fw_off=r;
            r=execute('MTPAFWMotor',struct(),[],2,metadata);
            assert(abs(channel(r,'speed_truth',numel(r.trace.time))-218)<0.3);
            assert(channel(r,'speed_truth',numel(r.trace.time))-channel(cases.fw_off,'speed_truth',numel(cases.fw_off.trace.time))>20);
            assert(channel(r,'id_reference',numel(r.trace.time))<-4);cases.fw_on=r;
            o=struct();o.experimentCfg=struct('SpeedReference',-218,'LoadTorque',-0.05);
            r=execute('MTPAFWMotor',o,[],2,metadata);
            assert(abs(channel(r,'speed_truth',numel(r.trace.time))+218)<0.3);cases.reverse_rotation=r;
            o=struct();o.experimentCfg=struct('SpeedInitial',218,'SpeedReference',100,'CommandTime',1.25);
            r=execute('MTPAFWMotor',o,[],2.5,metadata);
            assert(min(channel(r,'id_fw'))<-1&&abs(channel(r,'id_fw',numel(r.trace.time)))<1e-9);
            assert(abs(channel(r,'speed_truth',numel(r.trace.time))-100)<0.5);cases.exit_weakening=r;
            o=struct();o.inverterCfg=struct('Vdc',42);o.experimentCfg=struct('SpeedReference',190,'LoadTorque',0.03);
            r=execute('MTPAFWMotor',o,[],2,metadata);
            assert(abs(channel(r,'speed_truth',numel(r.trace.time))-190)<0.5);cases.bus_42V=r;
            o=struct();o.experimentCfg=struct('SpeedReference',250);
            r=execute('MTPAFWMotor',o,[],2,metadata);
            assert(channel(r,'speed_truth',numel(r.trace.time))<240);
            assert(abs(channel(r,'id_fw',numel(r.trace.time))+7)<0.01);cases.unattainable_aw_on=r;
            o.refCfg=struct('SpeedKaw',0);
            r=execute('MTPAFWMotor',o,[],2,metadata);cases.unattainable_aw_off=r;
            on=abs(channel(cases.unattainable_aw_on,'speed_pi_integral',numel(r.trace.time)));
            off=abs(channel(r,'speed_pi_integral',numel(r.trace.time)));
            assert(on<0.5*off,'Allocated torque feedback must reduce speed integral windup');
    end
    records.(group{1})=cases;
    summary=makeSummary(records);summary.rejected_configuration_count=rejected;
    save(fullfile(folder,'results.mat'),'records','summary','-v7');
    fid=fopen(fullfile(folder,'metrics.json'),'w','n','UTF-8');assert(fid>=0);
    fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true));fclose(fid);
    fprintf('%s: %d cases passed\n',group{1},numel(fieldnames(cases)));
end
end

function r=execute(model,o,u,duration,metadata)
r=run_mtpa_fw_case(model,o,u,duration);
entries=metadata.(model).entries;r.channels={};
for k=1:numel(entries)
    if iscell(entries),entry=entries{k};else,entry=entries(k);end
    for j=1:entry.width
        name=entry.name;if entry.width>1,name=sprintf('%s_%d',name,j);end
        r.channels{end+1}=name;
    end
end
assert(size(r.trace.signals.values,2)==numel(r.channels));
id=channel(r,'id_reference');iq=channel(r,'iq_reference');
motor=r.parameters.pmsmCfg;cfg=r.parameters.refCfg;
assert(max(hypot(id,iq))<=cfg.CurrentMax+1e-8);
assert(min(id)>=cfg.IdMin-1e-8&&max(id)<=1e-8);
torque=1.5*motor.PolePairs*(motor.Flux+(motor.Ld-motor.Lq)*id).*iq;
assert(max(abs(torque-channel(r,'allocated_torque')))<1e-9);
if strcmp(model,'MTPAFWMotor'),we=channel(r,'electrical_speed_feedback');else,we=channel(r,'omega_e');end
voltage=hypot(motor.Rs*id-we*motor.Lq.*iq,motor.Rs*iq+we.*(motor.Ld*id+motor.Flux));
valid=channel(r,'feasible')~=0;
assert(all(voltage(valid)<=channel(r,'voltage_available',valid)+1e-8));
assert(all(channel(r,'current_margin')>=-1e-8));
r.metrics.final_id_A=id(end);r.metrics.final_iq_A=iq(end);
r.metrics.peak_reference_current_A=max(hypot(id,iq));
r.metrics.minimum_id_A=min(id);
r.metrics.final_allocated_torque_Nm=torque(end);
r.metrics.final_feasible=logical(valid(end));
r.metrics.minimum_feasible_voltage_margin_V=NaN;
if any(valid),r.metrics.minimum_feasible_voltage_margin_V=min(channel(r,'voltage_available',valid)-voltage(valid));end
step=round(cfg.FwTs/r.parameters.currentCfg.Ts);
field=channel(r,'id_fw');active=channel(r,'enable')~=0 & channel(r,'reset')==0;
if strcmp(model,'MTPAFWMotor'),active=active & cfg.FwEnable~=0;end
index=1:step:numel(field);delta=diff(field(index));both=active(index(1:end-1)) & active(index(2:end));
assert(all(abs(delta(both))<=cfg.IdSlew*cfg.FwTs+1e-8));
if strcmp(model,'MTPAFWMotor')
    r.metrics.final_speed_rad_s=channel(r,'speed_truth',numel(id));
    r.metrics.final_speed_error_rad_s=abs(channel(r,'speed_request',numel(id))-r.metrics.final_speed_rad_s);
    r.metrics.final_speed_integral_Nm=channel(r,'speed_pi_integral',numel(id));
    r.metrics.peak_actual_current_A=max(hypot(channel(r,'id_truth'),channel(r,'iq_truth')));
    tail=r.trace.time>=duration-0.1;
    r.metrics.tail_current_error_rms_A=sqrt(mean((channel(r,'id_truth',tail)-id(tail)).^2+(channel(r,'iq_truth',tail)-iq(tail)).^2));
end
end

function error=oracleError(r)
motor=r.parameters.pmsmCfg;cfg=r.parameters.refCfg;error=0;
take=unique(round(linspace(1,numel(r.trace.time),31)));
for index=take
    torque=abs(channel(r,'allocated_torque',index));
    objective=@(id)id.^2+(torque./(1.5*motor.PolePairs*(motor.Flux+(motor.Ld-motor.Lq)*id))).^2;
    optimum=fminbnd(objective,cfg.IdMin,0,optimset('TolX',1e-10,'Display','off'));
    reference=sqrt(objective(optimum));
    actual=hypot(channel(r,'id_reference',index),channel(r,'iq_reference',index));
    error=max(error,abs(reference-actual));
end
end

function value=channel(r,name,index)
column=find(strcmp(r.channels,name),1);assert(~isempty(column),'Unknown channel: %s',name);
value=r.trace.signals.values(:,column);if nargin>=3,value=value(index);end
end

function s=makeSummary(records)
s.status='passed';s.scenario_count=0;s.group_counts=struct();s.metrics=struct();
groups=fieldnames(records);
for k=1:numel(groups)
    group=groups{k};names=fieldnames(records.(group));s.group_counts.(group)=numel(names);
    s.scenario_count=s.scenario_count+numel(names);
    for j=1:numel(names),s.metrics.(group).(names{j})=records.(group).(names{j}).metrics;end
end
if numel(groups)<3,s.status='partial';end
s.matlab_release=version('-release');
s.executed_at_utc=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss Z'));
end

function restoreCache(config,folder)
Simulink.fileGenControl('setConfig','config',config);
assert(startsWith(folder,tempdir)&&isfolder(folder));rmdir(folder,'s');
end

function count=checkRejectedParameters()
p=reference_case_parameters('CurrentReferenceTest');count=0;
for k=1:5
    cfg=p.refCfg;motor=p.pmsmCfg;
    switch k
        case 1,motor.Lq=motor.Ld/2;
        case 2,cfg.IdMin=-9;
        case 3,cfg.CurrentMax=0;
        case 4,cfg.MtpaEnable=2;
        case 5,cfg.FwVoltageMargin=-0.1;
    end
    rejected=false;
    try
        refresh_mtpa_tables(cfg,motor);
    catch
        rejected=true;
    end
    assert(rejected,'Invalid configuration %d must be rejected',k);count=count+1;
end
end
