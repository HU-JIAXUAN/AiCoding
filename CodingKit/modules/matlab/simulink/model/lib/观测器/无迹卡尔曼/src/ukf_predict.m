function next=ukf_predict(posterior,voltage,enable,reset,settings)
%UKF_PREDICT Nine sigma points advance the shared four-state SPMSM process.
% Settings 1:27 are the shared correction contract. Additional settings:
% alpha,beta,kappa,scales(4),initial/max normalized jitter,max retries,
% minimum circular resultant,maximum sigma angular deviation.
%#codegen
next=posterior;s=cast(settings,'like',posterior);
if enable<.5 || reset>.5 || posterior(26)>0 || posterior(27)<.5,return;end
valid=all(isfinite(s)) && s(28)>=.05 && s(28)<=1 && s(29)>=0 && s(29)<=4 && ...
    s(30)>=0 && s(30)<=3 && all(s(31:34)>0) && s(35)>0 && s(36)>=s(35) && ...
    s(37)>=1 && s(37)<=5 && s(37)==floor(s(37)) && s(38)>0 && s(38)<1 && s(39)>0 && s(39)<pi;
if ~valid || ~isfinite(enable) || ~isfinite(reset)
    next=fault_pack(posterior,s,2);return;
end
applied=cast(voltage,'like',posterior);
if ~all(isfinite(applied)) || any(abs(applied)>s(27))
    next=fault_pack(posterior,s,1);return;
end
if ~all(isfinite(posterior)) || abs(posterior(3))>s(25)
    next=fault_pack(posterior,s,3);return;
end
p=reshape(posterior(5:20),4,4);scales=s(31:34);
[root,~,repairs,ok]=bounded_root(p,scales,s(35:37));
if ~ok,next=fault_pack(posterior,s,3);return;end
c=s(28)^2*(4+s(30));wm0=1-4/c;wc0=wm0+1-s(28)^2+s(29);wi=1/(2*c);
spread=sqrt(c)*root;
if max(abs(spread(4,:)))>s(39),next=fault_pack(posterior,s,3);return;end
points=zeros(4,9,'like',posterior);center=posterior(1:4);points(:,1)=center;
for j=1:4
    points(:,j+1)=center+spread(:,j);points(:,j+5)=center-spread(:,j);
end
propagated=zeros(4,9,'like',posterior);
for j=1:9,propagated(:,j)=pmsm_sensorless_step(points(:,j),applied,s(1:4));end
meanState=wm0*propagated(:,1)+wi*sum(propagated(:,2:9),2);
sine=wm0*sin(propagated(4,1))+wi*sum(sin(propagated(4,2:9)));
cosine=wm0*cos(propagated(4,1))+wi*sum(cos(propagated(4,2:9)));
if hypot(sine,cosine)<s(38)
    next=fault_pack(posterior,s,3);return;
end
meanState(4)=atan2(sine,cosine);p=zeros(4,4,'like',posterior);
for j=1:9
    error=propagated(:,j)-meanState;error(4)=atan2(sin(error(4)),cos(error(4)));
    weight=wi;if j==1,weight=wc0;end
    p=p+weight*(error*error');
end
p=p+diag(s(11:14));p=.5*(p+p');
if ~all(isfinite(meanState)) || ~all(isfinite(p),'all')
    next=fault_pack(posterior,s,3);return;
end
[~,p,extraRepairs,ok]=bounded_root(p,scales,s(35:37));
if ~ok,next=fault_pack(posterior,s,3);return;end
next(1:4)=meanState;next(5:20)=p(:);next(28)=posterior(28)+repairs+extraRepairs;
end
function [root,repaired,events,ok]=bounded_root(p,scales,limits)
% Finite, bounded diagonal jitter in normalized state-variance units.
normalizer=scales*scales';normalized=p./normalizer;normalized=.5*(normalized+normalized');
root=zeros(4,4,'like',p);repaired=p;events=cast(0,'like',p);ok=false;
if ~all(isfinite(normalized),'all'),return;end
[factor,flag]=chol(normalized,'lower');
if flag==0,root=diag(scales)*factor;repaired=normalized.*normalizer;ok=true;return;end
jitter=limits(1);
for attempt=1:5
    if attempt>limits(3) || jitter>limits(2),break;end
    candidate=normalized+jitter*eye(4,'like',p);[factor,flag]=chol(candidate,'lower');
    if flag==0
        root=diag(scales)*factor;repaired=candidate.*normalizer;events=cast(1,'like',p);ok=true;return;
    end
    jitter=10*jitter;
end
end
function next=fault_pack(posterior,s,code)
% Keep the shared correction's fault latch finite even after a bad covariance.
next=posterior;next(21)=0;next(3)=0;next(26)=cast(code,'like',posterior);
if code==3 || ~all(isfinite(next))
    next=zeros(28,1,'like',posterior);p=diag(s(7:10));next(5:20)=p(:);
    next(4)=s(6);next(26)=cast(code,'like',posterior);next(27)=1;
    if isfinite(posterior(28)),next(28)=posterior(28);end
end
end
