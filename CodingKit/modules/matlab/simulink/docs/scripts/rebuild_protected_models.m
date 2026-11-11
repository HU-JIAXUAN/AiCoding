function delivery=rebuild_protected_models(work,blocks)
%REBUILD_PROTECTED_MODELS Generate and replay distribution candidates.
% Call with a new output directory from MATLAB R2026b on Windows x64.
% Candidates stay in WORK/delivery; review reports before replacing src SLXP.
arguments
    work (1,1) string
    blocks string = strings(0,1)
end
assert(~isfolder(work) && ~isfile(work),'Use a new build directory.');
assert(strcmp(computer('arch'),'win64'),'The recorded release profile uses Windows x64.');
assert(license('test','Real-Time_Workshop'),'A Simulink Coder license is required.');
assert(~isempty(mex.getCompilerConfigurations('C','Selected')),'Select the C compiler first.');

scripts=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(scripts));
modelRoot=fullfile(root,'model');
diagrams=[list_motor_library_models(modelRoot);dir(fullfile(modelRoot,'app_models','**','src','*.slx'))];
for item=diagrams'
    [~,model]=fileparts(item.name);
    assert(~bdIsLoaded(model),'Close the project model %s before rebuilding.',model);
end
pathBefore=path;
cwdBefore=pwd;
openBefore=find_system('Type','block_diagram');
cleanup=onCleanup(@()restore(pathBefore,cwdBefore,openBefore));
mkdir(work);
[ok,attributes]=fileattrib(work);
assert(ok,'Cannot resolve the build directory.');
work=string(attributes.Name);
snapshot=fullfile(work,'source');
copyInputs(root,snapshot);
cd(work);
addpath(fullfile(snapshot,'docs','scripts'));
initialize_motor_paths();
entries=index_protected_library_interfaces(snapshot,work);
catalog=fullfile(root,'docs','validation','protected_model_contracts.json');
if isempty(blocks)&&isfile(catalog)
    previous=jsondecode(fileread(catalog));
    blocks=string({previous.models.block});
end
if ~isempty(blocks)
    available=string({entries.block});
    assert(all(ismember(blocks,available)),'An export block in the build selection no longer exists.');
    entries=entries(ismember(available,blocks));
end
index=fullfile(work,'inventory.json');
f=fopen(index,'w','n','UTF-8');assert(f>=0,index);
fprintf(f,'%s\n',jsonencode(struct('exports',entries),PrettyPrint=true));fclose(f);
build_protected_libraries(snapshot,index,work,1,1);
delivery=fullfile(work,'delivery');
fprintf('Review protected packages and reports under %s\n',delivery);
end

function copyInputs(root,target)
files=[dir(fullfile(root,'model','**','*'));dir(fullfile(root,'docs','scripts','*.m'))];
for k=1:numel(files)
    file=files(k);
    relative=string(extractAfter(file.folder,strlength(root)+1));
    if any(strcmpi(split(string(strrep(relative,char(92),'/')),'/'),'ref')),continue,end
    if file.isdir
        if any(strcmp(file.name,{'src','parameter','build_process'}))
            mkdir(fullfile(target,relative,file.name));
        end
        continue
    end
    [~,~,extension]=fileparts(file.name);
    if ~any(strcmpi(extension,{'.slx','.m','.json'})),continue,end
    to=fullfile(target,relative);
    if ~isfolder(to),mkdir(to);end
    copyfile(fullfile(file.folder,file.name),fullfile(to,file.name));
end
end

function restore(oldPath,oldFolder,openBefore)
diagrams=setdiff(find_system('Type','block_diagram'),openBefore,'stable');
for k=1:numel(diagrams)
    if bdIsLoaded(diagrams{k}),close_system(diagrams{k},0);end
end
path(oldPath);
cd(oldFolder);
end
