function spec=extension_foc_spec(kind)
%EXTENSION_FOC_SPEC Offline model/library selection, no runtime algorithm swap.
kind=char(validatestring(kind,{'mras','ekf','ukf','sigmoid'}));
switch kind
    case 'mras',model='MrasSensorlessFOC';library='MrasObserver';export='CurrentModelMRAS';module='观测器/模型参考自适应';
    case 'ekf',model='EkfSensorlessFOC';library='EkfObserver';export='EKF';module='观测器/扩展卡尔曼';
    case 'ukf',model='UkfSensorlessFOC';library='UkfObserver';export='UKF';module='观测器/无迹卡尔曼';
    case 'sigmoid',model='SigmoidSensorlessFOC';library='SigmoidSlidingModeObserver';export='SigmoidSMO';module='观测器/滑模';
end
spec=struct('kind',kind,'model',model,'library',library,'export',export,'module',module);
end
