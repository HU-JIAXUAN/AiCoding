function report=run_flying_logic_checks()
%RUN_FLYING_LOGIC_CHECKS Check precharge changes, reset and tracking identity.
p=flying_foc_parameters();settings=p.flyingCfg.Vector;
u=[0;0;320;1;0;11.2;100;1;0];state=zeros(8,1);state(1)=2;
for test=1:3
    changed=u;
    if test==1,changed(7)=-100;expected=2;
    elseif test==2,changed(6)=settings(10)+1;expected=3;
    else,changed(1)=settings(9)+0.1;expected=4;end
    [next,output]=flying_capture_step(state,changed,settings);
    assert(next(1)==5 && next(5)==expected && output(3)==0);
end
changed=u;changed(4)=0;state(4)=settings(7)-1;
[next,output]=flying_capture_step(state,changed,settings);
assert(next(1)==5 && next(5)==5 && output(3)==0);
state(:)=1;changed=u;changed(9)=1;
[next,output]=flying_capture_step(state,changed,settings);
assert(all(next==0) && output(3)==0 && output(5)==1);
changed=u;changed(6)=NaN;
[next,output]=flying_capture_step(zeros(8,1),changed,settings);
assert(next(1)==5 && next(5)==7 && output(3)==0);
% Independent algebra: the actual PI recurrence must end at target-P.
error=[0.8;-0.3];integral=[2;-1];kp=[p.currentCfg.Kpd;p.currentCfg.Kpq];
target=[3;10];request=integral+kp.*error;ki=[p.currentCfg.Kid;p.currentCfg.Kiq];
residual=flying_pi_residual(request,request,target,error,1,[p.currentCfg.Ts;ki]);
actual=integral+p.currentCfg.Ts*(ki.*error+p.currentCfg.Kaw*residual);
assert(max(abs(actual-(target-kp.*error)))<1e-12);
invalid=p;invalid.currentCfg.Kaw=invalid.currentCfg.Kaw/2;rejected=false;
try,refresh_flying_foc_parameters(invalid);catch exception
    rejected=contains(exception.message,'Kaw=1/Ts');
end
assert(rejected);
report=struct('passed',true,'checks',8,'precharge_guards',3, ...
    'tracking_identity_max_error',max(abs(actual-(target-kp.*error))));
destination=fullfile(fileparts(mfilename('fullpath')),'flying_logic_checks.json');
file=fopen(destination,'w','n','UTF-8');assert(file>=0);cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(report,'PrettyPrint',true));disp(report);
end
