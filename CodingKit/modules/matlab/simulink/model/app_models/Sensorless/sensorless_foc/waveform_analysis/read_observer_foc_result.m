function record=read_observer_foc_result(output,parameters,kind)
%READ_OBSERVER_FOC_RESULT Decode actual four-stage logs without invented data.
record=struct('parameters',parameters,'release',version('-release'),'observer_kind',kind);
for scope={'plant','observer','controller','actuation'}
    name=scope{1};raw=output.get([name,'_trace']);definitions=observer_foc_channels(name,kind);
    widths=cell2mat(definitions(:,3));last=cumsum(widths);first=[1;last(1:end-1)+1];
    assert(prod(raw.signals.dimensions)==last(end),'Trace differs from channel definitions.');
    value=raw.signals.values;
    if ismatrix(value) && size(value,1)==numel(raw.time) && size(value,2)==last(end)
        trace=value;
    else
        trace=reshape(value,last(end),[])';
    end
    assert(all(isfinite(trace),'all'));
    columns=struct();
    for k=1:size(definitions,1),columns.(definitions{k,1})=first(k):last(k);end
    record.(name)=struct('time',raw.time,'trace',trace,'columns',columns,'definitions',{definitions});
    if strcmp(name,'plant'),record.time=raw.time;
    else,assert(isequal(raw.time,record.time),'Stage logs have different sample times.');end
end
end
