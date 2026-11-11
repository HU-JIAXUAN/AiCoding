function record=run_bridge_bus_case(p,stimulus)
%RUN_BRIDGE_BUS_CASE Override a linked dynamic-bus physical test via local M.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'));
if nargin<1,p=bridge_bus_test_parameters();end
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
if nargin<2,stimulus=bridge_bus_stimulus(p);end
assert(size(stimulus.signals.values,2)==6 && all(isfinite(stimulus.signals.values),'all'));
assert(numel(stimulus.time)==round(p.bridgeTestCfg.Duration/p.bridgeCfg.Ts)+1);
model='PMSMBridgeBusPlantTest';alreadyLoaded=bdIsLoaded(model);
if ~alreadyLoaded,load_system(fullfile(module,'src',[model,'.slx']));end
cleanup=onCleanup(@()finish(model,alreadyLoaded));
input=Simulink.SimulationInput(model);
input=input.setVariable('bridgeCfg',p.bridgeCfg,'Workspace',model);
input=input.setVariable('bridgeTestCfg',p.bridgeTestCfg,'Workspace',model);
input=input.setVariable('bridgeBusStim',stimulus,'Workspace',model);
clock=tic;output=sim(input);elapsed=toc(clock);raw=output.get('bridge_trace');
definitions=bridge_bus_trace_channels();last=cumsum(cell2mat(definitions(:,3)));first=[1;last(1:end-1)+1];
assert(prod(raw.signals.dimensions)==last(end));
if ismatrix(raw.signals.values) && size(raw.signals.values,1)==numel(raw.time)
    trace=raw.signals.values;
else
    trace=reshape(raw.signals.values,last(end),[])';
end
assert(size(trace,2)==last(end) && all(isfinite(trace),'all'));
columns=struct();
for k=1:size(definitions,1),columns.(definitions{k,1})=first(k):last(k);end
assert(isequal(trace(:,columns.stimulus),stimulus.signals.values));
record=struct('release',version('-release'),'parameters',p,'stimulus',stimulus,'time',raw.time, ...
    'trace',trace,'columns',columns,'definitions',{definitions},'host_seconds',elapsed);
end
function finish(model,alreadyLoaded)
if ~alreadyLoaded && bdIsLoaded(model),close_system(model,0);end
end
