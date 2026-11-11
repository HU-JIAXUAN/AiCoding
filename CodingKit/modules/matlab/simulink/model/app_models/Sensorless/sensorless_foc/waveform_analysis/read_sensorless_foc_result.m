function record=read_sensorless_foc_result(output,parameters)
%READ_SENSORLESS_FOC_RESULT Normalize four logs and preserve their named columns.
if nargin<2,parameters=struct();end
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'parameter'));
record=struct('parameters',parameters,'release',version('-release'));
for scope={'plant','observer','controller','actuation'}
    name=scope{1};raw=output.get([name,'_trace']);definitions=sensorless_foc_channels(name);
    widths=cell2mat(definitions(:,3));last=cumsum(widths);first=[1;last(1:end-1)+1];
    assert(prod(raw.signals.dimensions)==last(end),'Trace layout differs from channel definitions.');
    value=raw.signals.values;
    if ismatrix(value) && size(value,1)==numel(raw.time) && size(value,2)==last(end)
        trace=value;
    else
        trace=reshape(value,last(end),[])';
    end
    assert(all(isfinite(trace),'all'));
    columns=struct();
    for index=1:size(definitions,1),columns.(definitions{index,1})=first(index):last(index);end
    record.(name)=struct('time',raw.time,'trace',trace,'columns',columns,'definitions',{definitions});
    if strcmp(name,'plant'),record.time=raw.time;
    else,assert(isequal(raw.time,record.time),'Stage logs have different sample times.');end
end
end
