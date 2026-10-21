/**
 * @file test_example.c
 * @brief 分别编译原始示例，记录其当前单次调用生命周期。
 * @author HU JIAXUAN
 */

#include "foc.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static unsigned int g_initCount;
static unsigned int g_loopCount;
static bool g_failed;
static Foc g_lastController;

static bool baseline_init(Foc *controller);
static bool baseline_loop(Foc *controller);
static void run_once(void);

/**
 * @brief 观察初始化次数，真实初始化仍由原库完成。
 * @param[out] controller 示例持有的实例；不能为空。
 * @return 原始初始化的结果。
 */
static bool baseline_init(Foc *controller)
{
    /* 只记录调用，不替换控制算法。 */
    ++g_initCount;
    return foc_init(controller);
}

/**
 * @brief 观察原始周期调用及完整结果。
 * @param[in,out] controller 示例持有的实例；不能为空。
 * @return 原始控制周期结果。
 */
static bool baseline_loop(Foc *controller)
{
    bool valid = foc_loop(controller);

    /* 快照跨示例函数返回继续有效，不保留其栈指针。 */
    ++g_loopCount;
    g_lastController = *controller;
    g_failed = g_failed || !valid;
    return valid;
}

/* 每个测试目标只包含一个原文件，保留聚合示例的独立符号空间。 */
#define foc_init baseline_init
#define foc_loop baseline_loop
#define main baseline_main
#include FOC_EXAMPLE_SOURCE
#undef main
#undef foc_loop
#undef foc_init

/**
 * @brief 调用本目标对应的全部示例入口。
 */
static void run_once(void)
{
    /* 条件分支由编译目标固定，原示例源码不做修改。 */
#if FOC_EXAMPLE_KIND == 0
    app_foc_if_current_loop_example();
#elif FOC_EXAMPLE_KIND == 1
    app_foc_vf_open_loop_example();
    app_foc_if_open_loop_startup_example();
    app_foc_if_three_loop_example();
#elif FOC_EXAMPLE_KIND == 2
    app_foc_vf_minimal_example();
#elif FOC_EXAMPLE_KIND == 3
    if (baseline_main() != 0)
    {
        g_failed = true;
    }
#elif FOC_EXAMPLE_KIND == 4
    app_foc_if_open_loop_startup_example();
#elif FOC_EXAMPLE_KIND == 5
    app_foc_with_external_pid_example((AppPidOutput){1.0f}, (AppPidOutput){2.0f});
#else
#error "Unknown example kind"
#endif
}

/**
 * @brief 验证示例实际可执行，同时固定其每次重新初始化的现状。
 * @return 满足当前基线返回 EXIT_SUCCESS。
 */
int main(void)
{
    Foc first;
    const unsigned int calls = FOC_EXAMPLE_KIND == 1 ? 3U : 1U;

    /* 两次入口调用用于证明当前状态会重建，不能误报为持续运行示例。 */
    run_once();
    first = g_lastController;
    run_once();
    if (g_failed || g_initCount != 2U * calls || g_loopCount != 2U * calls ||
        !g_lastController.valid || !isfinite(g_lastController.duty_a) ||
        !isfinite(g_lastController.duty_b) || !isfinite(g_lastController.duty_c) ||
        g_lastController.duty_a < 0.0f || g_lastController.duty_a > 1.0f ||
        g_lastController.duty_b < 0.0f || g_lastController.duty_b > 1.0f ||
        g_lastController.duty_c < 0.0f || g_lastController.duty_c > 1.0f ||
        first.theta_e != g_lastController.theta_e ||
        first.pid_id.state.integral != g_lastController.pid_id.state.integral ||
        first.pid_iq.state.integral != g_lastController.pid_iq.state.integral)
    {
        fprintf(stderr, "example lifecycle baseline failed\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
