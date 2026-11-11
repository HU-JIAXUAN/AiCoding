function [posterior,y]=kalman_current_update(memory,current,direction,enable,reset,settings)
%KALMAN_CURRENT_UPDATE Shared four-state current correction and qualification.
% memory=[prior x(4);prior P(:)(16);count;previous theta;angle rate;have theta;
%         previous direction;fault;initialized;numeric repair count].
% The current measurement is used now; current voltage is not an input.
%#codegen
s=cast(settings,'like',memory);posterior=zeros(28,1,'like',memory);y=zeros(24,1,'like',memory);
validSettings=all(isfinite(s)) && s(1)>0 && s(2)>=0 && s(3)>0 && s(4)>0 && ...
    all(s(7:16)>0) && s(17)>=1 && all(s(18:22)>0) && s(23)>0 && s(23)<=1 && all(s(24:27)>0);
if ~validSettings,posterior(26)=2;y(14)=2;return;end
posterior=initial_pack(s,memory);
innovation=zeros(2,1,'like',memory);gain=zeros(4,2,'like',memory);nis=cast(0,'like',memory);
if (isfinite(reset) && reset>.5) || (isfinite(enable) && enable<.5)
    y=outputs(posterior,innovation,nis,gain,s);return;
end
if ~isfinite(enable) || ~isfinite(reset) || ~isfinite(direction) || (direction~=0 && abs(direction)~=1)
    posterior(26)=2;y=outputs(posterior,innovation,nis,gain,s);return;
end
if ~all(isfinite(memory))
    posterior(26)=3;y=outputs(posterior,innovation,nis,gain,s);return;
end
if memory(26)>0
    posterior=memory;posterior(21)=0;posterior(3)=0;
    y=outputs(posterior,innovation,nis,gain,s);return;
end
measured=cast(current,'like',memory);
if ~all(isfinite(measured)) || any(abs(measured)>s(26))
    if memory(27)>.5,posterior=memory;end
    posterior(26)=1;posterior(21)=0;posterior(3)=0;
    y=outputs(posterior,innovation,nis,gain,s);return;
end
if memory(27)>.5
    prior=memory(1:4);covariance=reshape(memory(5:20),4,4);posterior=memory;
else
    prior=posterior(1:4);prior(3)=direction*s(5);
    covariance=reshape(posterior(5:20),4,4);
end
[predictedMeasurement,h]=pmsm_sensorless_measurement(prior);
innovation=measured-predictedMeasurement;r=diag(s(15:16));
innovationCov=h*covariance*h'+r;determinant=innovationCov(1,1)*innovationCov(2,2)-innovationCov(1,2)*innovationCov(2,1);
if ~all(isfinite(innovationCov),'all') || any(diag(innovationCov)<=0) || ~isfinite(determinant) || determinant<=0
    posterior=initial_pack(s,memory);posterior(26)=3;y=outputs(posterior,zeros(2,1,'like',memory),nis,gain,s);return;
end
gain=(covariance*h')/innovationCov;state=prior+gain*innovation;
state(4)=atan2(sin(state(4)),cos(state(4)));
nis=innovation'*(innovationCov\innovation);
identity=eye(4,'like',memory);m=identity-gain*h;
covariance=m*covariance*m'+gain*r*gain';covariance=.5*(covariance+covariance');
if ~all(isfinite(state)) || ~all(isfinite(covariance),'all') || any(diag(covariance)<0) || ~isfinite(nis) || nis<0
    posterior=initial_pack(s,memory);posterior(26)=3;y=outputs(posterior,zeros(2,1,'like',memory),cast(0,'like',memory),zeros(4,2,'like',memory),s);return;
end
if memory(24)>.5
    difference=atan2(sin(state(4)-memory(22)),cos(state(4)-memory(22)));
    rate=memory(23)+s(23)*(difference/s(1)-memory(23));
else
    rate=state(3);
end
count=cast(0,'like',memory);
qualified=direction~=0 && direction*state(3)>=s(18) && abs(state(3))<=s(25) && abs(state(3))*s(4)>=s(19) && ...
    nis<=s(20) && sqrt(covariance(4,4))<=s(21) && sqrt(covariance(3,3))<=s(22) && abs(rate-state(3))<=s(24);
if qualified
    if direction==memory(25),count=min(memory(21)+1,s(17));else,count=cast(1,'like',memory);end
end
posterior(1:4)=state;posterior(5:20)=covariance(:);posterior(21)=count;
posterior(22)=state(4);posterior(23)=rate;posterior(24)=1;
posterior(25)=direction;posterior(26)=0;posterior(27)=1;posterior(28)=memory(28);
y=outputs(posterior,innovation,nis,gain,s);
end
function pack=initial_pack(s,like)
pack=zeros(28,1,'like',like);pack(4)=s(6);p=diag(s(7:10));pack(5:20)=p(:);
end
function y=outputs(pack,innovation,nis,gain,s)
y=zeros(24,1,'like',pack);p=reshape(pack(5:20),4,4);
y(1)=pack(4);y(2)=pack(3);y(3)=cast(pack(21)>=s(17) && pack(26)==0,'like',pack);
y(4:5)=pack(1:2);y(6:7)=innovation;y(8)=nis;
y(9)=sqrt(max(p(4,4),0));y(10)=sqrt(max(p(3,3),0));
y(11)=pack(23);y(12)=pack(23)-pack(3);y(13)=pack(21);y(14)=pack(26);
y(15:18)=diag(p);y(19:20)=gain(4,:)';y(21:22)=gain(3,:)';y(23)=abs(pack(3))*s(4);y(24)=pack(28);
end
