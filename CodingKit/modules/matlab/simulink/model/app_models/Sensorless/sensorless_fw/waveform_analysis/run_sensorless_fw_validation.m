function summary=run_sensorless_fw_validation(outputFolder)
%RUN_SENSORLESS_FW_VALIDATION Keep independent cases, including failed traces.
if nargin<1,outputFolder=fileparts(mfilename('fullpath'));end
assert(isfolder(outputFolder));cases=sensorless_fw_case_definitions();
limits=sensorless_fw_validation_parameters();results=cell(numel(cases),1);
for k=1:numel(cases)
    specification=cases(k);p=specification.parameters;
    try
        record=run_sensorless_fw_case(p);
        analysis=analyze_sensorless_fw_case(record,specification,limits);
        save(fullfile(outputFolder,[specification.name '.mat']),'record','analysis','limits');
        results{k}=analysis;
    catch exception
        results{k}=struct('name',specification.name,'passed',false,'classification','runtime-error', ...
            'identifier',exception.identifier,'message',getReport(exception,'extended','hyperlinks','off'));
    end
    fprintf('FW_CASE %s: passed=%d\n',specification.name,results{k}.passed);
    fid=fopen(fullfile(outputFolder,'fw_core_progress.json'),'w','n','UTF-8');assert(fid>=0);
    fwrite(fid,jsonencode(results(1:k),PrettyPrint=true),'char');fclose(fid);
end
passed=all(cellfun(@(x)x.passed,results));if passed,status='passed';else,status='failed';end
summary=struct('status',status,'release',version('-release'),'model_cases',numel(cases), ...
    'normal_cases',sum(~[cases.expected_counterexample]),'counterexamples',sum([cases.expected_counterexample]), ...
    'limits',limits,'results',{results}, ...
    'scope','High-speed four-quadrant/bus/limit core only. Startup/reset/direction checks have a separate edge suite. Rebuild and formal replay are recorded separately.');
fid=fopen(fullfile(outputFolder,'fw_core_results.json'),'w','n','UTF-8');assert(fid>=0);
fwrite(fid,jsonencode(summary,PrettyPrint=true),'char');fclose(fid);
assert(passed,'Inspect preserved failing cases; no thresholds were changed.');
end
