/**
 * @file test_legacy.c
 * @brief 用重构前的实际 C 输出固定 PID/FOC 行为基线。
 * @author HU JIAXUAN
 */

#include "foc.h"
#include "pid.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static bool visit_row(FILE *fixture, const float *values, size_t count);
static size_t append_pid(const Pid *controller, float *row, size_t offset);
static bool capture_tick(int tick);
static void configure_pid(Pid *controller, int scenario);
static bool run_pid(FILE *fixture);
static bool run_foc(FILE *fixture);

/**
 * @brief 输出一行基线，或逐字段比较实际 C 结果。
 * @param[in,out] fixture 基线输入文件；NULL 表示向标准输出采集。
 * @param[in] values 当前可观测量，单位由字段定义。
 * @param[in] count 字段数量。
 * @return 字段一致或采集成功返回 true。
 */
static bool visit_row(FILE *fixture, const float *values, size_t count)
{
    size_t index;

    /* 文本保留足够位数以还原 binary32，比较不依赖结构体填充字节。 */
    for (index = 0; index < count; ++index)
    {
        double expected;
        double actual = values[index];

        if (fixture == NULL)
        {
            printf("%.9g%c", actual, index + 1 == count ? '\n' : ' ');
            continue;
        }
        if (fscanf(fixture, "%lf", &expected) != 1)
        {
            fprintf(stderr, "missing baseline field %zu\n", index);
            return false;
        }
        if (isnan(expected) && isnan(actual))
        {
            continue;
        }
        if (expected == actual)
        {
            continue;
        }
        if (!isfinite(expected) || !isfinite(actual) ||
            fabs(actual - expected) > fmax(1.0e-6, fabs(expected) * 3.0e-6))
        {
            fprintf(stderr, "scenario=%.0f tick=%.0f field=%zu expected=%.9g actual=%.9g\n",
                    (double)values[0], (double)values[1], index, expected, actual);
            return false;
        }
    }

    return true;
}

/**
 * @brief 把 PID 全部状态观测量追加到固定长度测试行。
 * @param[in] controller 已初始化控制器。
 * @param[out] row 调用方保证至少剩余 17 个 float 的空间。
 * @param[in] offset 当前字段位置。
 * @return 追加后的字段位置。
 */
static size_t append_pid(const Pid *controller, float *row, size_t offset)
{
    const PidState *state = &controller->state;
    const float values[] = {state->setpoint,
                            state->setpointLimited,
                            state->feedback,
                            state->feedbackLimited,
                            state->error,
                            state->previousError,
                            state->derivative,
                            state->derivativeFiltered,
                            state->proportional,
                            state->integral,
                            state->derivativeTerm,
                            state->feedforward,
                            state->rawOutput,
                            state->output,
                            (float)state->saturated,
                            (float)state->initialized,
                            (float)state->status};

    /* 显式字段列表使新增状态不会被结构体内存布局悄悄掩盖。 */
    memcpy(row + offset, values, sizeof(values));
    return offset + sizeof(values) / sizeof(values[0]);
}

/**
 * @brief 选择启动、故障和恢复附近的固定采样点。
 * @param[in] tick 从零计数的调用序号。
 * @return 当前调用应入基线返回 true。
 */
static bool capture_tick(int tick)
{
    /* 不只比较最终输出，保留中间积分与微分状态的证据。 */
    return tick == 0 || tick == 1 || tick == 7 || tick == 15 || tick == 16 || tick == 31 ||
           tick == 39 || tick == 40 || tick == 63 || tick == 95 || tick == 127;
}

/**
 * @brief 配置 P、PI、PD、PID 与边界行为。
 * @param[out] controller 测试实例；不能为空。
 * @param[in] scenario 基线场景编号。
 */
static void configure_pid(Pid *controller, int scenario)
{
    (void)pid_init(controller);
    controller->config.kp = 0.7f;
    controller->config.ki = 3.25f;
    controller->config.controlFreq = 1000.0f;

    /* 这里的参数只固定历史行为，不作为实际系统推荐值。 */
    if (scenario == 0 || scenario == 4)
    {
        controller->config.kp = 2.25f;
        controller->config.ki = 0.0f;
    }
    if (scenario == 2 || scenario == 3)
    {
        controller->config.kd = 0.003f;
        controller->config.derivativeFilterCoef = 0.65f;
    }
    if (scenario == 2)
    {
        controller->config.ki = 0.0f;
    }
    if (scenario == 3 || scenario == 5)
    {
        controller->config.setpointLimit = (PidLimit){true, -1.0f, 1.0f};
        controller->config.feedbackLimit = (PidLimit){true, -0.6f, 0.6f};
        controller->config.errorLimit = (PidLimit){true, -0.4f, 0.4f};
        controller->config.setpointRateEnable = true;
        controller->config.setpointRate = 4.0f;
        controller->config.integralLimit = (PidLimit){true, -0.3f, 0.3f};
        controller->config.outputLimit = (PidLimit){true, -0.8f, 0.8f};
        controller->config.deadband = 0.1f;
        controller->config.antiWindupGain = 0.5f;
    }
    if (scenario == 4)
    {
        controller->config.integralLimit = (PidLimit){true, 1.0f, 2.0f};
        controller->state.integral = 0.4f;
    }
}

/**
 * @brief 执行八组旧入口场景，包含历史非法配置和非有限输入行为。
 * @param[in,out] fixture 参考输入；NULL 表示采集。
 * @return 全部记录一致返回 true。
 */
static bool run_pid(FILE *fixture)
{
    int scenario;

    for (scenario = 0; scenario < 8; ++scenario)
    {
        Pid controller;
        int tick;

        configure_pid(&controller, scenario);
        for (tick = 0; tick < 64; ++tick)
        {
            float row[19] = {(float)scenario, (float)tick};
            size_t count;

            controller.input.setpoint = (float)((tick % 17) - 8) * 0.125f;
            controller.input.feedback = (float)((tick % 11) - 5) * 0.0625f;
            controller.input.feedforward = (float)((tick % 3) - 1) * 0.03125f;
            if (scenario == 6)
            {
                controller.config.controlFreq = tick >= 10 && tick < 20 ? 0.0f : 1000.0f;
                controller.config.outputLimit = (PidLimit){tick >= 30 && tick < 40, 1.0f, -1.0f};
            }
            if (scenario == 7)
            {
                controller.config.controlFreq = tick >= 40 && tick < 48 ? NAN : 1000.0f;
                if (tick == 16)
                {
                    controller.input.feedback = NAN;
                }
                if (tick == 32)
                {
                    controller.state = (PidState){0};
                }
            }

            (void)pid(&controller);
            count = append_pid(&controller, row, 2);
            if (capture_tick(tick) && !visit_row(fixture, row, count))
            {
                return false;
            }
        }
    }

    return true;
}

/**
 * @brief 覆盖 VF/IF、角度来源、外环、offset 和失败输出的历史链路。
 * @param[in,out] fixture 参考输入；NULL 表示采集。
 * @return 全部记录一致返回 true。
 */
static bool run_foc(FILE *fixture)
{
    int scenario;

    for (scenario = 0; scenario < 5; ++scenario)
    {
        Foc controller;
        int tick;

        if (!foc_init(&controller))
        {
            return false;
        }
        controller.control_freq = 20000.0f;
        controller.max_voltage = scenario == 3 ? 0.7f : 12.0f;
        controller.pid_id.config.kp = 2.0f;
        controller.pid_iq.config.kp = 2.0f;
        controller.pid_id.config.ki = 800.0f;
        controller.pid_iq.config.ki = 800.0f;
        controller.pid_pos.config.kp = 2.0f;
        controller.pid_pos.config.ki = 0.1f;
        controller.pid_vel.config.kp = 0.4f;
        controller.pid_vel.config.ki = 2.0f;
        controller.vf_boost_v = 1.0f;
        controller.vf_gain_v_per_hz = 0.2f;
        controller.vf_max_v = 6.0f;
        controller.enable_pos_loop = scenario == 4;
        controller.enable_vel_loop = scenario == 4;
        if (scenario == 2)
        {
            (void)foc_current_offset_set(&controller, (FocPhase){0.1f, -0.05f, -0.05f});
        }

        /* 每次调用更新输入，但沿用同一真实 Foc 对象。 */
        for (tick = 0; tick < 128; ++tick)
        {
            float row[96];
            const float head[] = {(float)scenario, (float)tick};
            size_t count;
            float observations[22];

            controller.mode = scenario < 2 ? FOC_MODE_VF : FOC_MODE_IF;
            controller.angle_mode =
                scenario == 0 || scenario == 3 ? FOC_ANGLE_OPEN_LOOP : FOC_ANGLE_SENSOR;
            controller.vbus = tick == 32 ? 0.0f : 24.0f;
            controller.ia = (float)((tick % 13) - 6) * 0.025f;
            controller.ib = -0.5f * controller.ia;
            controller.ic = -0.5f * controller.ia;
            controller.open_loop_freq_hz = tick < 64 ? 8.0f : -8.0f;
            controller.theta_e = controller.angle_mode == FOC_ANGLE_SENSOR
                                     ? (float)((tick % 20) - 8) * 0.1f
                                     : controller.theta_e;
            controller.cmd_id = 0.2f;
            controller.cmd_iq = tick < 64 ? 0.8f : -0.5f;
            controller.cmd_vd = scenario == 0 ? 0.0f : 0.25f;
            controller.cmd_vq = scenario == 0 ? 0.0f : 3.0f;
            controller.cmd_pos = 1.0f;
            controller.pos = (float)(tick % 10) * 0.025f;
            controller.vel = 0.1f;
            if (tick == 64)
            {
                controller.mode = (FocMode)99;
            }
            (void)foc_loop(&controller);

            observations[0] = controller.theta_e;
            observations[1] = controller.omega_e;
            observations[2] = controller.cmd_vel;
            observations[3] = controller.cmd_iq;
            observations[4] = controller.real_id;
            observations[5] = controller.real_iq;
            observations[6] = controller.real_ialpha;
            observations[7] = controller.real_ibeta;
            observations[8] = controller.out_vd;
            observations[9] = controller.out_vq;
            observations[10] = controller.out_valpha;
            observations[11] = controller.out_vbeta;
            observations[12] = controller.duty_a;
            observations[13] = controller.duty_b;
            observations[14] = controller.duty_c;
            observations[15] = (float)controller.saturated;
            observations[16] = (float)controller.valid;
            observations[17] = controller.ia_offset;
            observations[18] = controller.ib_offset;
            observations[19] = controller.ic_offset;
            observations[20] = (float)controller.current_offset_valid;
            observations[21] = (float)controller.offset_sample_count;
            memcpy(row, head, sizeof(head));
            memcpy(row + 2, observations, sizeof(observations));
            count = append_pid(&controller.pid_id, row, 24);
            count = append_pid(&controller.pid_iq, row, count);
            count = append_pid(&controller.pid_pos, row, count);
            count = append_pid(&controller.pid_vel, row, count);
            if (capture_tick(tick) && !visit_row(fixture, row, count))
            {
                return false;
            }
        }
    }

    return true;
}

/**
 * @brief 选择基线类型并执行比较；省略参考路径时只采集。
 * @param[in] argc 参数数量。
 * @param[in] argv 类型 pid/foc 及可选参考文件路径。
 * @return 一致返回 EXIT_SUCCESS，否则 EXIT_FAILURE。
 */
int main(int argc, char **argv)
{
    FILE *fixture = NULL;
    bool passed;

    /* 采集模式不在 CTest 中使用，正常测试始终读取固定参考。 */
    if (argc < 2 || argc > 3)
    {
        return EXIT_FAILURE;
    }
    if (argc == 3)
    {
        fixture = fopen(argv[2], "r");
        if (fixture == NULL)
        {
            return EXIT_FAILURE;
        }
    }
    passed = strcmp(argv[1], "pid") == 0 ? run_pid(fixture)
                                         : strcmp(argv[1], "foc") == 0 && run_foc(fixture);
    if (fixture != NULL)
    {
        float extra;
        passed = passed && fscanf(fixture, "%f", &extra) == EOF;
        (void)fclose(fixture);
    }

    return passed ? EXIT_SUCCESS : EXIT_FAILURE;
}
