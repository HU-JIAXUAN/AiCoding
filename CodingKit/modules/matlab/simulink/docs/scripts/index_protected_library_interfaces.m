function records=index_protected_library_interfaces(root,work)
% Index library exports and model instances without changing source diagrams.
libs=list_motor_library_models(fullfile(root,'model'));
records=struct('library',{},'source',{},'block',{},'inputs',{},'outputs',{},'candidates',{});
for j=1:numel(libs)
    f=fullfile(libs(j).folder,libs(j).name);
    [~,m]=fileparts(f);
    if endsWith(m,'Test'),continue,end
    load_system(f);
    assert(strcmp(get_param(m,'BlockDiagramType'),'library'),m);
    blocks=find_system(m,'SearchDepth',1,'Type','Block');
    for k=1:numel(blocks)
        b=blocks{k};
        if ~strcmp(get_param(b,'BlockType'),'SubSystem'),continue,end
        ports=get_param(b,'PortHandles');
        rec=struct('library',m,'source',strrep(f,char(92),'/'),'block',b, ...
            'inputs',numel(ports.Inport),'outputs',numel(ports.Outport),'candidates',{{}});
        records(end+1)=rec;
    end
    close_system(m,0);
end
models=[libs(endsWith({libs.name},'Test.slx'));dir(fullfile(root,'model','app_models','**','src','*.slx'))];
issues={};
for j=1:numel(models)
    f=fullfile(models(j).folder,models(j).name);[~,m]=fileparts(f);
    try
        load_system(f);
        blocks=find_system(m,'LookUnderMasks','all','FollowLinks','off','Type','Block');
        for k=1:numel(blocks)
            b=blocks{k};
            ref=get_param(b,'ReferenceBlock');
            pos=find(strcmp({records.block},ref));
            if isempty(pos),continue,end
            records(pos).candidates{end+1}=struct('model',m,'file',strrep(f,char(92),'/'), ...
                'block',b,'sid',Simulink.ID.getSID(b),'depth',count(b,'/'));
        end
    catch ME
        issues{end+1}=struct('model',m,'error',ME.message);
    end
    if bdIsLoaded(m),close_system(m,0);end
end
f=fopen(fullfile(work,'inventory.json'),'w','n','UTF-8');
for k=1:numel(records)
    if nnz(strcmp({records.library},records(k).library))==1
        records(k).protected_name=[records(k).library 'Protected'];
    else
        block=extractAfter(records(k).block,'/');
        records(k).protected_name=[records(k).library '_' regexprep(block,'[^A-Za-z0-9_]','') 'Protected'];
    end
end
fprintf(f,'%s',jsonencode(struct('exports',records,'load_issues',{issues}),PrettyPrint=true));fclose(f);
fprintf('Exports %d, no candidates %d, loaded test/app %d, load issues %d\n',numel(records),sum(cellfun(@isempty,{records.candidates})),numel(models),numel(issues));
end
