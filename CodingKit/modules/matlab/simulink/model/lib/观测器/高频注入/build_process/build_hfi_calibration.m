function build_hfi_calibration()
%BUILD_HFI_CALIBRATION Extend an existing HFIAxis and its bench with measured L.
assert(strcmp(version('-release'),'2026b'));gate=library.settingsLookup();assert(gate.gatePass);
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')), ...
    fullfile(lib,'相位跟踪','src'),fullfile(lib,'相位跟踪','parameter'));
model='HighFrequencyObserver';load_system(model);disp(model_read(model,'root','0'));
scope=block_id(model,'HFIAxis');
edit(model,'root',{struct('op','configure','target',['config:',model],'params',struct('Lock','off')), ...
    struct('op','configure','target',scope,'params',struct('Mask','on','MaskVariables','cfg=@1;trackerCfg=@2;', ...
    'MaskStyleString','edit,edit','MaskPromptString','HFI axis configuration|Doubled phase PLL configuration', ...
    'MaskValueString','hfi_parameters()|hfi_pll_parameters(hfi_parameters())'))});
axisPath=Simulink.ID.getFullName([model,':',extractAfter(scope,'blk_')]);
assert(isempty(find_system(axisPath,'LookUnderMasks','all','SearchDepth',1,'Name','inverse_average_external')),'Already extended.');
found=find_system(axisPath,'LookUnderMasks','all','SearchDepth',1,'Name','Demodulate');assert(isscalar(found));
sid=Simulink.ID.getSID(found{1});demod=['blk_',extractAfter(sid,':')];
configuration=get_param(found{1},'MATLABFunctionConfiguration');configuration.FunctionScript=fileread(fullfile(module,'src','hfi_demodulate.m'));
disp(model_read(model,scope,'0'));
ops={struct('op','add_block','type','Inport','name','inverse_average_external','ref','external', ...
    'params',struct('Port','8','SampleTime','cfg.Ts')), ...
    struct('op','add_block','type','Outport','name','inverse_average_used','ref','used','params',struct('Port','15')), ...
    c('#external.y1',[demod,'.u12']),c([demod,'.y7'],'#used.u1')};
edit(model,scope,ops);
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','off'))});
disp(model_read(model,scope,'0'));health=model_check(model,scope,'["all"]');disp(health);assert(contains(string(health),'status: healthy'));
edit(model,'root',{struct('op','configure','target',scope,'params',struct('Mask','on','MaskVariables','cfg=@1;trackerCfg=@2;', ...
    'MaskStyleString','edit,edit','MaskPromptString','HFI axis configuration|Doubled phase PLL configuration','MaskValueString','hfiCfg|pllCfg'))});
save_system(model);close_system(model,0);
test='HFIAxisTest';open_system(fullfile(module,'src',[test,'.slx']));initialize_hfi_test(test);
disp(model_read(test,'root','0'));observer=block_id(test,'Observer');trace=block_id(test,'TraceChannels');
ops={struct('op','configure','target',trace,'params',struct('Inputs','38')), ...
    struct('op','add_block','type','Constant','name','ExternalInverseAverage','ref','external','params',struct('Value','hfiTestCfg.ExternalInverseAverage')), ...
    struct('op','add_block','type','Constant','name','NominalInverseAverage','ref','nominal','params',struct('Value','hfiCfg.InverseAverage')), ...
    struct('op','add_block','type','Mux','name','CalibrationChannels','ref','channels','params',struct('Inputs','3')), ...
    struct('op','add_block','type','Scope','name','CalibrationScope','ref','scope','params',struct('NumInputPorts','1')), ...
    c('#external.y1',[observer,'.u8']),c([observer,'.y15'],[trace,'.u38']), ...
    c('#nominal.y1','#channels.u1'),c('#external.y1','#channels.u2'),c([observer,'.y15'],'#channels.u3'),c('#channels.y1','#scope.u1')};
edit(test,'root',ops);health=model_check(test,'root','["all"]');disp(health);assert(contains(string(health),'status: healthy'));
save_system(test);close_system(test,0);
end
function result=edit(model,scope,operations)
disp(model_read(model,scope,'0'));result=model_edit(model,scope,jsonencode(operations),'incremental');disp(result);disp(model_read(model,scope,'0'));
if ~contains(string(result),'status: ok'),disp(model_check(model,scope,'["all"]'));error('HFI:Edit','%s',char(result));end
end
function operation=c(source,destination)
operation=struct('op','connect','target',[source,' -> ',destination]);
end
function id=block_id(model,name)
found=find_system(model,'SearchDepth',1,'Name',name);assert(isscalar(found));
sid=Simulink.ID.getSID(found{1});id=['blk_',extractAfter(sid,':')];
end
