function initialize_mtpa_fw_model(model)
%INITIALIZE_MTPA_FW_MODEL Resolve local dependencies and set model workspace.
initialize_motor_paths();
initialize_motor_model(model);
mw=get_param(model,'ModelWorkspace');
p=reference_case_parameters(model);
names=fieldnames(p);
for k=1:numel(names),assignin(mw,names{k},p.(names{k}));end
refTestCfg=p.refTestCfg;
sample=(0:round(refTestCfg.Duration/p.currentCfg.Ts))';
% Torque, signed electrical speed, bus, previous-cycle pre-limit voltage,
% enable, reset. Component bench intentionally separates these inputs.
stim.time=[];
stim.signals.values=[refTestCfg.TorqueReference*ones(size(sample)), ...
    refTestCfg.ElectricalSpeed*ones(size(sample)),refTestCfg.Vdc*ones(size(sample)), ...
    refTestCfg.VoltageDemand*double(sample>=round(refTestCfg.VoltageDemandTime/p.currentCfg.Ts)), ...
    refTestCfg.Enable*ones(size(sample)),refTestCfg.Reset*ones(size(sample))];
stim.signals.dimensions=6;
assignin(mw,'testStim',stim);
end
