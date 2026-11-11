function modelRoot = initialize_motor_paths()
%INITIALIZE_MOTOR_PATHS Add reusable modules and assembly test entry paths.
projectRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
modelRoot=fullfile(projectRoot,'model');
libraryModels=list_motor_library_models(modelRoot);
sourceFolders=unique({libraryModels.folder});
for k=1:numel(sourceFolders)
    sourceRoot=sourceFolders{k};
    [module,folderName]=fileparts(sourceRoot);
    while ~strcmp(folderName,'src')
        sourceRoot=module;
        [module,folderName]=fileparts(sourceRoot);
    end
    addpath(sourceFolders{k},fullfile(module,'parameter'),fullfile(module,'build_process'));
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
module=fullfile(modelRoot,'app_models','Mit Mode');
addpath(fullfile(module,'src'),fullfile(module,'parameter'), ...
    fullfile(module,'build_process'));
end
