function record=run_sensorless_fw_case(p,stimulus)
%RUN_SENSORLESS_FW_CASE Simulate a hidden App with nonpersistent overrides.
if nargin<1,p=sensorless_fw_parameters();end
p=refresh_sensorless_fw_parameters(p);
if nargin<2,stimulus=sensorless_fw_stimulus(p);end
assert(size(stimulus.signals.values,2)==7 && all(isfinite(stimulus.signals.values),'all'));
assert(all(stimulus.signals.values(:,7)>0));
assert(all(ismember(stimulus.signals.values(:,[3,4,6]),[0,1]),'all'));
assert(all(ismember(stimulus.signals.values(:,5),[-1,1])));
assert(numel(stimulus.time)==round(p.experimentCfg.Duration/p.currentCfg.Ts)+1);
module=fileparts(fileparts(mfilename('fullpath')));model='SensorlessFieldWeakeningFOC';
alreadyLoaded=bdIsLoaded(model);
if ~alreadyLoaded,load_system(fullfile(module,'src',[model '.slx']));end
cleanup=onCleanup(@()finish(model,alreadyLoaded));
input=Simulink.SimulationInput(model);names=fieldnames(p);
for k=1:numel(names),input=input.setVariable(names{k},p.(names{k}),'Workspace',model);end
input=input.setVariable('testStim',stimulus,'Workspace',model);
timer=tic;output=sim(input);elapsed=toc(timer);
record=struct('release',version('-release'),'parameters',p,'stimulus',stimulus,'host_seconds',elapsed);
for scope={'plant','observer','controller','allocation','actuation','guard'}
    name=scope{1};raw=output.get([name '_trace']);definitions=sensorless_fw_channels(name);
    last=cumsum(cell2mat(definitions(:,3)));first=[1;last(1:end-1)+1];
    assert(prod(raw.signals.dimensions)==last(end));
    if ismatrix(raw.signals.values)&&size(raw.signals.values,1)==numel(raw.time),trace=raw.signals.values;
    else,trace=reshape(raw.signals.values,last(end),[])';end
    assert(size(trace,2)==last(end)&&all(isfinite(trace),'all'));
    columns=struct();for k=1:size(definitions,1),columns.(definitions{k,1})=first(k):last(k);end
    record.(name)=struct('time',raw.time,'trace',trace,'columns',columns,'definitions',{definitions});
end
assert(isequal(record.actuation.trace(:,record.actuation.columns.stimulus),stimulus.signals.values));
end
function finish(model,alreadyLoaded)
if ~alreadyLoaded&&bdIsLoaded(model),close_system(model,0);end
end
