function [out,p]=run_flying_foc_case(p)
%RUN_FLYING_FOC_CASE One physical MIL using nonpersistent workspace overrides.
model='FlyingFluxFOC';
if nargin<1,p=flying_foc_parameters();end
p=refresh_flying_foc_parameters(p);
in=Simulink.SimulationInput(model);names=fieldnames(p);
for k=1:numel(names),in=in.setVariable(names{k},p.(names{k}),'Workspace',model);end
in=in.setVariable('flyingStim',flying_foc_stimulus(p),'Workspace',model);
in=in.setModelParameter('StopTime',num2str(p.experimentCfg.Duration,17));
out=sim(in);
% Column-vector model signals are saved by Simulink as width-by-1-by-time.
% The public runner returns time-by-channel tables for analysis and exports.
for scope={'plant','observer','controller'}
    name=[scope{1},'_trace'];trace=out.(name);
    definitions=flying_foc_channels(scope{1});width=sum(cell2mat(definitions(:,2)));
    assert(numel(trace.signals.values)==width*numel(trace.time));
    trace.signals.values=reshape(trace.signals.values,width,[]).';
    trace.signals.dimensions=width;out.(name)=trace;
end
end
