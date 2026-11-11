function p=observer_foc_parameters(kind)
%OBSERVER_FOC_PARAMETERS Use the existing physical FOC fixture with EMF/flux.
%   P=OBSERVER_FOC_PARAMETERS('eemf'|'flux') returns local model-workspace
%   settings. Motor, startup, transfer and external acceptance limits retain
%   the SMO baseline. This selects a model before simulation, not at runtime.
kind=char(validatestring(kind,{'eemf','flux'}));
p=sensorless_foc_parameters();p=rmfield(p,'smoCfg');
motor=p.pmsmCfg;
switch kind
    case 'eemf'
        p.emfCfg=emf_parameters('ipmsm');
        p.emfCfg.Ts=p.currentCfg.Ts;p.emfCfg.Rs=motor.Rs;
        p.emfCfg.Ld=motor.Ld;p.emfCfg.Lq=motor.Lq;
        p.emfCfg.Flux=motor.Flux;p.emfCfg.PolePairs=motor.PolePairs;
        p.pllCfg.MinMagnitude=p.emfCfg.MinEmf;
    case 'flux'
        assert(motor.Ld==motor.Lq,'This voltage-model flux library is for SPMSM.');
        p.fluxCfg=flux_parameters();
        p.fluxCfg.Ts=p.currentCfg.Ts;p.fluxCfg.Rs=motor.Rs;
        p.fluxCfg.L=motor.Ld;p.fluxCfg.Flux=motor.Flux;
        p.fluxCfg.PolePairs=motor.PolePairs;
        p.fluxCfg=refresh_flux_parameters(p.fluxCfg);
        p.pllCfg.MinMagnitude=p.fluxCfg.MinFlux;
        % Flux quality is |norm(psi_r)-Flux|/L, not a current-state error.
        % Match the handover threshold to this observer's own valid gate:
        % 5 A-equivalent corresponds to 5 mWb with the default 1 mH motor.
        p.handoverCfg.MaxResidual=p.fluxCfg.MaxResidual;
        p.handoverCfg=refresh_handover_parameters(p.handoverCfg);
end
p.pllCfg.Ts=p.currentCfg.Ts;
end
