function report=inspect_extension_foc(module,kind)
%INSPECT_EXTENSION_FOC Native structure, Scope and actual-source inventory.
spec=extension_foc_spec(kind);model=spec.model;
assert(~bdIsLoaded(model),'Close this App before running its read-only inventory.');
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'),fullfile(module,'waveform_analysis'));
load_system(fullfile(module,'src',[model '.slx']));
cleanup=onCleanup(@()close_system(model,0));
initialize_extension_foc(model,spec.kind);
report=struct('model',model,'release',version('-release'),'editor_open',strcmp(get_param(model,'Open'),'on'));
report.root_read=model_read(model,'root','0');
report.root_check=model_check(model,'root','["all"]');
assert(startsWith(strtrim(string(report.root_check)),'status: healthy'));
root=find_system(model,'SearchDepth',1,'Type','Block');
report.root_blocks=cell(0,1);report.connections=struct('source',{},'source_port',{},'destination',{},'destination_port',{});
for k=1:numel(root)
    path=root{k};if strcmp(path,model),continue;end
    report.root_blocks{end+1}=get_param(path,'Name');
    ports=get_param(path,'PortHandles');
    for n=1:numel(ports.Inport)
        line=get_param(ports.Inport(n),'Line');assert(line~=-1);
        src=get_param(line,'SrcPortHandle');assert(src~=-1);
        report.connections(end+1)=struct('source',get_param(get_param(src,'Parent'),'Name'), ...
            'source_port',get_param(src,'PortNumber'),'destination',get_param(path,'Name'),'destination_port',n);
    end
end
links=find_system(model,'LookUnderMasks','all','FollowLinks','off','Type','Block','LinkStatus','resolved');
report.links=struct('block',{},'reference',{});
for k=1:numel(links)
    report.links(end+1)=struct('block',erase(links{k},[model '/']),'reference',get_param(links{k},'ReferenceBlock'));
end
bad=find_system(model,'LookUnderMasks','all','FollowLinks','off','Type','Block','LinkStatus','unresolved');
assert(isempty(bad));report.unresolved_links=numel(bad);
feval(model,[],[],[],'compile');compiled=onCleanup(@()feval(model,[],[],[],'term'));
scopes=find_system(model,'LookUnderMasks','all','FollowLinks','off','BlockType','Scope');
report.scopes=struct('path',{},'channels',{},'width',{});
for k=1:numel(scopes)
    ports=get_param(scopes{k},'PortHandles');channels=struct('first',{},'last',{},'source',{},'source_port',{},'width',{});
    next=1;
    for n=1:numel(ports.Inport)
        line=get_param(ports.Inport(n),'Line');assert(line~=-1);
        signals=expand(get_param(line,'SrcPortHandle'));
        for j=1:numel(signals)
            src=signals{j};parent=get_param(src,'Parent');widths=get_param(parent,'CompiledPortWidths');number=get_param(src,'PortNumber');width=widths.Outport(number);
            channels(end+1)=struct('first',next,'last',next+width-1,'source',erase(parent,[model '/']),'source_port',number,'width',width);next=next+width;
        end
    end
    report.scopes(end+1)=struct('path',erase(scopes{k},[model '/']),'channels',channels,'width',next-1);
end
clear compiled
assert(~report.editor_open&&report.unresolved_links==0);
theta=report.connections(strcmp({report.connections.source},'Plant')&[report.connections.source_port]==2);
assert(numel(theta)==1&&strcmp(theta.destination,'UnneededTruthAngle'));
report.truth_angle_to_controller=false;
report.parameter_fields=struct();p=extension_foc_parameters(spec.kind);names=fieldnames(p);
for k=1:numel(names),report.parameter_fields.(names{k})=fieldnames(p.(names{k}));end
report.status='passed';
fid=fopen(fullfile(module,'waveform_analysis',[spec.kind '_native_inventory.json']),'w','n','UTF-8');
fwrite(fid,jsonencode(report,PrettyPrint=true),'char');fclose(fid);
fprintf('EXTENSION_NATIVE scopes=%d links=%d no_truth_feedback=1\n',numel(report.scopes),numel(report.links));
end
function signals=expand(port)
parent=get_param(port,'Parent');
if strcmp(get_param(parent,'BlockType'),'Mux')
    inputs=get_param(parent,'PortHandles');signals={};
    for k=1:numel(inputs.Inport)
        line=get_param(inputs.Inport(k),'Line');assert(line~=-1);
        signals=[signals,expand(get_param(line,'SrcPortHandle'))]; %#ok<AGROW>
    end
else,signals={port};end
end
