function tidy_sensorless_fw_model(model)
%TIDY_SENSORLESS_FW_MODEL Resize port labels, then let the engine place boxes.
% Only the newly generated App is changed. Reference libraries stay linked.
assert(strcmp(model,'SensorlessFieldWeakeningFOC')&&bdIsLoaded(model));
rootBlocks=find_system(model,'SearchDepth',1,'Type','Block');scopes={model};
for k=1:numel(rootBlocks)
    if strcmp(rootBlocks{k},model),continue;end
    if strcmp(get_param(rootBlocks{k},'BlockType'),'SubSystem'),scopes{end+1}=rootBlocks{k};end
end
% Child diagrams first, so root placement uses the resized component boxes.
order=[2:numel(scopes),1];
for n=order
    scope=scopes{n};if n==1,scopeId='root';else,scopeId=id(scope);end
    disp(model_read(model,scopeId,'0'));
    blocks=find_system(scope,'SearchDepth',1,'Type','Block');operations={};
    for k=1:numel(blocks)
        block=blocks{k};if strcmp(block,scope),continue;end
        if ~strcmp(get_param(block,'BlockType'),'SubSystem'),continue;end
        ports=get_param(block,'PortHandles');count=max(numel(ports.Inport),numel(ports.Outport));
        if n==1,width=400;elseif count>=4,width=380;else,width=220;end
        height=max(110,26*count+40);position=get_param(block,'Position');
        % Preserve the origin here; the full layout below owns all positions.
        position(3:4)=position(1:2)+[max(width,position(3)-position(1)),max(height,position(4)-position(2))];
        operations{end+1}=struct('op','configure','target',id(block),'params',struct('Position',mat2str(position)));
    end
    if ~isempty(operations)
        result=model_edit(model,scopeId,jsonencode(operations),'incremental');disp(result);disp(model_read(model,scopeId,'0'));
        if ~startsWith(strtrim(string(result)),'status: ok')
            disp(model_check(model,scopeId,'["all"]'));error('Resize failed; inspect current scope before continuing.');
        end
    end
    result=model_edit(model,scopeId,'[]','full');disp(result);disp(model_read(model,scopeId,'0'));
    check=model_check(model,scopeId,'["all"]');disp(check);
    assert(startsWith(strtrim(string(result)),'status: ok')&&startsWith(strtrim(string(check)),'status: healthy'));
end
end
function value=id(path)
value=['blk_' extractAfter(Simulink.ID.getSID(path),':')];
end
