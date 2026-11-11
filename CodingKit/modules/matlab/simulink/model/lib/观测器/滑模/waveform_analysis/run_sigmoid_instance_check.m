function report=run_sigmoid_instance_check()
%RUN_SIGMOID_INSTANCE_CHECK Two library instances with different local masks.
module=initialize_sigmoid_smo_paths();probe='SigmoidSmoInstancesTest';assert(~bdIsLoaded(probe));
before=find_system('type','block_diagram');cleanup=onCleanup(@()close_added(before));
data=load(fullfile(module,'waveform_analysis','sigmoid_results.mat'),'records');a=data.records.positive;
test=sigmoid_smo_test_parameters();sigmoidA=a.configuration;pllA=a.pll;
sigmoidB=sigmoidA;sigmoidB.SlidingGain=test.InstanceGain;sigmoidB.Slope=test.InstanceSlope;sigmoidB=refresh_sigmoid_smo_parameters(sigmoidB);
pllB=pllA;pllB.Theta0=test.InstanceTheta;
stim=struct('time',a.time,'signals',struct('values',a.inputs(:,1:7),'dimensions',7));
new_system(probe);workspace=get_param(probe,'ModelWorkspace');
assignin(workspace,'sigmoidA',sigmoidA);assignin(workspace,'sigmoidB',sigmoidB);assignin(workspace,'pllA',pllA);assignin(workspace,'pllB',pllB);
assignin(workspace,'probeStim',stim);assignin(workspace,'sigmoidTestCfg',test);
ops={struct('op','configure','target',['config:',probe],'params',struct('Solver','FixedStepDiscrete','SolverType','Fixed-step', ...
    'FixedStep','sigmoidA.Ts','StopTime','sigmoidTestCfg.Duration','ReturnWorkspaceOutputs','on')), ...
    b('FromWorkspace','Stimulus',struct('VariableName','probeStim','Interpolate','off','SampleTime','sigmoidA.Ts','OutputAfterFinalValue','Holding final value')), ...
    b('Demux','Inputs',struct('Outputs','7')),c('#Stimulus.y1','#Inputs.u1')};
for letter={'A','B'}
    name=letter{1};ops=[ops,{struct('op','add_block','type','SigmoidSMO','ReferenceBlock','SigmoidSlidingModeObserver/SigmoidSMO', ...
        'name',name,'ref',name,'params',struct('MaskValueString',['sigmoid',name,'|pll',name])), ...
        b('Mux',['Trace',name],struct('Inputs','14')),b('ToWorkspace',['Save',name],struct('VariableName',['trace',name], ...
        'SaveFormat','Structure With Time','SampleTime','sigmoidA.Ts','MaxDataPoints','inf')),c(['#Trace',name,'.y1'],['#Save',name,'.u1'])}];
    for k=1:7,ops{end+1}=c(sprintf('#Inputs.y%d',k),sprintf('#%s.u%d',name,k));end
    for k=1:14,ops{end+1}=c(sprintf('#%s.y%d',name,k),sprintf('#Trace%s.u%d',name,k));end
end
disp(model_read(probe,'root','0'));result=model_edit(probe,'root',jsonencode(ops),'full');disp(result);disp(model_read(probe,'root','0'));
if ~contains(string(result),'status: ok'),disp(model_check(probe,'root','["all"]'));error('SigmoidInstance:Edit','%s',char(result));end
check=model_check(probe,'root','["all"]');disp(check);assert(~contains(string(check),'severity: error'));
in=Simulink.SimulationInput(probe);out=sim(in);parallelA=out.traceA;parallelB=out.traceB;
model='SigmoidSlidingModeObserverTest';in=Simulink.SimulationInput(model);
in=in.setVariable('sigmoidCfg',sigmoidB,'Workspace',model);in=in.setVariable('pllCfg',pllB,'Workspace',model);
fullStim=struct('time',a.time,'signals',struct('values',a.inputs,'dimensions',9));
in=in.setVariable('testStim',fullStim,'Workspace',model);out=sim(in);
differenceA=max(abs(parallelA.signals.values-a.trace(:,10:23)),[],'all');
differenceB=max(abs(parallelB.signals.values-out.trace.signals.values(:,10:23)),[],'all');
assert(isequal(parallelA.time,a.time) && isequal(parallelB.time,a.time));assert(differenceA==0 && differenceB==0);
assert(max(abs(parallelA.signals.values-parallelB.signals.values),[],'all')>1e-3);
paths=find_system(probe,'SearchDepth',1,'Type','SubSystem');
for k=1:numel(paths)
    name=get_param(paths{k},'Name');
    if ismember(name,{'A','B'})
        if strcmp(name,'A'),expected=sigmoidA;else,expected=sigmoidB;end
        maskVariables=get_param(paths{k},'MaskWSVariables');
        assert(isequal(maskVariables(strcmp({maskVariables.Name},'cfg')).Value,expected));
    end
end
report=struct('status','passed','checks',1,'parallel_A_difference',differenceA,'parallel_B_difference',differenceB, ...
    'different_instance_parameters',true,'mask_configuration_readback_matches',true,'temporary_model_saved',false);
save(fullfile(module,'waveform_analysis','sigmoid_instance_results.mat'),'parallelA','parallelB','sigmoidA','sigmoidB','pllA','pllB','report');
file=fopen(fullfile(module,'waveform_analysis','sigmoid_instance_metrics.json'),'w');fprintf(file,'%s',jsonencode(report,'PrettyPrint',true));fclose(file);
clear cleanup;
end
function close_added(before)
after=find_system('type','block_diagram');for k=1:numel(after),if ~ismember(after{k},before),close_system(after{k},0);end,end
end
function op=b(type,name,params)
op=struct('op','add_block','type',type,'name',name,'ref',name,'params',params);
end
function op=c(a,b)
op=struct('op','connect','target',[a,' -> ',b]);
end
