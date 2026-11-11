function initialize_hfi_hybrid(model)
%INITIALIZE_HFI_HYBRID Install this App's local configurations without UI changes.
module=fileparts(fileparts(mfilename('fullpath')));lib=fullfile(module,'..','..','..','lib');
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')));
for name={'观测器/高频注入','观测器/反电势','相位跟踪','无感切换','永磁同步电机', ...
        'math','电流环','逆变器','运动环','MTPA弱磁','电压前馈'}
    addpath(fullfile(lib,name{1},'src'),fullfile(lib,name{1},'parameter'));
end
values=hfi_hybrid_workspace(hfi_hybrid_app_parameters());workspace=get_param(model,'ModelWorkspace');
names=fieldnames(values);for k=1:numel(names),assignin(workspace,names{k},values.(names{k}));end
end
