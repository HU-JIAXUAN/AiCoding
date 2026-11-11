function record=run_open_loop_app_case(kind,p,stimulus)
%RUN_OPEN_LOOP_APP_CASE Keep exact traces in RAM; caller chooses compact export.
p=refresh_open_loop_app_parameters(p);spec=open_loop_app_spec(kind);
assert(size(stimulus.signals.values,2)==5&&numel(stimulus.time)==round(p.experimentCfg.Duration/p.currentCfg.Ts)+1);
addpath(fullfile(spec.module,'src'));wasLoaded=bdIsLoaded(spec.model);
cleanup=onCleanup(@()finish(spec.model,wasLoaded));
in=Simulink.SimulationInput(spec.model);fields=fieldnames(p);
for k=1:numel(fields),in=in.setVariable(fields{k},p.(fields{k}),'Workspace',spec.model);end
sourceStimulus=stimulus;sourceStimulus.time=[];
in=in.setVariable('testStim',sourceStimulus,'Workspace',spec.model);
out=sim(in);defs=open_loop_app_channels(kind);last=cumsum(cell2mat(defs(:,2)));first=[1;last(1:end-1)+1];
columns=struct();for k=1:size(defs,1),columns.(defs{k,1})=first(k):last(k);end
record=struct('parameters',p,'stimulus',stimulus,'time',out.app_trace.time, ...
    'trace',matrix(out.app_trace,last(end)),'columns',columns,'physical_time',out.physical_trace.time, ...
    'physical_trace',matrix(out.physical_trace,4));
assert(size(record.trace,2)==last(end)&&all(isfinite(record.trace),'all')&&all(isfinite(record.physical_trace),'all'));
end
function finish(model,wasLoaded)
if ~wasLoaded&&bdIsLoaded(model),close_system(model,0);end
end

function values=matrix(raw,width)
if ismatrix(raw.signals.values)&&size(raw.signals.values,1)==numel(raw.time)
    values=raw.signals.values;
else
    values=reshape(raw.signals.values,width,[])';
end
assert(size(values,2)==width&&size(values,1)==numel(raw.time));
end
