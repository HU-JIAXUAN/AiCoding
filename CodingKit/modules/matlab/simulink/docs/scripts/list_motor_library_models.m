function models = list_motor_library_models(modelRoot)
%LIST_MOTOR_LIBRARY_MODELS Find delivered SLX files under library src folders.
models = dir(fullfile(modelRoot,'lib','**','*.slx'));
folders = replace(string({models.folder}),string(filesep),"/");
models = models(contains(folders+"/","/src/"));
end
