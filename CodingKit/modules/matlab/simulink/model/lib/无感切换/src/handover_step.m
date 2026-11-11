function [nextState,output]=handover_step(state,input,parameter)
%#codegen
%HANDOVER_STEP Unit Delay owns all states; no plant truth is an input.
% input: thetaStart,omegaStart,ready,startMode,startFault,thetaHat,omegaHat,
%        observerValid,currentResidualNorm,enable,reset.
% output: thetaUsed,omegaBase,omegaFrame,beta,mode,fault,acquired,run,
%         qualificationN,lossN,phaseOffset.
p=cast(parameter,'like',state);u=cast(input,'like',state);
nextState=state;output=zeros(11,1,'like',state);
thetaStart=u(1);thetaHat=u(6);omegaHat=u(7);mode=state(1);
if u(10)<0.5 || u(11)>0.5
    nextState(:)=0;nextState(6)=thetaStart;output(1)=thetaStart;
    return
end
fraction=min(state(3)/p(7),1);beta=fraction*fraction*(3-2*fraction);offset=state(5);
if mode==5
    output(1)=state(6);output(4)=beta;output(5)=5;output(6)=state(7);
    output(9)=state(2);output(10)=state(4);output(11)=offset;
    return
end
if mode<=2 && u(5)>0.5
    nextState(1)=5;nextState(7)=1;
    output(1)=state(6);output(5)=5;output(6)=1;
    output(9)=state(2);output(10)=state(4);output(11)=offset;
    return
end
theta=thetaStart;omegaBase=u(2);omegaFrame=omegaBase;
baseHealthy=u(8)>0.5 && abs(omegaHat)>=p(2) && u(9)>=0 && u(9)<=p(5);
if mode==0
    nextState(1)=1;nextState(2)=0;
    nextState(8)=thetaHat;nextState(9)=omegaHat;
elseif mode==1 || mode==2
    phaseGap=atan2(sin(thetaStart-thetaHat),cos(thetaStart-thetaHat));
    ordinary=u(3)>0.5 && abs(u(2)-omegaHat)<=p(3) && abs(phaseGap)<=p(4);
    flying=p(10)>0.5 && u(4)==1;
    if baseHealthy && (ordinary || flying)
        nextState(1)=2;nextState(2)=min(state(2)+1,p(6));
        if nextState(2)>=p(6)
            nextState(1)=3;nextState(3)=0;nextState(4)=0;nextState(5)=phaseGap;
        end
    else
        nextState(1)=1;nextState(2)=0;
    end
    nextState(8)=thetaHat;nextState(9)=omegaHat;
elseif mode==3 || mode==4
    prediction=state(8)+p(1)*state(9);
    prediction=atan2(sin(prediction),cos(prediction));
    innovation=atan2(sin(thetaHat-prediction),cos(thetaHat-prediction));
    healthy=baseHealthy && abs(innovation)<=p(9);
    if healthy
        safeTheta=thetaHat;safeOmega=omegaHat;nextState(4)=0;
    else
        safeTheta=prediction;safeOmega=state(9);nextState(4)=state(4)+1;
    end
    nextState(8)=safeTheta;nextState(9)=safeOmega;
    if mode==3 && state(3)==0
        offset=atan2(sin(thetaStart-safeTheta),cos(thetaStart-safeTheta));
        nextState(5)=offset;
    end
    if mode==4,beta=cast(1,'like',state);end
    theta=safeTheta+(1-beta)*offset;theta=atan2(sin(theta),cos(theta));
    omegaBase=safeOmega;omegaFrame=safeOmega;
    if mode==3 && healthy
        if beta<1
            nextState(3)=min(state(3)+1,p(7));
            nextFraction=nextState(3)/p(7);
            nextBeta=nextFraction*nextFraction*(3-2*nextFraction);
            omegaFrame=safeOmega-offset*(nextBeta-beta)/p(1);
        else
            nextState(1)=4;
        end
    end
    if mode==3 && state(3)==0 && ~healthy,omegaFrame=u(2);end
    if nextState(4)>=p(8),nextState(1)=5;nextState(7)=2;end
else
    nextState(1)=5;nextState(7)=3;
    output(1)=state(6);output(5)=5;output(6)=3;
    return
end
nextState(6)=theta;
output(1)=theta;output(2)=omegaBase;output(3)=omegaFrame;output(4)=beta;
output(5)=mode;output(6)=state(7);output(7)=cast(mode==4,'like',state);
output(8)=cast(mode~=0,'like',state);output(9)=state(2);
output(10)=state(4);output(11)=offset;
end
