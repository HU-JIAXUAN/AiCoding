function report=run_frame_blend_validation()
%RUN_FRAME_BLEND_VALIDATION Compare the compiled blend in physical alpha/beta.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
model='FrameBlendTest';if ~bdIsLoaded(model),open_system(fullfile(module,'src',[model,'.slx']));end
names={'explicit_examples','randomized_vectors'};metrics=cell(1,2);records=struct();
for test=1:2
    cfg=blend_test_parameters();u=cfg.Inputs;
    if test==2
        stream=RandStream('mt19937ar','Seed',42);u=10*rand(stream,500,9)-5;
        u(:,5:6)=4*pi*rand(stream,500,2)-2*pi;u(:,7)=2*rand(stream,500,1)-0.5;
        u(:,8)=double(mod((1:500)',7)~=0);u(:,9)=double(mod((1:500)',11)==0);
        cfg.Inputs=u;cfg.Duration=(size(u,1)-1)*cfg.Ts;
    end
    stimulus.time=(0:size(u,1)-1)'*cfg.Ts;
    stimulus.signals.values=u;stimulus.signals.dimensions=9;
    input=Simulink.SimulationInput(model);
    input=input.setVariable('blendTestCfg',cfg,'Workspace',model);
    input=input.setVariable('testStim',stimulus,'Workspace',model);
    result=sim(input);value=result.trace.signals.values;time=result.trace.time;
    assert(prod(result.trace.signals.dimensions)==11);
    if ismatrix(value) && size(value,1)==numel(time) && size(value,2)==11,trace=value;
    else,trace=reshape(value,11,[])';end
    assert(isequal(trace(:,1:9),u) && all(isfinite(trace),'all'));
    expected=zeros(size(u,1),2);actual=expected;bound=zeros(size(u,1),1);
    for sample=1:size(u,1)
        controlRotation=rotation(u(sample,6));
        actual(sample,:)=(controlRotation*trace(sample,10:11)')';
        if u(sample,8)>=0.5 && u(sample,9)<=0.5
            beta=min(max(u(sample,7),0),1);
            startPhysical=rotation(u(sample,5))*u(sample,1:2)';
            closedPhysical=controlRotation*u(sample,3:4)';
            expected(sample,:)=((1-beta)*startPhysical+beta*closedPhysical)';
            bound(sample)=(1-beta)*norm(u(sample,1:2))+beta*norm(u(sample,3:4));
        end
    end
    maximumError=max(abs(actual-expected),[],'all');
    assert(maximumError<1e-12 && all(vecnorm(trace(:,10:11),2,2)<=bound+1e-12));
    inactive=u(:,8)<0.5 | u(:,9)>0.5;assert(all(trace(inactive,10:11)==0,'all'));
    metric=struct('name',names{test},'passed',true,'vectors',size(u,1),'max_physical_error_A',maximumError);
    metrics{test}=metric;records.(names{test})=struct('time',time,'trace',trace,'parameters',cfg, ...
        'expected_physical',expected,'actual_physical',actual,'metric',metric);
end
metrics=[metrics{:}];report=struct('release',version('-release'),'passed',true,'case_count',2, ...
    'vector_count',sum([metrics.vectors]),'cases',metrics);
save(fullfile(module,'waveform_analysis','frame_blend_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','frame_blend_metrics.json'),'w');
cleanup=onCleanup(@()fclose(file));fwrite(file,jsonencode(report,PrettyPrint=true));clear cleanup
figureHandle=figure('Visible','off','Position',[100,100,1000,750]);
cleanup=onCleanup(@()close(figureHandle));r=records.explicit_examples;
tiledlayout(3,1);nexttile;stairs(r.time,r.trace(:,10:11));ylabel('reference (A)');legend('d','q');grid on
nexttile;stairs(r.time,r.trace(:,5:6));ylabel('angle (rad)');legend('start','control');grid on
nexttile;stairs(r.time,r.trace(:,7:9));ylabel('weight / flag');legend('raw beta','enable','reset');xlabel('time (s)');grid on
exportgraphics(figureHandle,fullfile(module,'waveform_analysis','frame_blend.png'));
exportgraphics(figureHandle,fullfile(module,'waveform_analysis','frame_blend.svg'),ContentType='vector');
disp(report);
end
function matrix=rotation(angle)
matrix=[cos(angle),-sin(angle);sin(angle),cos(angle)];
end
