/*
    I-f 软件电角度生成
    定位、斜坡、PI、SVPWM 在实现文件中仅以注释标明接入位置
*/
#ifndef IF_CONTROLLER_H
#define IF_CONTROLLER_H

#ifdef __cplusplus
extern "C" {
#endif

/*
    设置初始软件电角度
    输入：phaseRad 指向调用方持有的相位；initialAngleRad 为初始角，rad，[0, 2*pi)
    输出：覆盖 *phaseRad，后续调用从此角度累计
    约束：指针有效、初始角有限；同一相位由调用方独占访问
*/
void if_init(double *phaseRad, float initialAngleRad);

/*
    按电频率推进一拍相位，返回本拍软件电角度
    输入：phaseRad 已初始化；frequencyHz 为有符号电频率，Hz；periodS 为本拍周期，s
    输出：更新 *phaseRad，返回归一化的 float 电角度，rad，[0, 2*pi)
    约束：指针及输入有效，periodS > 0，abs(frequencyHz)*periodS < 0.5
          不检查调用前提；同一相位独占访问，频率和周期可在每次调用前直接修改
    数值：累计相位使用 double 保留低频增量，返回值使用 float
*/
float if_crtl(double *phaseRad, float frequencyHz, float periodS);

#ifdef __cplusplus
}
#endif
#endif
