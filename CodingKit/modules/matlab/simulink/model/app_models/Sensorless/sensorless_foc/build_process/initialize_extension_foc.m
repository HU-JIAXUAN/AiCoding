function initialize_extension_foc(model,kind)
%INITIALIZE_EXTENSION_FOC Load only this App's M configuration into its workspace.
spec=extension_foc_spec(kind);assert(strcmp(model,spec.model));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'build_process'),fullfile(module,'waveform_analysis'));
p=extension_foc_parameters(spec.kind);workspace=get_param(model,'ModelWorkspace');clear(workspace);
names=fieldnames(p);for k=1:numel(names),assignin(workspace,names{k},p.(names{k}));end
assignin(workspace,'testStim',sensorless_fw_stimulus(p));
end
