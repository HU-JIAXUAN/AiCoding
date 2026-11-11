function summary=run_extension_foc_validation(kind,outputFolder,selectedCases)
%RUN_EXTENSION_FOC_VALIDATION Keep physical traces and diagnostics per scenario.
specification=extension_foc_spec(kind);
if nargin<2,outputFolder=fullfile(fileparts(mfilename('fullpath')),specification.kind);end
if ~isfolder(outputFolder),mkdir(outputFolder);end
cases=extension_foc_cases(kind);
if nargin>2
    selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,{cases.name})));
    cases=cases(ismember({cases.name},selectedCases));assert(~isempty(cases));
end
entry=which('initialize_motor_paths');root=fileparts(fileparts(fileparts(entry)));
addpath(fullfile(root,'model','app_models','Sensorless','sensorless_fw','waveform_analysis'));
limits=extension_foc_validation_parameters();results=cell(numel(cases),1);
for n=1:numel(cases)
    specification=cases(n);p=refresh_extension_foc_parameters(specification.parameters);
    stimulus=sensorless_fw_stimulus(p);time=stimulus.time;
    switch specification.kind
        case 'observer_loss',stimulus.signals.values(time>=specification.event_time,6)=0;
        case 'moving_exit',stimulus.signals.values(time>=specification.event_time&time<specification.event_time+.01,4)=1;
    end
    try
        record=run_extension_foc_case(kind,p,stimulus);
        analysis=analyze_extension_foc(record,specification,limits);
        save(fullfile(outputFolder,[specification.name '.mat']),'record','analysis','limits');
        results{n}=analysis;
    catch exception
        failure=struct('name',specification.name,'algorithm',kind,'kind',specification.kind,'passed',false, ...
            'identifier',exception.identifier,'runtime_error',getReport(exception,'extended','hyperlinks','off'));
        save(fullfile(outputFolder,[specification.name '_runtime_failure.mat']),'p','stimulus','limits','failure');
        results{n}=failure;
    end
    fprintf('EXTENSION_FOC %s/%s passed=%d\n',kind,specification.name,results{n}.passed);
    fid=fopen(fullfile(outputFolder,'progress.json'),'w','n','UTF-8');fwrite(fid,jsonencode(results(1:n),PrettyPrint=true),'char');fclose(fid);
end
passed=all(cellfun(@(x)x.passed,results));if passed,status='passed';else,status='failed';end
summary=struct('status',status,'algorithm',kind,'release',version('-release'),'model_cases',numel(cases), ...
    'limits',limits,'results',{results},'scope','Physical SPMSM App takeovers/refusals/exits only; no new lib, single, SIL or C2000 claim.');
fid=fopen(fullfile(outputFolder,'results.json'),'w','n','UTF-8');fwrite(fid,jsonencode(summary,PrettyPrint=true),'char');fclose(fid);
assert(passed,'Inspect retained App cases and declared criteria before promotion.');
end
