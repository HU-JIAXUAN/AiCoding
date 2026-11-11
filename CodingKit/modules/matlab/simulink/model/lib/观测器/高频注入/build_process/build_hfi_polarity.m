function build_hfi_polarity()
%BUILD_HFI_POLARITY Append the dual-pulse polarity state machine to the HFI lib.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'));
model='HighFrequencyObserver';load_system(model);disp(model_read(model,'root','0'));
assert(isempty(find_system(model,'SearchDepth',1,'Name','PolarityPulse')),'Polarity block already exists.');
edit(model,'root',{struct('op','configure','target',['config:',model],'params',struct('Lock','off'))});
result=edit(model,'root',{struct('op','create_subsystem','name','PolarityPulse','ref','core','interface',struct('inputs',{{}},'outputs',{{}}))});
scope=id(result,'core');
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','on','MaskVariables','cfg=@1;', ...
    'MaskStyleString','edit','MaskPromptString','Dual pulse polarity configuration','MaskValueString','hfi_polarity_parameters()'))});
inputs={'u_alpha','u_beta','i_alpha','i_beta','theta_axis','omega_axis','axis_valid','saliency_qualified','enable','reset'};
outputs={'pulse_alpha','pulse_beta','injection_scale','theta_full','position_valid','polarity_known','flip_pi','stage', ...
    'peak_positive','peak_negative','peak_difference','dose_positive','dose_negative','fault_code','frozen_axis','filtered_speed'};
ops={};
for k=1:numel(inputs),ops{end+1}=b('Inport',inputs{k},struct('Port',num2str(k),'SampleTime','cfg.Ts'));end
for k=1:numel(outputs),ops{end+1}=b('Outport',outputs{k},struct('Port',num2str(k)));end
ops=[ops,{b('MATLAB Function','PolarityUpdate',struct()),b('MATLAB Function','PolarityOutput',struct())}];
result=edit(model,scope,ops);names=[inputs,outputs,{'PolarityUpdate','PolarityOutput'}];ports=struct();
for k=1:numel(names),ports.(names{k})=id(result,names{k});end
for entry={'Update','Output'}
    path=Simulink.ID.getFullName([model,':',extractAfter(ports.(['Polarity',entry{1}]),'blk_')]);
    configuration=get_param(path,'MATLABFunctionConfiguration');configuration.FunctionScript=fileread(fullfile(module,'src',['hfi_polarity_',lower(entry{1}),'.m']));
end
disp(model_read(model,scope,'0'));
ops={b('Mux','VoltageAB',struct('Inputs','2')),b('Mux','CurrentAB',struct('Inputs','2')), ...
    b('UnitDelay','PolarityStates',struct('InitialCondition','cfg.InitialState','SampleTime','cfg.Ts')), ...
    b('Constant','Settings',struct('Value','cfg.Settings')),b('Logic','NotReset',struct('Operator','NOT')), ...
    b('Logic','Active',struct('Operator','AND','Inputs','2')),b('Demux','OutputSignals',struct('Outputs','16')), ...
    b('Sum','FullAngleSum',struct('Inputs','++')),b('Trigonometry','FullAngleSin',struct('Operator','sin')), ...
    b('Trigonometry','FullAngleCos',struct('Operator','cos')),b('Trigonometry','FullAngleWrap',struct('Operator','atan2')), ...
    b('Logic','FullValid',struct('Operator','AND','Inputs','2')),b('DataTypeConversion','FullValidDouble',struct('OutDataTypeStr','double'))};
edges={'u_alpha','VoltageAB',1;'u_beta','VoltageAB',2;'i_alpha','CurrentAB',1;'i_beta','CurrentAB',2; ...
    'reset','NotReset',1;'NotReset','Active',2;'enable','Active',1; ...
    'PolarityStates','PolarityUpdate',1;'CurrentAB','PolarityUpdate',2;'VoltageAB','PolarityUpdate',3; ...
    'theta_axis','PolarityUpdate',4;'omega_axis','PolarityUpdate',5;'axis_valid','PolarityUpdate',6; ...
    'saliency_qualified','PolarityUpdate',7;'Active','PolarityUpdate',8;'Settings','PolarityUpdate',9; ...
    'PolarityUpdate','PolarityStates',1;'PolarityStates','PolarityOutput',1;'saliency_qualified','PolarityOutput',2; ...
    'Active','PolarityOutput',3;'Settings','PolarityOutput',4;'PolarityOutput','OutputSignals',1; ...
    'theta_axis','FullAngleSum',1;'FullAngleSum','FullAngleSin',1;'FullAngleSum','FullAngleCos',1; ...
    'FullAngleSin','FullAngleWrap',1;'FullAngleCos','FullAngleWrap',2;'axis_valid','FullValid',2; ...
    'FullValid','FullValidDouble',1;'FullAngleWrap','theta_full',1;'FullValidDouble','position_valid',1};
for k=1:size(edges,1),ops{end+1}=c(['#',edges{k,1},'.y1'],sprintf('#%s.u%d',edges{k,2},edges{k,3}));end
ops=[ops,{c('#OutputSignals.y4','#FullAngleSum.u2'),c('#OutputSignals.y5','#FullValid.u1')}];
for k=[1:3,6:numel(outputs)],ops{end+1}=c(sprintf('#OutputSignals.y%d',k),['#',outputs{k},'.u1']);end
for k=1:numel(ops)
    if isfield(ops{k},'target')
        for n=1:numel(names),ops{k}.target=strrep(ops{k}.target,['#',names{n},'.'],[ports.(names{n}),'.']);end
    end
end
edit(model,scope,ops);
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','off'))});
disp(model_read(model,scope,'0'));health=model_check(model,scope,'["all"]');disp(health);assert(contains(string(health),'status: healthy'));
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','on','MaskVariables','cfg=@1;', ...
    'MaskStyleString','edit','MaskPromptString','Dual pulse polarity configuration','MaskValueString','polarityCfg','Position','[200 1200 540 1660]'))});
save_system(model);close_system(model,0);
end
function result=edit(model,scope,operations)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(operations),'incremental');disp(result);disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok'),disp(model_check(model,scope,'["all"]'));error('HFI:Edit','%s',char(result));end
end
function operation=b(type,name,params)
operation=struct('op','add_block','type',type,'name',name,'ref',name,'params',params);
end
function operation=c(source,destination)
operation=struct('op','connect','target',[source,' -> ',destination]);
end
function value=id(result,reference)
matches=regexp(char(result),['(?m)^[ \t]*',regexptranslate('escape',reference),':[ \t]*(blk_\d+)'],'tokens');assert(isscalar(matches));value=matches{1}{1};
end
