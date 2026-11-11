function next=emf_predict(state,voltage,current,omega,active,settings)
%EMF_PREDICT Full-order current/extended-EMF observer, forward Euler.
% state=[i_hat_alpha;i_hat_beta;e_hat_alpha;e_hat_beta].
% current[k] and interval-start voltage[k] update state[k+1].
% settings=[Ts;Rs;Ld;Lq;observer_pole_rad_s]. No true angle/speed input.
%#codegen
next=zeros(4,1,'like',state);
if ~active,return;end
step=settings(1);resistance=settings(2);ld=settings(3);lq=settings(4);pole=settings(5);
ihat=state(1:2);emf=state(3:4);innovation=current-ihat;
jcurrent=[-ihat(2);ihat(1)];jemf=[-emf(2);emf(1)];
l1=2*pole-resistance/ld;l2=-ld*pole*pole;
di=(-resistance*ihat+omega*(ld-lq)*jcurrent-emf+voltage)/ld+l1*innovation;
de=omega*jemf+l2*innovation;
next(1:2)=ihat+step*di;next(3:4)=emf+step*de;
end
