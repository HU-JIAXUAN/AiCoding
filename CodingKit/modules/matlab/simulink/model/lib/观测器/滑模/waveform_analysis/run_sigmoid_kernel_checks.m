function report=run_sigmoid_kernel_checks()
%RUN_SIGMOID_KERNEL_CHECKS Closed-form identities, failure memory and single smoke.
module=initialize_sigmoid_smo_paths();cfg=sigmoid_smo_parameters();s=cfg.Settings;names={};
currentError=(-5:.01:5)';logistic=cfg.SlidingGain*(2./(1+exp(-cfg.Slope*currentError))-1);
assert(max(abs(logistic-cfg.SlidingGain*tanh(cfg.Slope*currentError/2)))<1e-12);names{end+1}='published_logistic_identity';
large=cfg.SlidingGain*tanh(cfg.Slope*[-1e6;1e6]/2);assert(isequal(large,[-cfg.SlidingGain;cfg.SlidingGain]));names{end+1}='large_input_finite_bound';
state=[.4;-.7;1;0];voltage=[3;-2];
next=sigmoid_smo_predict(state,voltage,1,1,0,1,[0;0],0,s);
steady=voltage/cfg.Rs;closed=steady+(state(1:2)-steady)*exp(-cfg.Rs*cfg.Ts/cfg.L);
assert(max(abs(next(1:2)-closed))<1e-14);names{end+1}='constant_voltage_RL_closed_form';
tiny=cfg;tiny.Rs=1e-12;tiny=refresh_sigmoid_smo_parameters(tiny);
assert(abs(tiny.B-cfg.Ts/cfg.L)<1e-13);names{end+1}='small_resistance_expm1_limit';
unsafe=cfg;unsafe.SlidingGain=300;rejected=false;
try
    refresh_sigmoid_smo_parameters(unsafe);
catch exception
    rejected=contains(exception.message,'pole');
end
assert(rejected);names{end+1}='unsafe_local_pole_rejected';
[z,~,~,~,~,active,reset,fault]=sigmoid_smo_measure(state,[1;2],-1,1,0,s);
assert(active==0 && reset==1 && fault==0 && all(z==0));
next=sigmoid_smo_predict(state,[3;4],-1,1,0,active,z,fault,s);
assert(isequal(next,[0;0;-1;0]));names{end+1}='direction_change_clears_predictor';
[z,~,~,~,~,active,~,fault]=sigmoid_smo_measure(state,[NaN;2],1,1,0,s);assert(fault==1);
held=sigmoid_smo_predict(state,voltage,1,1,0,active,z,fault,s);assert(held(4)==1);
[~,~,~,~,~,active,~,fault]=sigmoid_smo_measure(held,[1;2],1,1,0,s);assert(fault==1 && active==0);
cleared=sigmoid_smo_predict(held,voltage,1,0,0,0,[0;0],fault,s);assert(all(cleared==0));names{end+1}='fault_latched_until_disable';
bad=s;bad(2)=0;[~,~,~,~,~,active,~,fault]=sigmoid_smo_measure(state,[1;2],1,1,0,bad);
assert(fault==2 && active==0);names{end+1}='invalid_packed_settings';
[~,~,~,~,~,active,~,fault]=sigmoid_smo_measure([NaN;0;1;0],[1;2],1,1,0,s);
assert(fault==3 && active==0);names{end+1}='nonfinite_prior_state';
[zd,hd,rd,pd,md,ad,td,fd,nd]=sigmoid_smo_measure(state,[1;2],1,1,0,s);
[zs,hs,rs,ps,ms,as,ts,fs,ns]=sigmoid_smo_measure(single(state),single([1;2]),single(1),single(1),single(0),single(s));
delta=max(abs([zd;hd;rd;pd;md;ad;td;fd;nd]-double([zs;hs;rs;ps;ms;as;ts;fs;ns])));
assert(isa(zs,'single') && delta<5e-5);names{end+1}='single_measure_kernel_smoke';
report=struct('status','passed','checks',numel(names),'names',{names},'single_kernel_maximum_absolute_difference',delta, ...
    'full_single_model_validated',false,'target_timing_measured',false);
file=fopen(fullfile(module,'waveform_analysis','sigmoid_kernel_metrics.json'),'w');
fprintf(file,'%s',jsonencode(report,'PrettyPrint',true));fclose(file);disp(report);
end
