function report=run_hf_plant_validation()
%RUN_HF_PLANT_VALIDATION Physical model tests before HFI observer integration.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
model='PMSMHighFrequencyPlantTest';open_system(fullfile(module,'src',[model,'.slx']));
names={'d_axis_rl','q_axis_rl','rotated_rl','cross_coupled_rl','positive_saturation', ...
    'reversed_axis','no_saturation_symmetry','locked_rotor','free_rotor','positive_load', ...
    'no_saliency_zero','no_saliency_rotated','hf_square_salient','hf_square_round'};
records=struct();metrics=cell(1,numel(names));
for test=1:numel(names)
    name=names{test};plant=pmsm_hf_parameters();fixture=hf_plant_test_parameters();
    plant.MechanicalEnabled=0;
    switch name
        case {'d_axis_rl','no_saturation_symmetry'},plant.SaturationDepth=0;
        case 'q_axis_rl',plant.SaturationDepth=0;fixture.VoltageAxis=pi/2;
        case 'rotated_rl',plant.SaturationDepth=0;plant.Position0=0.7/plant.PolePairs;fixture.VoltageAxis=-0.2;
        case 'cross_coupled_rl'
            plant.SaturationDepth=0;plant.CrossInductance=0.2e-3;
            plant.Position0=-1.1/plant.PolePairs;fixture.VoltageAxis=0.4;
        case 'reversed_axis',fixture.VoltageAxis=pi;
        case {'locked_rotor','free_rotor'}
            fixture.VoltageAxis=pi/4;plant.MechanicalEnabled=double(strcmp(name,'free_rotor'));
        case 'positive_load',plant.MechanicalEnabled=1;fixture.PulseVoltage=0;fixture.LoadTorque=0.05;
        case {'no_saliency_zero','no_saliency_rotated','hf_square_round'}
            plant.SaturationDepth=0;plant.Lq=plant.Ld;
            if ~strcmp(name,'no_saliency_zero'),plant.Position0=0.7/plant.PolePairs;end
        case 'hf_square_salient',plant.SaturationDepth=0;plant.Position0=0.7/plant.PolePairs;
    end
    plant=refresh_pmsm_hf_parameters(plant);stimulus=hf_plant_stimulus(fixture);
    if startsWith(name,'hf_square')
        sample=(0:size(stimulus.signals.values,1)-1)';
        stimulus.signals.values(:,1)=5*(-1).^sample;stimulus.signals.values(:,2)=0;
    end
    input=Simulink.SimulationInput(model);
    input=input.setVariable('hfPlantCfg',plant,'Workspace',model);
    input=input.setVariable('hfPlantTestCfg',fixture,'Workspace',model);
    input=input.setVariable('testStim',stimulus,'Workspace',model);
    input=input.setModelParameter('StopTime',num2str(fixture.Duration,16),'FixedStep',num2str(fixture.PlantStep,16));
    record=struct('name',name,'plant',plant,'fixture',fixture,'input',stimulus);
    try
        fprintf('HF_PLANT running %s\n',name);output=sim(input);t=output.trace.time;y=output.trace.signals.values;
        assert(size(y,2)==13 && all(isfinite(y),'all'));
        assert(size(y,1)==size(stimulus.signals.values,1) && max(abs(t-stimulus.time))<1e-12);
        assert(isequal(y(:,1:3),stimulus.signals.values));
        assert(all(y(:,11)>=plant.Ld*(1-plant.SaturationDepth)-1e-12));
        assert(all(y(:,11)<=plant.Ld*(1+plant.SaturationDepth)+1e-12));
        assert(all(y(:,11)*plant.Lq-plant.CrossInductance^2>0));
        currentError=NaN;
        if plant.SaturationDepth==0 && plant.MechanicalEnabled==0
            inductance=[plant.Ld,plant.CrossInductance;plant.CrossInductance,plant.Lq];
            transition=expm(-plant.Rs*(inductance\eye(2))*fixture.Ts);
            forcing=(eye(2)-transition)/plant.Rs;
            theta=plant.PolePairs*plant.Position0;rotation=[cos(theta),sin(theta);-sin(theta),cos(theta)];
            voltage=rotation*stimulus.signals.values(:,1:2)';reference=zeros(size(voltage));
            reference(:,1)=[plant.Id0;plant.Iq0];
            for sample=1:size(voltage,2)-1
                reference(:,sample+1)=transition*reference(:,sample)+forcing*voltage(:,sample);
            end
            currentError=max(abs(y(:,9:10)-reference'),[],'all');
            assert(currentError<1e-5,'Exact linear ZOH reference mismatch: %.9g A',currentError);
            record.reference_dq=reference';
        end
        positive=t>=fixture.PositiveStart & t<fixture.PositiveStart+0.005;
        negative=t>=fixture.NegativeStart & t<fixture.NegativeStart+0.005;
        % Peaks in the FIXED voltage-injection axis, not the true rotor axis.
        injectionCurrent=cos(fixture.VoltageAxis)*y(:,4)+sin(fixture.VoltageAxis)*y(:,5);
        positivePeak=max(injectionCurrent(positive));negativePeak=max(-injectionCurrent(negative));
        difference=positivePeak-negativePeak;
        switch name
            case 'positive_saturation',assert(difference>0.1);
            case 'reversed_axis',assert(difference< -0.1);
            case 'no_saturation_symmetry',assert(abs(difference)<1e-5);
            case 'locked_rotor',assert(all(y(:,7)==0) && all(abs(y(:,6))<1e-12));assert(max(abs(y(:,8)))>0.05);
            case 'free_rotor',assert(max(abs(y(:,7)))>0.2 && max(abs(y(:,6)))>1e-4);
            case 'positive_load',assert(min(y(:,7))< -0.2 && min(y(:,6))< -1e-4);
            case 'no_saliency_rotated'
                assert(max(abs(y(:,4:5)-records.no_saliency_zero.trace(:,4:5)),[],'all')<1e-10);
            case 'hf_square_salient',assert(sqrt(mean(y(t>0.02,5).^2))>0.01);
            case 'hf_square_round',assert(max(abs(y(:,5)))<1e-10);
        end
        metric=struct('name',name,'linear_reference_checked',~isnan(currentError), ...
            'exact_linear_current_max_error_A',currentError, ...
            'positive_peak_A',positivePeak,'negative_peak_A',negativePeak,'peak_difference_A',difference, ...
            'max_electrical_speed_rad_s',max(abs(y(:,7))), ...
            'max_electrical_displacement_rad',max(abs(unwrap(y(:,6))-plant.PolePairs*plant.Position0)), ...
            'min_incremental_inductance_H',min(y(:,11)),'passed',true);
        record.time=t;record.trace=y;record.metric=metric;records.(name)=record;metrics{test}=metric;
        fprintf('HF_PLANT %s PASS reference=%.8g A peak_difference=%.6g A\n',name,currentError,difference);
    catch exception
        record.error=getReport(exception,'extended','hyperlinks','off');
        save(fullfile(module,'waveform_analysis','hf_failure.mat'),'record','-v7.3');rethrow(exception);
    end
end
% A numerical derivative verifies that the electrical matrix is the flux Jacobian.
plant=pmsm_hf_parameters();plant.CrossInductance=0.15e-3;plant=refresh_pmsm_hf_parameters(plant);
jacobianError=0;voltageBalanceError=0;
for current=linspace(-5,5,51)
    x=[current;-0.8;12;0.4];u=[4;-3];[dx,signals]=pmsm_hf_dynamics(x,u,0.2,plant.Settings);
    numerical=zeros(2);step=1e-5;
    for axis=1:2
        plus=x;minus=x;plus(axis)=plus(axis)+step;minus(axis)=minus(axis)-step;
        [~,a]=pmsm_hf_dynamics(plus,u,0.2,plant.Settings);[~,b]=pmsm_hf_dynamics(minus,u,0.2,plant.Settings);
        numerical(:,axis)=(a(9:10)-b(9:10))/(2*step);
    end
    expected=[signals(8),plant.CrossInductance;plant.CrossInductance,plant.Lq];
    jacobianError=max(jacobianError,max(abs(numerical-expected),[],'all'));
    theta=plant.PolePairs*x(4);dq=[cos(theta),sin(theta);-sin(theta),cos(theta)]*u;
    residual=dq-plant.Rs*x(1:2)-expected*dx(1:2)-plant.PolePairs*x(3)*[-signals(10);signals(9)];
    voltageBalanceError=max(voltageBalanceError,norm(residual));
end
assert(jacobianError<1e-9 && voltageBalanceError<1e-10);
report=struct('release',version('-release'),'status','passed','tests',numel(names), ...
    'cases',[metrics{:}],'flux_jacobian_max_error_H',jacobianError, ...
    'voltage_balance_max_error_V',voltageBalanceError,'observer_tested',false,'hardware_tested',false);
save(fullfile(module,'waveform_analysis','hf_results.mat'),'records','report','-v7.3');
file=fopen(fullfile(module,'waveform_analysis','hf_metrics.json'),'w');cleanup=onCleanup(@()fclose(file));
fwrite(file,jsonencode(report,PrettyPrint=true));clear cleanup
for name={'positive_saturation','reversed_axis','free_rotor','hf_square_salient'}
    exportCase(records.(name{1}),name{1},module);
end
disp(rmfield(report,'cases'));
end
function exportCase(record,name,module)
figureHandle=figure('Visible','off','Position',[100,100,1100,900]);cleanup=onCleanup(@()close(figureHandle));
t=record.time;y=record.trace;tiledlayout(4,1);
nexttile;plot(t,y(:,1:2));ylabel('voltage V');legend('alpha','beta');grid on
nexttile;plot(t,y(:,[4,5,9,10]));ylabel('current A');legend('alpha','beta','d','q');grid on
nexttile;plot(t,1e3*y(:,11));ylabel('incremental Ld mH');grid on
nexttile;yyaxis left;plot(t,y(:,6));ylabel('electrical angle rad');yyaxis right;plot(t,y(:,7));ylabel('electrical speed rad/s');xlabel('time s');grid on
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',['hf_',name,'.png']));
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',['hf_',name,'.svg']),ContentType='vector');
end
