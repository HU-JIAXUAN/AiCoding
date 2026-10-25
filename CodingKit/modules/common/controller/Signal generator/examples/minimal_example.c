/*
    minimal_example.c
    每隔1毫秒计算一次7Hz正弦，打印成CSV
    作者 HU JIAXUAN
    日期 2026-10-25
*/
#include "signal_gen.h"
#include <stdio.h>
#include <stdlib.h>

/* 初始化一次，然后每次调用直接取得一个波形值 */
int main(void)
{
    SignalGen generator;
    SignalGenConfig config = signal_gen_defaults(0.001);
    size_t index;
    SignalGenReal output;
    config.wave = SIGNAL_GEN_SINE;
    config.frequencyHz = 7.0;
    config.amplitude = 0.2;
    config.durationS = 1.0;
    config.fadeInS = 0.05;
    config.fadeOutS = 0.05;
    if (signal_gen_init(&generator, &config) != SIGNAL_GEN_OK)
    {
        return EXIT_FAILURE;
    }
    if (printf("time_s,value,phase_cycles,frequency_hz,active\n") < 0)
    {
        return EXIT_FAILURE;
    }
    /* 实机中放在固定周期任务里；这里用循环演示，多算一次以显示结束后的输出 */
    for (index = 0u; index <= 1000u; index++)
    {
        output = signal_gen_update(&generator, true);
        if (generator.status < 0)
        {
            return EXIT_FAILURE;
        }
        if (printf("%.9g,%.9g,%.9g,%.9g,%d\n", generator.elapsedS, output, generator.phaseCycles,
                   generator.currentFrequencyHz, generator.active ? 1 : 0) < 0)
        {
            return EXIT_FAILURE;
        }
    }
    return EXIT_SUCCESS;
}
