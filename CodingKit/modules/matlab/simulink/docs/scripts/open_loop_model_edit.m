function result=open_loop_model_edit(model,scope,operations,complete,layout)
%OPEN_LOOP_MODEL_EDIT Read/edit/read/check one scope using the native toolkit.
before=model_read(model,scope,'0');assert(startsWith(strtrim(string(before)),'status: ok'));
result=model_edit(model,scope,jsonencode(operations),layout);
after=model_read(model,scope,'0');assert(startsWith(strtrim(string(after)),'status: ok'));
if ~startsWith(strtrim(string(result)),'status: ok')
    disp(result);disp(after);disp(model_check(model,scope,'["all"]'));error('Inspect partial model edit before proceeding.');
end
if complete
    health=model_check(model,scope,'["all"]');
    assert(startsWith(strtrim(string(health)),'status: healthy'),'%s',char(health));
end
fprintf('EDITED %s/%s operations=%d complete=%d\n',model,scope,numel(operations),complete);
end
