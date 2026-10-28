/*
    I-f 电频率积分与有界相位环绕
    定位、斜坡、PI、SVPWM 仅标明接入位置，实际代码由接入工程提供
    唯一运行状态为调用方持有的 double 相位
*/
#include "if_controller.h"

#include <float.h>

#if FLT_RADIX != 2 || DBL_MANT_DIG < 53
#error "IF phase accumulation requires at least binary64 double precision"
#endif

#define IF_TWO_PI (6.283185307179586476925286766559)

void if_init(double *phaseRad, float initialAngleRad)
{
    *phaseRad = (double)initialAngleRad;
}

float if_crtl(double *phaseRad, float frequencyHz, float periodS)
{
    double next;
    float angle;

    /****************************** 定位接入 ******************************/
    /*
        此处仅说明定位流程：固定电角度，给定 D 轴电流并保持
        定位电流和计时由接入工程完成，初始软件角度由 if_init() 设置
    */

    /****************************** 斜坡接入 ******************************/
    /* 如需平滑改速，接入工程先推进斜坡；frequencyHz 是本拍实际采用的电频率 */

    /****************************** I-f 相位计算 ******************************/
    next = *phaseRad + IF_TWO_PI * (double)frequencyHz * (double)periodS;
    if (next >= IF_TWO_PI) {
        next -= IF_TWO_PI;
    } else if (next < 0.0) {
        next += IF_TWO_PI;
    }
    *phaseRad = next;
    angle = (float)next;

    /* 接近整周期时 float 可能向上舍入，输出折回零，内部 double 相位继续保留 */
    angle = angle >= (float)IF_TWO_PI ? 0.0f : angle;

    /****************************** 电流 PI 接入 ******************************/
    /* 接入工程使用本拍 angle 完成 Park、电流 PI、限压和反 Park，此处不实现电流环 */

    /****************************** SVPWM 接入 ******************************/
    /* 接入工程将电流环得到的电压交给 SVPWM 并更新 PWM，此处不实现调制或硬件写入 */

    return angle;
}
