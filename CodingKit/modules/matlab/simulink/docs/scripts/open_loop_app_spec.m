function spec=open_loop_app_spec(kind)
assert(ismember(kind,{'if','vf'}));
if strcmp(kind,'if'),model='SensorlessIF';else,model='SensorlessVF';end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
spec=struct('kind',kind,'model',model,'module',fullfile(root,'model','app_models','Sensorless',['sensorless_' kind]));
end
