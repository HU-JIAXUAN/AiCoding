function modelRoot = initialize_motor_paths()
%INITIALIZE_MOTOR_PATHS Add reusable modules and assembly test entry paths.
projectRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
modelRoot=fullfile(projectRoot,'model');
libraryModels=dir(fullfile(modelRoot,'lib','**','*.slx'));
sourceFolders=unique({libraryModels.folder});
for k=1:numel(sourceFolders)
    [module,folderName]=fileparts(sourceFolders{k});
    if ~strcmp(folderName,'src'),continue,end
    addpath(sourceFolders{k},fullfile(module,'parameter'), ...
        fullfile(module,'build_process'));
end
assemblies={'experiment','mtpa_fw','observer_compare'};
for k=1:numel(assemblies)
    module=fullfile(modelRoot,'app_models','Sensor',assemblies{k});
    addpath(fullfile(module,'src'),fullfile(module,'parameter'), ...
        fullfile(module,'build_process'));
end
assemblies={'sensorless_foc','sensorless_hfi','sensorless_fw','sensorless_if','sensorless_vf'};
for k=1:numel(assemblies)
    module=fullfile(modelRoot,'app_models','Sensorless',assemblies{k});
    addpath(fullfile(module,'src'),fullfile(module,'parameter'), ...
        fullfile(module,'build_process'));
end
end
