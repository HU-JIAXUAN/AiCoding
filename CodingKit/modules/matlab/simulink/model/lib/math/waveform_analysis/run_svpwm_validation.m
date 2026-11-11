function report = run_svpwm_validation()
%RUN_SVPWM_VALIDATION Exercise both saved SVPWM libraries and their sequences.
module = fileparts(fileparts(mfilename('fullpath')));
src = fullfile(module,'src','svpwm');
testModel = 'SvpwmComparisonTest';
load_system(fullfile(src,[testModel,'.slx']));
out = sim(testModel);
data = out.trace.signals.values;
cfg = svpwm_test_parameters();
assert(numel(out.trace.time)==size(cfg.Stimulus,1) && ...
    max(abs(out.trace.time-cfg.Stimulus(:,1)))<1e-14,'Unexpected test sample times.');
assert(isequal(data(:,1:3),cfg.Stimulus(:,2:4)),'Unexpected test stimuli.');

alpha = data(:,1);
beta = data(:,2);
bus = data(:,3);
phase = [alpha,-alpha/2+sqrt(3)*beta/2,-alpha/2-sqrt(3)*beta/2];
seven = data(:,4:6);
five = data(:,8:10);
assert(all(isfinite(data),'all') && all(seven>=0 & seven<=1,'all') && ...
    all(five>=0 & five<=1,'all'),'Duties must be finite and bounded.');

tol = 1e-12;
interior = 1:12;
for k = interior
    d7 = seven(k,:);
    d5 = five(k,:);
    assert(abs(max(d7)+min(d7)-1)<tol && min(d7)>0 && max(d7)<1, ...
        'Seven-segment dwell times must split equally.');
    assert(nnz(d5==0)==1 && max(d5)<1,'Five-segment must clamp one phase low.');
    assert(isequal(switching_states(d7), ...
        expected_states(d7,[0 1 2 3 2 1 0])), ...
        'Unexpected seven-segment switching sequence in sector %d.',mod(k-1,6)+1);
    assert(isequal(switching_states(d5), ...
        expected_states(d5,[0 1 2 1 0])), ...
        'Unexpected five-segment switching sequence in sector %d.',mod(k-1,6)+1);
end

voltage7 = bus.*(seven-mean(seven,2));
voltage5 = bus.*(five-mean(five,2));
rows = [interior,13];
error7 = max(abs(voltage7(rows,:)-phase(rows,:)),[],'all');
error5 = max(abs(voltage5(rows,:)-phase(rows,:)),[],'all');
assert(max(error7,error5)<tol,'Linear phase voltage reconstruction failed.');
assert(all(seven(13,:)==0.5) && all(five(13,:)==0),'Zero-reference duty mismatch.');
assert(isequal(seven(14,:),[1,0,0]) && isequal(five(14,:),[1,0,0]), ...
    'Over-range duty saturation mismatch.');
assert(max(abs(data(:,7)+(max(phase,[],2)+min(phase,[],2))/2))<tol);
assert(max(abs(data(:,11)+bus/2+min(phase,[],2)))<tol);

report = struct('cases',size(data,1),'sector_checks',numel(interior), ...
    'seven_segment_max_voltage_error_V',error7,'five_segment_max_voltage_error_V',error5);
disp(report);
end

function states = switching_states(duty)
% Sample midway between ideal events on a shared carrier starting at its peak.
switchingDuty = duty(duty>0 & duty<1);
events = unique([0,(1-switchingDuty)/2,(1+switchingDuty)/2,1]);
midpoints = (events(1:end-1)+events(2:end))/2;
carrier = abs(2*midpoints(:)-1);
states = carrier < duty;
end

function states = expected_states(duty,activePhases)
[~,order] = sort(duty,'descend');
states = false(numel(activePhases),3);
for k = 1:numel(activePhases)
    states(k,order(1:activePhases(k))) = true;
end
end
