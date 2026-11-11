function [next,voltageAB,phaseVoltage,dcCurrent,diodeStates,bridgeLoss,residual,nextPhaseCurrent,neutralVoltage,poleVoltage]=pmsm_bridge_step(state,duty,mode,loadTorque,settings)
%PMSM_BRIDGE_STEP Coupled linear PMSM + ideal PWM/PWL freewheel diode bridge.
% Mode: 0 all gates OFF (diode rectifier), 1 averaged PWM, 2 active short.
% Electrical flux balance uses backward Euler; mechanics uses forward Euler.
% Current outputs belong to state[k]. Solver voltages/current diagnostics
% describe the k -> k+1 interval; no current reset is used when gates turn off.
% settings=[Ts;Rs;Ld;Lq;Flux;p;J;B;Vdc;Vf;Ron;MechanicalEnabled; ...
%           CurrentTolerance;VoltageTolerance;MaxCurrent;MaxSpeed;MaxAngleStep].
%#codegen
assert(all(isfinite(state)) && all(isfinite(settings)) && isfinite(loadTorque));
assert(mode==0 || mode==1 || mode==2,'Bridge mode must be 0, 1 or 2.');
step=settings(1);rs=settings(2);ld=settings(3);lq=settings(4);
flux=settings(5);pairs=settings(6);inertia=settings(7);friction=settings(8);
bus=settings(9);vf=settings(10);ron=settings(11);
assert(step>0 && ld>0 && lq>0 && inertia>0 && bus>0 && rs>=0 && vf>=0 && ron>=0);
assert(max(abs(state(1:2)))<=settings(15) && abs(state(3))<=settings(16));
assert(abs(pairs*state(3)*step)<=settings(17),'Electrical angle increment exceeds configured model limit.');
angle=pairs*state(4);cosine=cos(angle);sine=sin(angle);
rotation=[cosine,-sine;sine,cosine];inductance=rotation*diag([ld,lq])*rotation';
magnet=flux*[cosine;sine];oldFlux=inductance*state(1:2)+magnet;
id=cosine*state(1)+sine*state(2);iq=-sine*state(1)+cosine*state(2);
torque=1.5*pairs*(flux*iq+(ld-lq)*id*iq);
next=zeros(4,1,'like',state);next(3)=state(3);
if settings(12)>0.5
    next(3)=state(3)+step*(torque-loadTorque-friction*state(3))/inertia;
end
next(4)=state(4)+step*state(3); % prescribed-speed mode also advances angle
futureAngle=pairs*next(4);futureCosine=cos(futureAngle);futureSine=sin(futureAngle);
futureRotation=[futureCosine,-futureSine;futureSine,futureCosine];
matrix=futureRotation*diag([ld,lq])*futureRotation'+step*rs*eye(2);
forcing=oldFlux-flux*[futureCosine;futureSine];
transform=[1,0;-0.5,sqrt(3)/2;-0.5,-sqrt(3)/2];
diodeStates=zeros(3,1,'like',state);neutralVoltage=zeros(1,'like',state);
if mode==0
    [current,voltageAB,poleVoltage,neutralVoltage,diodeStates]= ...
        solveRectifier(matrix,forcing,step,bus,vf,ron,settings(13),settings(14));
elseif mode==1
    assert(all(isfinite(duty)) && all(duty>=0) && all(duty<=1),'PWM duty must be finite in [0,1].');
    poleVoltage=bus*duty;neutralVoltage=sum(poleVoltage)/3;
    voltageAB=[(2*poleVoltage(1)-poleVoltage(2)-poleVoltage(3))/3; ...
        (poleVoltage(2)-poleVoltage(3))/sqrt(3)];
    current=matrix\(forcing+step*voltageAB);
else
    poleVoltage=zeros(3,1,'like',state);voltageAB=zeros(2,1,'like',state);
    current=matrix\forcing;
end
next(1:2)=current;nextPhaseCurrent=transform*current;phaseVoltage=transform*voltageAB;
dcCurrent=zeros(1,'like',state);bridgeLoss=zeros(1,'like',state);
if mode==1
    dcCurrent=sum(duty.*nextPhaseCurrent);
elseif mode==0
    for phaseIndex=1:3
        if diodeStates(phaseIndex)<-0.5,dcCurrent=dcCurrent+nextPhaseCurrent(phaseIndex);end
        if abs(diodeStates(phaseIndex))>0.5
            bridgeLoss=bridgeLoss+vf*abs(nextPhaseCurrent(phaseIndex))+ron*nextPhaseCurrent(phaseIndex)^2;
        end
    end
end
residual=max(abs((matrix*current-forcing)/step-voltageAB));
assert(all(isfinite(next)) && all(isfinite(voltageAB)) && all(isfinite(poleVoltage)));
assert(max(abs(next(1:2)))<=settings(15) && abs(next(3))<=settings(16),'Physical model range exceeded.');
end

function [current,voltage,poles,neutral,states]=solveRectifier(matrix,forcing,step,bus,vf,ron,currentTolerance,voltageTolerance)
% Current into a motor phase is positive. Lower diode: +1; upper: -1.
% Open phase current is zero and its pole voltage lies between -Vf and Vdc+Vf.
transform=[1,0;-0.5,sqrt(3)/2;-0.5,-sqrt(3)/2];
current=zeros(2,1,'like',forcing);states=zeros(3,1,'like',forcing);
voltage=-forcing/step;freePoles=transform*voltage;
low=-vf-min(freePoles);high=bus+vf-max(freePoles);
neutral=(low+high)/2;poles=freePoles+neutral;
if high>=low-voltageTolerance,return;end
% A balanced three-wire current has both signs. These twelve conducting
% patterns plus the all-open case cover every feasible diode configuration.
patterns=[1,-1,0;1,0,-1;-1,1,0;0,1,-1;-1,0,1;0,-1,1; ...
    1,1,-1;1,-1,1;-1,1,1;1,-1,-1;-1,1,-1;-1,-1,1];
impedance=matrix/step+ron*eye(2);source=forcing/step;found=false;
for patternIndex=1:12
    candidateStates=patterns(patternIndex,:)';system=zeros(3,3,'like',forcing);rhs=zeros(3,1,'like',forcing);
    for phaseIndex=1:3
        if candidateStates(phaseIndex)==0
            system(phaseIndex,1:2)=transform(phaseIndex,:);
        else
            system(phaseIndex,1:2)=transform(phaseIndex,:)*impedance;
            system(phaseIndex,3)=1;
            rail=-vf;if candidateStates(phaseIndex)<0,rail=bus+vf;end
            rhs(phaseIndex)=rail+transform(phaseIndex,:)*source;
        end
    end
    solution=system\rhs;candidate=solution(1:2);candidateNeutral=solution(3);
    candidateVoltage=(matrix*candidate-forcing)/step;
    candidatePoles=transform*candidateVoltage+candidateNeutral;phaseCurrent=transform*candidate;
    valid=true;
    for phaseIndex=1:3
        if candidateStates(phaseIndex)>0
            valid=valid && phaseCurrent(phaseIndex)>=-currentTolerance;
        elseif candidateStates(phaseIndex)<0
            valid=valid && phaseCurrent(phaseIndex)<=currentTolerance;
        else
            valid=valid && abs(phaseCurrent(phaseIndex))<=currentTolerance && ...
                candidatePoles(phaseIndex)>=-vf-voltageTolerance && candidatePoles(phaseIndex)<=bus+vf+voltageTolerance;
        end
    end
    if valid
        current=candidate;voltage=candidateVoltage;poles=candidatePoles;
        neutral=candidateNeutral;states=candidateStates;found=true;break
    end
end
assert(found,'No consistent diode conduction state.');
end
