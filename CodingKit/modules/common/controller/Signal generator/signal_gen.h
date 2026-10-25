/*
    signal_gen.h
    每次调用计算一个点的波形发生器
    用户填写 SignalGenConfig，SignalGen 保存一路波形的运行进度
    每种波形有独立计算函数，update只负责选择调用 多路波形分别使用各自的 SignalGen
    先调用 signal_gen_init，再按固定周期调用 signal_gen_update
    作者 HU JIAXUAN
    日期 2026-10-25
*/
#ifndef SIGNAL_GEN_H
#define SIGNAL_GEN_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

/* 改成double即可切换幅值、频率和输出类型；所有源文件必须使用同一设置 */
#ifndef SIGNAL_GEN_REAL_TYPE
#define SIGNAL_GEN_REAL_TYPE float
#endif
    typedef SIGNAL_GEN_REAL_TYPE SignalGenReal;

#define SIGNAL_GEN_MAX_TONES (16u) /* 多正弦最多叠加16路 */

    /* 发生器状态；init/cfg/reset返回此值，周期计算后也可读取generator.status */
    typedef enum
    {
        SIGNAL_GEN_OK = 0,          /* 已计算一个点，或按要求暂停 */
        SIGNAL_GEN_DONE = 1,        /* 已到设置的时长，输出为 offset */
        SIGNAL_GEN_ERR_INPUT = -1,  /* 传入了空指针 */
        SIGNAL_GEN_ERR_CONFIG = -2, /* 参数不合适；请检查周期、频率、幅值等设置 */
        SIGNAL_GEN_ERR_STATE = -3,  /* 没有先初始化，或采样计数已经用完 */
        SIGNAL_GEN_ERR_NUMBER = -4  /* 计算结果超出了所选浮点类型能表示的范围 */
    } SignalGenStatus;

    /* 选择要产生的波形，只有所选波形的专用参数需要填写 */
    typedef enum
    {
        SIGNAL_GEN_DC = 0,       /* 常量，输出 offset + amplitude */
        SIGNAL_GEN_STEP,         /* 阶跃，在指定时刻从一个值切到另一个值 */
        SIGNAL_GEN_SINE,         /* 正弦波 */
        SIGNAL_GEN_SQUARE,       /* 方波，可设置高电平所占比例 */
        SIGNAL_GEN_TRIANGLE,     /* 对称三角波 */
        SIGNAL_GEN_TRAPEZOID,    /* 周期梯形波，可设置上升、平台、下降的比例 */
        SIGNAL_GEN_CHIRP_LINEAR, /* 线性扫频，频率随时间匀速变化 */
        SIGNAL_GEN_CHIRP_LOG,    /* 对数扫频，每经过相同时间，频率按相同比例变化 */
        SIGNAL_GEN_PRBS,         /* PRBS15伪随机二进制序列，只有高、低两个电平 */
        SIGNAL_GEN_NOISE,        /* 均匀随机噪声，两次刷新之间保持不变 */
        SIGNAL_GEN_MULTISINE     /* 将多路不同频率、幅值比例和初相的正弦相加 */
    } SignalGenWave;

    /* 阶跃设置；实际输出 = offset + amplitude * before 或 after */
    typedef struct
    {
        double atS;           /* 切换时刻，s；填0.5表示开始运行0.5秒后切换 */
        SignalGenReal before; /* 切换前的幅值比例，[-1,1]；填0表示输出 offset */
        SignalGenReal after;  /* 切换后的幅值比例，[-1,1]；填1表示输出 offset + amplitude */
    } SignalGenStep;

    /* 梯形波各段占完整周期的比例，填的是比例，不是秒数 */
    typedef struct
    {
        SignalGenReal rise; /* 从最低值升到最高值的比例，>0；填0.2表示用一个周期的20%上升 */
        SignalGenReal high; /* 保持最高值的比例，>=0；填0.3表示高平台持续一个周期的30% */
        SignalGenReal fall; /* 从最高值降到最低值的比例，>0；剩余时间保持最低值，三项之和<=1 */
    } SignalGenTrapezoid;

    /* 扫频起止频率；扫频时间填写公共参数 durationS，必须大于0 */
    typedef struct
    {
        SignalGenReal startHz; /* 开始频率，Hz，例如2；对数扫频必须大于0 */
        SignalGenReal endHz;   /* 结束频率，Hz，例如200；可小于开始频率，用来降频扫描 */
    } SignalGenChirp;

    /* 多正弦中的一路；最后按绝对权重之和分配公共幅值 amplitude */
    typedef struct
    {
        SignalGenReal frequencyHz; /* 这一路正弦的频率，Hz */
        SignalGenReal
            weight;         /* 相对幅值；例如权重1、2、1分得总幅值的1/4、1/2、1/4；负数使该路反相 */
        double phaseCycles; /* 这一路的初相，1表示一周，0.25表示90度；还会叠加公共初相 */
    } SignalGenTone;

    /* 多正弦设置；只填写 tones[0] 到 tones[count-1] */
    typedef struct
    {
        size_t count;                              /* 叠加多少路正弦，范围1~16 */
        SignalGenTone tones[SIGNAL_GEN_MAX_TONES]; /* 各路频率、相对幅值和初相 */
    } SignalGenMultisine;

    /*
        用户填写的波形参数
        先用 signal_gen_defaults(调用周期) 得到默认值，再修改需要的字段
        普通正弦只需设置 wave、frequencyHz、amplitude，其他参数可以保持默认
        初始化时会保存这些参数，之后修改原来的 cfg 变量不会改变正在输出的波形
    */
    typedef struct
    {
        /* 所有波形共用；时间和相位保留double，防止长时间运行积累偏差 */
        SignalGenWave wave; /* 波形种类，例如 SIGNAL_GEN_SINE */
        double periodS;     /* 每隔多少秒调用一次 update；20kHz填0.00005，1kHz填0.001 */
        SignalGenReal
            amplitude; /* 相对 offset 的最大变化量，>=0；offset=3、amplitude=2时输出范围为1~5 */
        SignalGenReal offset; /* 波形的直流偏置；做零均值电流扰动时通常填0，单位与 amplitude 相同 */
        SignalGenReal
            frequencyHz;    /* 普通周期波的完整周期频率；PRBS为换码次数/秒，噪声为刷新次数/秒 */
        double phaseCycles; /* 初相，1表示一周；0为0度，0.25为90度，负数或超过1也会换算到一周内 */
        double durationS;   /* 运行时长，s；0表示一直运行，正数表示到时结束；暂停时间不计入 */
        double fadeInS;     /* 开始时用多少秒把激励幅值从0逐渐升到设定值；0表示不用 */
        double fadeOutS; /* 结束前用多少秒把激励幅值逐渐降到0；0表示不用，使用时 durationS 必须>0 */

        /* 只在对应波形中使用 */
        SignalGenReal duty; /* 方波高电平占完整周期的比例，[0,1]；0.5表示一半高、一半低 */
        uint32_t seed;      /* 随机序列起点；PRBS填1~32767，噪声填任意非零值；相同值可重复实验 */
        SignalGenStep step; /* 仅阶跃使用：切换时刻及切换前后比例 */
        SignalGenTrapezoid trapezoid; /* 仅梯形波使用：上升、高平台和下降占周期的比例 */
        SignalGenChirp chirp;         /* 仅扫频使用：起止频率；此时忽略 frequencyHz */
        SignalGenMultisine multisine; /* 仅多正弦使用：路数和每路参数；此时忽略 frequencyHz */
    } SignalGenConfig;

    /*
        保存一路波形的运行进度，由模块自己维护
        一路定义一个变量，并让它在整个运行期间一直存在，例如定义成 static 变量
        不要在每次中断中重新创建或初始化它，否则波形每次都会从头开始
        下列字段都不需要用户赋值；修改参数使用 signal_gen_cfg，重新开始使用 signal_gen_reset
    */
    typedef struct
    {
        SignalGenConfig config; /* 当前使用的参数副本，更换参数请使用cfg函数 */

        /* 下面是刚计算出的结果，需要观察或记录时才读取 */
        SignalGenReal output;             /* 最近一次输出值，也就是update的返回值 */
        SignalGenReal currentFrequencyHz; /* 最近一次输出的频率，Hz；DC、阶跃和多正弦为0 */
        double phaseCycles;     /* 最近一次输出的相位，单位为周；多正弦没有统一相位，返回0 */
        double elapsedS;        /* 最近一次输出对应的运行时间，s；首点为0，不含暂停 */
        bool active;            /* true表示正在输出；false表示暂停、结束或发生错误 */
        bool finished;          /* true表示到达设置时长，reset后可重新输出 */
        SignalGenStatus status; /* 正常OK，结束DONE，计算出错为负值 */

        /* 以下数据由计算函数维护，不需要用户填写或修改 */
        double phase;                           /* 当前周期走到了哪里，单位为周，范围[0,1) */
        double tonePhase[SIGNAL_GEN_MAX_TONES]; /* 多正弦中各路当前的周期位置，单位为周 */
        SignalGenReal weightSum;                /* 各路绝对权重之和，用来分配多正弦的总幅值 */
        SignalGenReal noiseValue; /* 最近一次产生的噪声值，范围[-1,1]；未到刷新时刻就继续用它 */
        SignalGenReal logRatio;   /* 对数扫频使用的 ln(结束频率/开始频率)，初始化时算一次 */
        uint64_t sampleIndex;     /* 已产生了多少个点，用它乘 periodS 得到运行时间 */
        uint32_t prng;            /* 噪声发生器计算下一随机数时需要保存的整数 */
        uint32_t prbs;            /* PRBS15的15位移位寄存器 */
        bool initialized;         /* init成功后为true，避免跳过初始化直接使用 */
    } SignalGen;

    /*
        得到默认参数；默认输出为0，用户再选择波形和幅值
        periodS 固定调用周期，单位s；必须大于0
        返回 可直接修改的参数结构，具体参数在 init 时检查
    */
    SignalGenConfig signal_gen_defaults(double periodS);

    /*
        保存参数并从第0点开始 先调用一次本函数，再周期调用 update
        generator 保存这一路波形进度的变量
        config 用户设置的参数；函数会复制参数，之后不需要一直保留该变量
        返回 成功返回OK；参数错误返回负值，原来已经在运行的设置不变
    */
    SignalGenStatus signal_gen_init(SignalGen *generator, const SignalGenConfig *config);

    /*
        给已经初始化的发生器更换参数，并从头开始
        generator 已初始化的波形发生器
        config 新参数；如果不合适，保持原来的波形和进度
        返回 成功返回OK，否则返回负值 更换参数时输出可能跳变
    */
    SignalGenStatus signal_gen_cfg(SignalGen *generator, const SignalGenConfig *config);

    /*
        参数不变，回到初相和第0点；随机序列也会从同一个起点重放
        generator 已初始化的波形发生器
        返回 成功返回OK，否则返回负值
    */
    SignalGenStatus signal_gen_reset(SignalGen *generator);

    /*
        按wave选择对应的波形计算函数，直接返回当前输出
        generator 这一路的运行变量；同一路不要在任务和中断中同时调用
        enable true继续计算；false暂停并输出 offset；再次置true会接着上次的位置计算
        返回 当前波形值；暂停、结束或计算错误时返回offset，空指针或未初始化时返回0
        0本身也是合法输出，判断错误应读取generator.status，不能用输出是否为0判断
        到时结束后保持 offset，reset或cfg后才会重新开始
    */
    SignalGenReal signal_gen_update(SignalGen *generator, bool enable);

#ifdef __cplusplus
}
#endif
#endif
