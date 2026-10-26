"""C99 motor primitives: independent analytical/Decimal references and discrete host experiments."""
from __future__ import annotations

import argparse
import cmath
import ctypes as C
from decimal import Decimal, localcontext
import hashlib
import json
import math
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import time

F, D, U, B = C.c_float, C.c_double, C.c_uint32, C.c_bool
P = C.POINTER


def structure(name, fields):
    return type(name, (C.Structure,), {"_fields_": fields})


Dq = structure("Dq", [("d", F), ("q", F)])
Phase = structure("Phase", [("a", F), ("b", F), ("c", F)])
Ab = structure("Ab", [("alpha", F), ("beta", F)])
SinCos = structure("SinCos", [("sinValue", F), ("cosValue", F)])
Motor = structure("Motor", [(x, F) for x in ("resistanceOhm", "ldH", "lqH", "fluxWb")] +
                  [("polePairs", U), ("version", U)])
Pi = structure("Pi", [(x, F) for x in ("kp", "ki", "integral")])
PiStep = structure("PiStep", [(x, F) for x in ("proportional", "integral", "output", "limit")])
PiDesign = structure("PiDesign", [(x, F) for x in ("kp", "ki", "closedPole", "phaseMarginRad", "crossoverRadS")])
Angle = structure("Angle", [("angleRad", F), ("speedRadS", F), ("latchTimeS", D), ("targetTimeS", D),
                  ("maxAgeS", F), ("maxPredictionRad", F), ("valid", B), ("alreadyPredicted", B)])
RlConfig = structure("RlConfig", [("periodS", D), ("minRankRatio", D), ("maxSpeedRadS", D),
                                 ("minSamples", U), ("version", U)])
Rl = structure("Rl", [("config", RlConfig)] + [(x, D) for x in ("ii", "iv", "vv", "iy", "vy", "yy")] +
               [("count", U)])
RlSample = structure("RlSample", [(x, D) for x in ("currentStartA", "currentEndA", "appliedVoltageV",
                     "speedRadS", "periodS")] + [("version", U), ("valid", B)])
RlResult = structure("RlResult", [(x, D) for x in ("resistanceOhm", "inductanceH", "pole", "voltageGain",
                     "rankRatio", "residualRmsA")] + [("samples", U)])
Mtpa = structure("Mtpa", [("currentA", F), ("direction", F), ("version", U)])
Limits = structure("Limits", [("currentMagnitudeA", F), ("voltageMagnitudeV", F),
                             ("currentLimited", B), ("voltageLimited", B)])
Deadtime = structure("Deadtime", [(x, F) for x in ("busVoltageV", "effectiveDelayS", "pwmPeriodS",
                     "transitionA")] + [("alreadyCompensated", B)])
Friction = structure("Friction", [(x, F) for x in ("coulombNm", "staticNm", "viscousNms",
                     "stribeckRadS", "transitionRadS")])
Mechanical = structure("Mechanical", [(x, F) for x in ("inertiaKgm2", "viscousNms", "speedRadS",
                      "accelRadS2", "knownLoadNm")])
DobConfig = structure("DobConfig", [(x, F) for x in ("periodS", "inertiaKgm2", "bandwidthRadS",
                       "maxDisturbanceNm")] + [("version", U)])
Dob = structure("Dob", [("config", DobConfig), ("estimateNm", F), ("previousSpeedRadS", F), ("alpha", F), ("primed", B)])
Biquad = structure("Biquad", [(x, F) for x in ("b0", "b1", "b2", "a1", "a2")])
BiquadState = structure("BiquadState", [(x, F) for x in ("x1", "x2", "y1", "y2")])
Pll = structure("Pll", [(x, F) for x in ("angleRad", "speedRadS", "periodS", "kpRadS", "kiRadS2",
                       "maxSpeedRadS")] + [("version", U)])
TrajRequest = structure("TrajRequest", [(x, D) for x in ("startRad", "endRad", "periodS", "maxSpeedRadS",
                           "maxAccelRadS2", "maxJerkRadS3")])
Trajectory = structure("Trajectory", [("startRad", D), ("endRad", D), ("periodS", D), ("samples", U)])
TrajectoryPoint = structure("TrajectoryPoint", [(x, D) for x in ("positionRad", "speedRadS", "accelRadS2",
                              "jerkRadS3")] + [("complete", B)])
FrfInput = structure("FrfInput", [("input", P(F)), ("output", P(F)), ("count", C.c_size_t),
                                 ("periodS", D), ("frequencyHz", D), ("minAmplitude", D)])
Frf = structure("Frf", [(x, D) for x in ("real", "imaginary", "magnitude", "phaseRad", "inputAmplitude",
                    "outputAmplitude")] + [("cycles", U)])
SvpwmConfig = structure("SvpwmConfig", [("maxModulation", F), ("enableAutoScale", B)])
SvpwmInput = structure("SvpwmInput", [("modulation", Ab)])
SvpwmState = structure("SvpwmState", [(x, F) for x in ("dutyA", "dutyB", "dutyC", "scale")] +
                        [("saturated", B), ("valid", B)])
Svpwm = structure("Svpwm", [("config", SvpwmConfig), ("input", SvpwmInput), ("state", SvpwmState)])
PhaseSample = structure("PhaseSample", [("currentA", Phase), ("validMask", U), ("maxZeroSumA", F),
                           ("sampleTimeS", D), ("targetTimeS", D), ("maxAgeS", F)])
BusSample = structure("BusSample", [("busCurrentA", F), ("switchState", U), ("sampleTimeS", D),
                                   ("validWindowS", F), ("valid", B)])
ShuntLimits = structure("ShuntLimits", [("targetTimeS", D)] + [(x, F) for x in ("minWindowS", "maxAgeS",
                           "maxSeparationS", "maxPhaseSlopeAS", "maxErrorA")] + [("slopeBoundValid", B)])
Reconstructed = structure("Reconstructed", [("currentA", Phase), ("errorBoundA", F)])

BRIDGE = r"""
#include "motor.h"
#include "foc.h"
#include <math.h>
int bridge_foc(float freq, float bus, float angle, float openFreq, float direction, int sensor, float *out)
{
    Foc control;
    if (!foc_init(&control)) { return -1; }
    control.mode = FOC_MODE_VF;
    control.angle_mode = sensor ? FOC_ANGLE_SENSOR : FOC_ANGLE_OPEN_LOOP;
    control.control_freq = freq;
    control.vbus = bus;
    control.theta_e = angle;
    control.open_loop_freq_hz = openFreq;
    control.dir = direction;
    control.cmd_vd = 1.2f;
    control.cmd_vq = -0.4f;
    if (!foc_loop(&control)) { return 0; }
    out[0] = control.duty_a;
    out[1] = control.duty_b;
    out[2] = control.duty_c;
    out[3] = control.theta_e;
    return control.valid ? 1 : -2;
}
"""


class Checks:
    def __init__(self):
        self.counts = {}
        self.failures = []

    def check(self, group, condition, message):
        self.counts[group] = self.counts.get(group, 0) + 1
        if not condition:
            self.failures.append({"group": group, "message": message})

    def near(self, group, actual, expected, message, rel=3e-6, absolute=1e-7):
        self.check(group, math.isfinite(actual) and math.isclose(actual, expected, rel_tol=rel, abs_tol=absolute),
                   f"{message}: actual={actual:.12g}, reference={expected:.12g}")


def bind(lib, name, arguments, result=C.c_int):
    fn = getattr(lib, name)
    fn.argtypes, fn.restype = arguments, result
    return fn


def load_api(path):
    lib = C.CDLL(str(path))
    signatures = {
        "mc_dq_ff": [P(Motor), Dq, F, P(Dq)],
        "mc_pi_design": [F, F, F, F, F, P(PiDesign)],
        "mc_pi_cfg": [P(Pi), F, F, F, F],
        "mc_align_angle": [P(Angle), P(F)],
        "mc_rl_init": [P(Rl), P(RlConfig)], "mc_rl_add": [P(Rl), P(RlSample)], "mc_rl_fit": [P(Rl), P(RlResult)],
        "mc_mtpa": [P(Motor), P(Mtpa), P(Dq)], "mc_torque": [P(Motor), Dq, P(F)],
        "mc_check_limits": [P(Motor), Dq, F, F, F, P(Limits)],
        "mc_deadtime": [P(Deadtime), Phase, P(Phase)], "mc_friction": [P(Friction), F, P(F)],
        "mc_mech_ff": [P(Mechanical), P(F)], "mc_dob_init": [P(Dob), P(DobConfig)],
        "mc_dob_update": [P(Dob), F, F, B, U, P(F)],
        "mc_notch": [F, F, F, F, P(Biquad)], "mc_filter": [P(BiquadState), P(Biquad), F, P(F)],
        "mc_pll_init": [P(Pll), F, F, F, F, U], "mc_pll_update": [P(Pll), F, B, U],
        "mc_dual_error": [F, F, F, F, P(F)], "mc_schedule": [U, U, U, P(B)],
        "mc_ripple": [F, P(F), C.c_size_t, P(F)],
        "mc_traj_plan": [P(TrajRequest), P(Trajectory)],
        "mc_traj_sample": [P(Trajectory), U, P(TrajectoryPoint)],
        "mc_frf": [P(FrfInput), P(Frf)],
        "mc_phase_current": [P(PhaseSample), P(Phase)],
        "mc_bus_current": [P(BusSample), P(BusSample), P(ShuntLimits), P(Reconstructed)],
        "pid_pi_eval": [P(Pi), F, F, F, P(PiStep)], "pid_pi_track": [P(Pi), P(PiStep), F],
        "bridge_foc": [F, F, F, F, F, C.c_int, P(F)],
    }
    for name, args in signatures.items():
        bind(lib, name, args)
    bind(lib, "foc_clarke", [Phase], Ab)
    bind(lib, "foc_park", [Ab, SinCos], Dq)
    bind(lib, "foc_inv_park", [Dq, SinCos], Ab)
    bind(lib, "foc_svpwm_init", [P(Svpwm)], B)
    bind(lib, "foc_svpwm", [P(Svpwm)], B)
    return lib


def test_dq(api, checks):
    motor = Motor(0.2, 0.0003, 0.0005, 0.015, 7, 1)
    out = Dq()
    with localcontext() as context:
        context.prec = 60
        ld, lq, flux = map(Decimal.from_float, (motor.ldH, motor.lqH, motor.fluxWb))
        for speed in (-10000, -3000, -1, 0, 1, 3000, 10000):
            for id_a in (-20, -2, 0, 2, 20):
                for iq_a in (-20, -2, 0, 2, 20):
                    checks.check("dq", api.mc_dq_ff(motor, Dq(id_a, iq_a), speed, out) == 0, "dq status")
                    checks.near("dq", out.d, float(-Decimal(speed) * lq * Decimal(iq_a)), "d sign/unit")
                    checks.near("dq", out.q, float(Decimal(speed) * (ld * Decimal(id_a) + flux)), "q sign/unit")
    for current, speed in ((Dq(float("nan"), 0), 1), (Dq(1, 0), float("inf"))):
        out = Dq(77, 88)
        checks.check("dq_fault", api.mc_dq_ff(motor, current, speed, out) == 2 and out.d == 77, "nonfinite unchanged")
    checks.check("dq_fault", api.mc_dq_ff(None, Dq(), 0, out) == 1, "null")
    for angle in [k * 0.03141592653589793 for k in range(-100, 101)]:
        phase = Phase(math.cos(angle), math.cos(angle - 2 * math.pi / 3), math.cos(angle + 2 * math.pi / 3))
        actual = api.foc_park(api.foc_clarke(phase), SinCos(math.sin(angle), math.cos(angle)))
        checks.near("transforms", actual.d, 1, "balanced cosine -> d=1")
        checks.near("transforms", actual.q, 0, "balanced cosine -> q=0", absolute=2e-7)
        restored = api.foc_inv_park(actual, SinCos(math.sin(angle), math.cos(angle)))
        checks.near("transforms", restored.alpha, math.cos(angle), "inverse alpha", absolute=2e-7)
        checks.near("transforms", restored.beta, math.sin(angle), "inverse beta", absolute=2e-7)


def test_pi(api, checks):
    design = PiDesign()
    r, l, ts, bandwidth = map(lambda x: F(x).value, (0.3, 0.001, 0.00005, 400))
    checks.check("pi", api.mc_pi_design(r, l, ts, bandwidth, 0, design) == 0, "design")
    with localcontext() as context:
        context.prec = 60
        rd, ld, td, fd = map(Decimal.from_float, (r, l, ts, bandwidth))
        a = (-rd * td / ld).exp()
        b = (1 - a) / rd
        p = (-2 * Decimal("3.141592653589793238462643383279502884197") * fd * td).exp()
        checks.near("pi", design.kp, float(a * (1 - p) / b), "exact discrete kp")
        checks.near("pi", design.ki, float((1 - a) * (1 - p) / b / td), "exact discrete ki")
        checks.near("pi", design.closedPole, float(p), "closed pole")
    baseline = bytes(design)
    checks.check("pi_fault", api.mc_pi_design(r, l, ts, 5000, 0, design) == 8 and bytes(design) == baseline,
                 "sampling constraint no mutation")
    checks.check("pi_fault", api.mc_pi_design(r, l, ts, bandwidth, 0.001, design) == 8,
                 "extra execution delay violates margin")
    checks.check("pi", api.mc_pi_design(r, l, ts, bandwidth, ts, design) == 0, "one extra cycle accepted at low bandwidth")
    checks.check("pi", design.phaseMarginRad < math.pi / 2, "delay lowers predicted margin")
    checks.check("pi_fault", api.mc_pi_design(-r, l, ts, bandwidth, 0, design) == 3, "negative R rejected")
    checks.check("pi_fault", api.mc_pi_design(r, l, float("nan"), bandwidth, 0, design) == 2, "invalid period")
    snapshot = bytes(design)
    checks.check("pi_fault", api.mc_pi_design(r, l, ts, 1e-8, 0, design) == 8 and bytes(design) == snapshot,
                 "float pole rounding to one is not accepted as a stable design")
    checks.check("pi_fault", api.mc_pi_design(1e38, 1e38, 0.0001, 100, 0, design) == 2 and
                 bytes(design) == snapshot, "out-of-float-range gains rejected before narrowing conversion")
    # 独立complex频响+二分找交越，校验C内解析解确实使用量化后的PI系数
    for parameters in ((0.1, 0.0001, 0.00001, 1000, 0.00001),
                       (0.35, 0.0008, 0.00005, 400, 0),
                       (20, 0.05, 0.001, 20, 0.0001),
                       (0.001, 0.1, 0.0001, 10, 0.001)):
        qr, ql, qt, qf, qdelay = (F(value).value for value in parameters)
        quantized = PiDesign()
        checks.check("pi_quantization", api.mc_pi_design(qr, ql, qt, qf, qdelay, quantized) == 0,
                     "normal quantized coefficients accepted")
        plant_pole = math.exp(-qr * qt / ql)
        plant_gain = -math.expm1(-qr * qt / ql) / qr
        integral_step = F(quantized.ki * qt).value

        def loop_at(omega):
            inverse_z = cmath.exp(-1j * omega)
            control = quantized.kp + integral_step / (1 - inverse_z)
            return control * plant_gain * inverse_z / (1 - plant_pole * inverse_z)

        low, high = 1e-10, math.pi - 1e-10
        for _ in range(80):
            mid = (low + high) / 2
            if abs(loop_at(mid)) > 1:
                low = mid
            else:
                high = mid
        normalized_cross = (low + high) / 2
        reference_pm = math.pi + cmath.phase(loop_at(normalized_cross)) - normalized_cross / qt * qdelay
        checks.near("pi_quantization", quantized.crossoverRadS, normalized_cross / qt,
                    "actual stored-coefficient crossover", rel=3e-6)
        checks.near("pi_quantization", quantized.phaseMarginRad, reference_pm,
                    "actual stored-coefficient margin", rel=3e-6)
        trace = 1 + plant_pole - plant_gain * (quantized.kp + integral_step)
        determinant = plant_pole - plant_gain * quantized.kp
        roots = [(trace + sign * cmath.sqrt(trace * trace - 4 * determinant)) / 2 for sign in (-1, 1)]
        checks.check("pi_quantization", all(abs(root) < 1 for root in roots), "quantized closed-loop poles inside unit circle")
    api.mc_pi_design(r, l, ts, bandwidth, 0, design)
    pole = math.exp(-r * ts / l)
    gain = (1 - pole) / r
    # 真实C99 PI + 独立解析ZOH对象；加一拍输出延迟时波形必须不同
    responses = []
    for delay in (0, 1):
        pi, current, previous_voltage, result = Pi(design.kp, design.ki, 0), 0.0, 0.0, []
        for k in range(300):
            step = PiStep()
            error = 1.0 - current
            checks.check("pi_sim", api.pid_pi_eval(pi, error, ts, 100, step) == 0, "shared PI eval")
            checks.check("pi_sim", api.pid_pi_track(pi, step, step.output) == 0, "shared PI track")
            voltage = step.output if delay == 0 else previous_voltage
            previous_voltage = step.output
            current = pole * current + gain * voltage
            result.append(current)
        checks.near("pi_sim", current, 1, "closed loop reaches reference", rel=1e-5)
        if delay == 0:
            for k in (0, 1, 2, 5, 10, 30):
                checks.near("pi_sim", result[k], 1 - design.closedPole ** (k + 1), "closed pole truth", rel=2e-5)
        responses.append(result)
    checks.check("pi_sim", responses[1][0] == 0 and abs(responses[1][5] - responses[0][5]) > 0.005,
                 "one-cycle actuation delay changes transient")
    # 饱和实际量减去前馈后回跟踪；不是再次累积积分
    pi = Pi(1.2, 300, 0)
    step = PiStep()
    api.pid_pi_eval(pi, 5, ts, 10, step)
    ff, total_limit = 7.0, 3.0
    actual_total = max(-total_limit, min(total_limit, step.output + ff))
    actual_pi = actual_total - ff
    checks.check("pi_aw", api.pid_pi_track(pi, step, actual_pi) == 0, "post-FF actual PI tracking")
    checks.near("pi_aw", pi.integral, actual_pi - step.proportional, "actual voltage AW residual")
    before = pi.kp * 2 + pi.integral
    checks.check("pi_aw", api.mc_pi_cfg(pi, 0.8, 250, 2, 20) == 0, "bumpless parameter config")
    checks.near("pi_aw", pi.kp * 2 + pi.integral, before, "proportional change offset by state")
    snapshot = bytes(pi)
    checks.check("pi_fault", api.mc_pi_cfg(pi, 1, 0, 2, 20) == 8 and bytes(pi) == snapshot,
                 "unsupported zero-I bumpless transition rejected")


def test_rl(api, checks):
    rng = random.Random(0x20261026)
    cfg = RlConfig(0.00005, 1e-5, 0, 20, 42)
    state, result = Rl(), RlResult()
    checks.check("rl", api.mc_rl_init(state, cfg) == 0, "init")
    with localcontext() as context:
        context.prec = 65
        resistance, inductance, period = Decimal("0.35"), Decimal("0.0008"), Decimal.from_float(cfg.periodS)
        a = (-resistance * period / inductance).exp()
        b = (1 - a) / resistance
        current = Decimal("0.123")
        for k in range(800):
            voltage = Decimal(rng.choice((-8, -4, 0, 2, 6, 8)))
            next_current = a * current + b * voltage
            sample = RlSample(float(current), float(next_current), float(voltage), 0, cfg.periodS, 42, True)
            checks.check("rl", api.mc_rl_add(state, sample) == 0, "accept exact ZOH interval")
            current = next_current
    checks.check("rl", api.mc_rl_fit(state, result) == 0, "fit")
    checks.near("rl", result.resistanceOhm, 0.35, "R recovery", rel=2e-10)
    checks.near("rl", result.inductanceH, 0.0008, "L recovery", rel=2e-10)
    checks.check("rl", result.rankRatio > cfg.minRankRatio and result.residualRmsA < 1e-6, "rank and residual")
    # 独立留出集按真实对象生成，不复用拟合残差作为唯一验收
    predicted_a = math.exp(-result.resistanceOhm * cfg.periodS / result.inductanceH)
    predicted_b = (1 - predicted_a) / result.resistanceOhm
    actual_a = math.exp(-0.35 * cfg.periodS / 0.0008)
    actual_b = (1 - actual_a) / 0.35
    for current, voltage in ((-20, -8), (-2, 8), (0, 4), (2, -8), (20, 8)):
        checks.near("rl_holdout", predicted_a * current + predicted_b * voltage,
                    actual_a * current + actual_b * voltage, "independent validation", rel=1e-10)
    snapshot = bytes(state)
    for sample, expected in ((RlSample(1, 2, 3, 0, cfg.periodS, 43, True), 5),
                             (RlSample(1, 2, 3, 0.1, cfg.periodS, 42, True), 8),
                             (RlSample(1, 2, 3, 0, cfg.periodS * 2, 42, True), 3),
                             (RlSample(1, 2, 3, 0, cfg.periodS, 42, False), 6),
                             (RlSample(float("nan"), 2, 3, 0, cfg.periodS, 42, True), 2)):
        checks.check("rl_fault", api.mc_rl_add(state, sample) == expected and bytes(state) == snapshot,
                     f"bad sample code {expected}, unchanged state")
    api.mc_rl_init(state, cfg)
    checks.check("rl_fault", api.mc_rl_fit(state, result) == 7, "insufficient samples")
    for _ in range(30):
        api.mc_rl_add(state, RlSample(10, 10, 3.5, 0, cfg.periodS, 42, True))
    checks.check("rl_fault", api.mc_rl_fit(state, result) == 7, "steady DC is rank-deficient")
    # 有输入噪声时该OLS存在偏差；只验有限噪声工况，不宣称在线EIV无偏
    api.mc_rl_init(state, cfg)
    current = 0.0
    for k in range(2000):
        voltage = rng.choice((-8, -4, 0, 4, 8))
        next_current = actual_a * current + actual_b * voltage
        api.mc_rl_add(state, RlSample(current + rng.uniform(-1e-4, 1e-4),
                                     next_current + rng.uniform(-1e-4, 1e-4), voltage, 0, cfg.periodS, 42, True))
        current = next_current
    checks.check("rl_noise", api.mc_rl_fit(state, result) == 0, "noisy fit")
    checks.near("rl_noise", result.resistanceOhm, 0.35, "R small-noise acceptance", rel=0.003)
    checks.near("rl_noise", result.inductanceH, 0.0008, "L small-noise acceptance", rel=0.003)


def test_feedback(api, checks):
    output = F(99)
    for speed in (-10000, -100, 0, 100, 10000):
        item = Angle(0.3, speed, 10, 10.00002, 0.0001, 0.5, True, False)
        checks.check("angle", api.mc_align_angle(item, output) == 0, "align")
        checks.near("angle", output.value, math.remainder(F(0.3).value + speed * (10.00002 - 10), 2 * math.pi),
                    "latch age prediction")
    for field, value, code in (("valid", False, 6), ("alreadyPredicted", True, 9),
                               ("targetTimeS", 9, 4), ("targetTimeS", 11, 4),
                               ("angleRad", float("nan"), 2), ("maxPredictionRad", 0.01, 8)):
        item = Angle(0.3, 10000, 10, 10.00002, 0.0001, 0.5, True, False)
        setattr(item, field, value)
        output.value = 99
        checks.check("angle_fault", api.mc_align_angle(item, output) == code and output.value == 99,
                     f"{field} rejected with code {code}")
    due = B()
    for cycle in range(120):
        checks.check("multirate", api.mc_schedule(cycle, 4, 1, due) == 0 and due.value == (cycle % 4 == 1),
                     "integer phase schedule")
    checks.check("multirate", api.mc_schedule(0, 0, 0, due) == 3, "zero divisor")
    checks.check("multirate", api.mc_schedule(0, 4, 4, due) == 3, "invalid phase")
    checks.check("dual_feedback", api.mc_dual_error(10, 1.9, 5, 0.2, output) == 0, "gear coordinates")
    checks.near("dual_feedback", output.value, 0.1, "load-side error")
    checks.check("dual_feedback", api.mc_dual_error(10, 1, 5, 0.2, output) == 8, "inconsistency trips")
    checks.check("dual_feedback", api.mc_dual_error(10, 1, 0, 0.2, output) == 3, "zero ratio")


def test_allocation(api, checks):
    motor = Motor(0.2, 0.0003, 0.0008, 0.015, 7, 1)
    for current in (0, 0.01, 1, 5, 20, 100):
        for direction in (-1, 1):
            request, out, torque = Mtpa(current, direction, 1), Dq(), F()
            checks.check("mtpa", api.mc_mtpa(motor, request, out) == 0, "MTPA")
            checks.near("mtpa", math.hypot(out.d, out.q), current, "current circle", absolute=1e-6)
            api.mc_torque(motor, out, torque)
            # 独立角度穷举反证：所有[-pi/2,0]候选转矩均不能更大
            for index in range(181):
                angle = -math.pi / 2 * index / 180
                id_a, iq_a = current * math.sin(angle), direction * current * math.cos(angle)
                candidate = 1.5 * motor.polePairs * (motor.fluxWb + (motor.ldH - motor.lqH) * id_a) * iq_a
                checks.check("mtpa_optimality", abs(torque.value) + 1e-4 * max(1, abs(torque.value)) >= abs(candidate),
                             "independent angular grid optimum")
            # 一阶极值条件 psi*id + delta*(I²-2id²)=0
            residual = motor.fluxWb * out.d + (motor.lqH - motor.ldH) * (current**2 - 2 * out.d**2)
            checks.near("mtpa", residual, 0, "stationarity", absolute=1e-5)
    spm = Motor(0.2, 0.0003, 0.0003, 0.015, 7, 1)
    out = Dq()
    checks.check("mtpa", api.mc_mtpa(spm, Mtpa(10, 1, 1), out) == 0 and out.d == 0 and out.q == 10,
                 "SPM no divide-by-saliency")
    checks.check("mtpa_fault", api.mc_mtpa(motor, Mtpa(10, 1, 2), out) == 5, "version mismatch")
    checks.check("mtpa_fault", api.mc_mtpa(motor, Mtpa(-1, 1, 1), out) == 3, "negative magnitude")
    limits = Limits()
    for speed, voltage_limit, expect in ((0, 24, False), (10000, 24, True), (-10000, 24, True), (1000, 8, True)):
        checks.check("constraints", api.mc_check_limits(motor, Dq(-2, 5), speed, 6, voltage_limit, limits) == 0,
                     "check ellipse")
        checks.check("constraints", limits.voltageLimited == expect and not limits.currentLimited,
                     "speed/reverse/bus-drop voltage constraint")
    api.mc_check_limits(motor, Dq(10, 10), 0, 6, 24, limits)
    checks.check("constraints", limits.currentLimited, "current limit")


def test_compensation(api, checks):
    cfg = Deadtime(48, 0.0000005, 0.00005, 0.2, False)
    out = Phase()
    checks.check("deadtime", api.mc_deadtime(cfg, Phase(1, -0.5, -0.5), out) == 0, "deadtime")
    # 48*0.5us/50us = 0.48V，去零序后[0.64,-0.32,-0.32]
    for value, expected in zip((out.a, out.b, out.c), (0.64, -0.32, -0.32)):
        checks.near("deadtime", value, expected, "effective voltage")
    for scale in (-1, -0.1, 0, 0.1, 1):
        api.mc_deadtime(cfg, Phase(scale, -scale, 0), out)
        checks.near("deadtime", out.a + out.b + out.c, 0, "neutral zero-sum", absolute=1e-7)
        checks.check("deadtime", out.a * scale >= 0, "calibrated polarity")
    cfg.alreadyCompensated = True
    checks.check("deadtime_fault", api.mc_deadtime(cfg, Phase(1, -1, 0), out) == 9, "duplicate compensation")
    cfg.alreadyCompensated = False
    cfg.pwmPeriodS = 0
    checks.check("deadtime_fault", api.mc_deadtime(cfg, Phase(1, -1, 0), out) == 3, "zero PWM period")
    friction = Friction(0.2, 0.4, 0.001, 1, 0.01)
    value, opposite = F(), F()
    for speed in (0, 0.001, 0.1, 1, 10, 100):
        checks.check("friction", api.mc_friction(friction, speed, value) == 0, "friction")
        api.mc_friction(friction, -speed, opposite)
        checks.near("friction", value.value, -opposite.value, "odd smooth model")
        expected = ((friction.coulombNm + (friction.staticNm - friction.coulombNm) *
                     math.exp(-(speed / friction.stribeckRadS)**2)) * math.tanh(speed / friction.transitionRadS) +
                    friction.viscousNms * speed)
        checks.near("friction", value.value, expected, "reference model")
    mechanical = Mechanical(0.002, 0.01, -100, 500, 0.2)
    checks.check("mechanical_ff", api.mc_mech_ff(mechanical, value) == 0, "mechanical FF")
    checks.near("mechanical_ff", value.value, 0.2, "J*a+B*w+known load")
    coefficients = (F * 4)(0.3, 0.1, -0.2, 0.05)
    for angle in (-3, -1, 0, 1, 3):
        checks.check("ripple", api.mc_ripple(angle, coefficients, 4, value) == 0, "harmonics")
        expected = 0.3 * math.cos(angle) + 0.1 * math.sin(angle) - 0.2 * math.cos(2 * angle) + 0.05 * math.sin(2 * angle)
        checks.near("ripple", value.value, expected, "independent Fourier sum")
    checks.check("ripple_fault", api.mc_ripple(0, coefficients, 3, value) == 3, "odd table")
    checks.check("ripple_fault", api.mc_ripple(0, coefficients, 34, value) == 3, "bounded harmonic count")


def test_observers_filters(api, checks):
    cfg = DobConfig(0.001, 0.002, 100, 2, 3)
    dob, value = Dob(), F()
    checks.check("dob", api.mc_dob_init(dob, cfg) == 0, "DOB init")
    checks.check("dob", api.mc_dob_update(dob, 0.5, 0, True, 3, value) == 0 and value.value == 0,
                 "first frame establishes baseline")
    for k in range(1, 81):
        # interval torque 0.5, J*accel 0.2 => opposing external torque 0.3
        speed = 100 * k * cfg.periodS
        checks.check("dob", api.mc_dob_update(dob, 0.5, speed, True, 3, value) == 0, "DOB update")
        expected = 0.3 * (1 - math.exp(-cfg.bandwidthRadS * cfg.periodS * k))
        checks.near("dob", value.value, expected, "exact-ZOH Q step", rel=2e-5, absolute=1e-6)
    snapshot = bytes(dob)
    held_estimate = dob.estimateNm
    checks.check("dob_fault", api.mc_dob_update(dob, 1, 1, False, 3, value) == 6 and
                 dob.estimateNm == held_estimate and not dob.primed,
                 "invalid sample does not integrate and clears differentiation baseline")
    checks.check("dob_fault", api.mc_dob_update(dob, 1, 10, True, 3, value) == 0 and
                 dob.estimateNm == held_estimate and dob.primed, "recovery does not differentiate across lost frame")
    checks.check("dob_fault", api.mc_dob_update(dob, 1, 1, True, 4, value) == 5, "version mismatch")
    for k in range(200):
        api.mc_dob_update(dob, 100, 0, True, 3, value)
    checks.near("dob", value.value, 2, "disturbance clamp")
    coefficients = Biquad()
    checks.check("notch", api.mc_notch(300, 0.02, 0.4, 0.0001, coefficients) == 0, "notch design")
    z = cmath.exp(2j * math.pi * 300 * F(0.0001).value)
    actual_h = (coefficients.b0 + coefficients.b1 / z + coefficients.b2 / z**2) / (
        1 + coefficients.a1 / z + coefficients.a2 / z**2)
    checks.near("notch", abs(actual_h), F(0.02).value / F(0.4).value, "prewarped center attenuation", rel=1e-4)
    roots = [(complex(-coefficients.a1) + sign * cmath.sqrt(coefficients.a1**2 - 4 * coefficients.a2)) / 2
             for sign in (-1, 1)]
    checks.check("notch", all(abs(root) < 1 for root in roots), "quantized poles stable")
    state = BiquadState()
    x1 = x2 = y1 = y2 = 0.0
    for k in range(1000):
        input_value = F(math.sin(0.2 * k) + 0.1 * math.cos(0.01 * k)).value
        expected = (coefficients.b0 * input_value + coefficients.b1 * x1 + coefficients.b2 * x2 -
                    coefficients.a1 * y1 - coefficients.a2 * y2)
        checks.check("notch_sim", api.mc_filter(state, coefficients, input_value, value) == 0, "filter update")
        checks.near("notch_sim", value.value, expected, "independent state recurrence", rel=1e-4, absolute=2e-6)
        x2, x1, y2, y1 = x1, input_value, y1, F(expected).value
    checks.check("notch_fault", api.mc_notch(5000, 0.1, 0.4, 0.0001, coefficients) == 3, "Nyquist constraint")
    pll = Pll()
    checks.check("pll", api.mc_pll_init(pll, 0.0001, 100, 0.707, 200, 1) == 0, "PLL init")
    for direction in (-1, 1):
        api.mc_pll_init(pll, 0.0001, 100, 0.707, 200, 1)
        for k in range(10000):
            angle = math.remainder(direction * 30 * 0.0001 * k, 2 * math.pi)
            checks.check("pll_sim", api.mc_pll_update(pll, angle, True, 1) == 0, "PLL sample")
        checks.near("pll_sim", pll.speedRadS, direction * 30, "positive/negative wrap tracking", rel=5e-4)
        checks.near("pll_sim", math.remainder(pll.angleRad - direction * 30 * 0.0001 * 10000, 2 * math.pi),
                    0, "angle belongs to k+1", absolute=2e-5)
    snapshot = bytes(pll)
    checks.check("pll_fault", api.mc_pll_update(pll, 0, False, 1) == 6 and bytes(pll) == snapshot, "lost encoder frame")
    checks.check("pll_fault", api.mc_pll_init(pll, 0.1, 100, 0.707, 200, 1) == 8, "Jury unstable rejected")
    # 已发现的独立反例：double设计稳定，但最终float增益把极点推到单位圆外
    period = F(3.8134632632136345e-05).value
    bandwidth = F(16964.27734375).value
    damping = F(1.384039044380188).value
    stored_kp = F(2 * damping * bandwidth).value
    stored_ki = F(bandwidth * bandwidth).value
    trace = 2 - stored_kp * period - stored_ki * period * period
    determinant = 1 - stored_kp * period
    roots = [(trace + sign * cmath.sqrt(trace * trace - 4 * determinant)) / 2 for sign in (-1, 1)]
    checks.check("pll_quantization", max(abs(root) for root in roots) > 1,
                 "independent roots establish regression case instability after quantization")
    before = bytes(pll)
    checks.check("pll_quantization", api.mc_pll_init(pll, period, bandwidth, damping, 1e6, 1) == 8 and
                 bytes(pll) == before, "quantized unstable boundary rejected without state mutation")
    checks.check("pll_quantization", api.mc_pll_init(pll, period, bandwidth, damping * 0.999, 1e6, 1) == 0,
                 "neighboring stable quantized candidate remains available")


def test_existing_foc(api, checks):
    output = (F * 4)()
    for angle, speed, direction, sensor in ((0.3, 50, 1, 1), (0, 10, 1, 0),
                                           (0, 10, -1, 0), (3e30, 10, 1, 0), (-3e30, 10, 1, 0)):
        checks.check("foc_integration", api.bridge_foc(20000, 24, angle, speed, direction, sensor, output) == 1,
                     "existing FOC VF chain including very large finite angle terminates")
        checks.check("foc_integration", all(0 <= value <= 1 for value in output[:3]), "valid physical duty")
    for frequency, bus, angle, open_frequency in ((float("nan"), 24, 0, 10), (20000, float("inf"), 0, 10),
                                                (20000, 24, float("nan"), 10), (20000, 24, 0, float("inf"))):
        checks.check("foc_fault", api.bridge_foc(frequency, bus, angle, open_frequency, 1, 0, output) == 0,
                     "nonfinite angle/frequency/bus rejected before usable output")


def test_trajectory_frf(api, checks):
    for start, end in ((0, 10), (10, 0), (1, 1), (-3, 7)):
        request = TrajRequest(start, end, 0.001, 10, 40, 500)
        trajectory, point = Trajectory(), TrajectoryPoint()
        checks.check("trajectory", api.mc_traj_plan(request, trajectory) == 0, "trajectory plan")
        checks.check("trajectory", trajectory.samples >= 1, "integer finite schedule")
        previous = start
        for k in range(trajectory.samples + 3):
            checks.check("trajectory_sim", api.mc_traj_sample(trajectory, k, point) == 0, "PVAJ sample")
            checks.check("trajectory_sim", abs(point.speedRadS) <= 10 * (1 + 1e-12) and
                         abs(point.accelRadS2) <= 40 * (1 + 1e-12) and abs(point.jerkRadS3) <= 500 * (1 + 1e-12),
                         "analytical speed/acceleration/jerk bounds")
            checks.check("trajectory_sim", (end - start) * (point.positionRad - previous) >= -1e-10,
                         "forward/reverse monotonic")
            previous = point.positionRad
        checks.near("trajectory", point.positionRad, end, "exact final position", rel=1e-12)
        checks.check("trajectory", point.complete and point.speedRadS == 0 and point.accelRadS2 == 0,
                     "rest-to-rest end")
        # 独立Bernstein形式s=10u^3(1-u)^2+5u^4(1-u)+u^5
        k = trajectory.samples // 3
        api.mc_traj_sample(trajectory, k, point)
        u = k / trajectory.samples
        bernstein = 10 * u**3 * (1 - u)**2 + 5 * u**4 * (1 - u) + u**5
        checks.near("trajectory", point.positionRad, start + (end - start) * bernstein,
                    "independent Bernstein polynomial", rel=1e-12)
    checks.check("trajectory_fault", api.mc_traj_plan(TrajRequest(0, 1, 0, 1, 1, 1), trajectory) == 3,
                 "invalid period")
    count, frequency, period, lag, gain = 512, 156.25, 0.0001, 0.7, 0.35
    excitation = (F * count)(*(2 * math.sin(2 * math.pi * frequency * period * k) + 0.4 for k in range(count)))
    response = (F * count)(*(2 * gain * math.sin(2 * math.pi * frequency * period * k - lag) - 1.2
                            for k in range(count)))
    item = FrfInput(excitation, response, count, period, frequency, 0.1)
    actual = Frf()
    checks.check("frf", api.mc_frf(item, actual) == 0, "coherent single-tone DFT")
    checks.near("frf", actual.magnitude, gain, "gain", rel=1e-6)
    checks.near("frf", actual.phaseRad, -lag, "phase lag", rel=1e-6)
    checks.near("frf", actual.inputAmplitude, 2, "DC rejected by coherent bin", rel=1e-6)
    checks.check("frf", actual.cycles == 8, "exact full periods")
    item.frequencyHz = 160
    checks.check("frf_fault", api.mc_frf(item, actual) == 8, "leakage/noninteger record rejected")
    item.frequencyHz = frequency
    item.input = (F * count)()
    checks.check("frf_fault", api.mc_frf(item, actual) == 7, "insufficient excitation")
    item.input = excitation
    excitation[3] = float("nan")
    checks.check("frf_fault", api.mc_frf(item, actual) == 2, "nonfinite sample")


def test_control_chain(api, checks):
    # 独立PMSM ODE，PWM电压在alpha-beta内ZOH；Park坐标在每个区间内继续旋转
    def plant_step(current, command, speed, period, r, ld, lq, flux):
        def derivative(state, time_s):
            delta = speed * time_s
            vd = math.cos(delta) * command[0] + math.sin(delta) * command[1]
            vq = -math.sin(delta) * command[0] + math.cos(delta) * command[1]
            return ((vd - r * state[0] + speed * lq * state[1]) / ld,
                    (vq - r * state[1] - speed * (ld * state[0] + flux)) / lq)
        k1 = derivative(current, 0)
        middle1 = tuple(current[j] + period * k1[j] / 2 for j in (0, 1))
        k2 = derivative(middle1, period / 2)
        middle2 = tuple(current[j] + period * k2[j] / 2 for j in (0, 1))
        k3 = derivative(middle2, period / 2)
        end = tuple(current[j] + period * k3[j] for j in (0, 1))
        k4 = derivative(end, period)
        return tuple(current[j] + period / 6 * (k1[j] + 2 * k2[j] + 2 * k3[j] + k4[j]) for j in (0, 1))

    period = F(0.00005).value
    for direction, mismatch in ((1, 1.0), (-1, 1.0), (1, 1.2), (-1, 0.8)):
        motor = Motor(0.35 * mismatch, 0.0008 * mismatch, 0.001 * mismatch, 0.006 * mismatch, 7, 1)
        design_d, design_q = PiDesign(), PiDesign()
        api.mc_pi_design(motor.resistanceOhm, motor.ldH, period, 400, 0, design_d)
        api.mc_pi_design(motor.resistanceOhm, motor.lqH, period, 400, 0, design_q)
        pi_d, pi_q = Pi(design_d.kp, design_d.ki, 0), Pi(design_q.kp, design_q.ki, 0)
        current, angle, saturated_samples = (0.0, 0.0), 0.0, 0
        svpwm = Svpwm()
        api.foc_svpwm_init(svpwm)
        # 实际phase/Vbus归一化的线性区圆盘；不使用旧接口较宽的默认矢量上限
        svpwm.config.maxModulation = 1 / math.sqrt(3)
        for k in range(1200):
            speed = direction * (900 if 600 <= k < 800 else 600)
            bus = 8 if 600 <= k < 800 else 48
            limit = bus / math.sqrt(3) * 0.98
            ref_d = -0.5
            requested_q = direction * (2 if k < 200 or k >= 600 else (-2 if k < 400 else 10))
            ref_scale = min(1, 5 / math.hypot(ref_d, requested_q))
            ref_d, ref_q = ref_d * ref_scale, requested_q * ref_scale
            # 物理电流 -> 三相采样 -> 唯一正式Clarke/Park
            alpha = math.cos(angle) * current[0] - math.sin(angle) * current[1]
            beta = math.sin(angle) * current[0] + math.cos(angle) * current[1]
            phase = Phase(alpha, -0.5 * alpha + math.sqrt(3) / 2 * beta,
                          -0.5 * alpha - math.sqrt(3) / 2 * beta)
            sc = SinCos(math.sin(angle), math.cos(angle))
            measured = api.foc_park(api.foc_clarke(phase), sc)
            ff, step_d, step_q = Dq(), PiStep(), PiStep()
            checks.check("composition", api.mc_dq_ff(motor, measured, speed, ff) == 0, "composed dq feedforward")
            checks.check("composition", api.pid_pi_eval(pi_d, ref_d - measured.d, period, limit, step_d) == 0 and
                         api.pid_pi_eval(pi_q, ref_q - measured.q, period, limit, step_q) == 0, "shared PI candidates")
            requested = (step_d.output + ff.d, step_q.output + ff.q)
            scale = min(1, limit / max(1e-30, math.hypot(*requested)))
            applied = tuple(value * scale for value in requested)
            saturated_samples += scale < 0.99999
            checks.check("composition", math.hypot(*applied) <= limit * (1 + 1e-12), "one final voltage disk")
            for pi, step, actual, feedforward in ((pi_d, step_d, applied[0], ff.d), (pi_q, step_q, applied[1], ff.q)):
                actual_pi = max(-limit, min(limit, actual - feedforward))
                checks.check("composition", api.pid_pi_track(pi, step, actual_pi) == 0 and
                             abs(pi.integral) <= limit * (1 + 1e-6), "tracking after total saturation")
            ab = api.foc_inv_park(Dq(*applied), sc)
            svpwm.input.modulation = Ab(ab.alpha / bus, ab.beta / bus)
            checks.check("composition", api.foc_svpwm(svpwm) and svpwm.state.valid and
                         all(0 < value < 1 for value in (svpwm.state.dutyA, svpwm.state.dutyB, svpwm.state.dutyC)),
                         "existing SVPWM stays within sampling margin")
            # 从实际duty重建已执行电压；不是用未限幅命令喂回被控对象
            neutral = (svpwm.state.dutyA + svpwm.state.dutyB + svpwm.state.dutyC) / 3
            actual_alpha = (svpwm.state.dutyA - neutral) * bus
            actual_beta = (svpwm.state.dutyB - svpwm.state.dutyC) * bus / math.sqrt(3)
            actual_dq = (math.cos(angle) * actual_alpha + math.sin(angle) * actual_beta,
                         math.cos(angle) * actual_beta - math.sin(angle) * actual_alpha)
            current = plant_step(current, actual_dq, speed, period, 0.35, 0.0008, 0.001, 0.006)
            angle = math.remainder(angle + speed * period, 2 * math.pi)
            checks.check("composition", all(math.isfinite(value) and abs(value) < 50 for value in current),
                         "bounded response during reversal/bus drop/parameter mismatch")
        checks.check("composition_acceptance", saturated_samples > 0, "bus drop exercises saturation")
        checks.near("composition_acceptance", current[0], -0.5, "recovers d tracking", absolute=0.003)
        checks.near("composition_acceptance", current[1], direction * 2, "recovers q tracking", absolute=0.003)


def test_shunts(api, checks):
    phase_out, result = Phase(), Reconstructed()
    # 单/双/三电阻共享物理相电流真值；dc样本从开关导通关系独立合成
    for a, b in ((0, 0), (2, -0.5), (-2, 0.5), (20, -10), (0.01, 0.02)):
        actual = (a, b, -a - b)
        for mask in (3, 5, 6, 7):
            measured = [actual[k] if (mask & (1 << k)) else float("nan") for k in range(3)]
            item = PhaseSample(Phase(*measured), mask, 1e-5, 1, 1.00001, 0.0001)
            checks.check("phase_shunt", api.mc_phase_current(item, phase_out) == 0, "two/three valid phases")
            for value, expected in zip((phase_out.a, phase_out.b, phase_out.c), actual):
                checks.near("phase_shunt", value, expected, "phase reconstruction")
        limits = ShuntLimits(1.00002, 0.000001, 0.0001, 0.00005, 1000, 0.1, True)
        for first_vector in range(1, 7):
            first_dc = sum(actual[k] for k in range(3) if first_vector & (1 << k))
            first = BusSample(first_dc, first_vector, 1, 0.000002, True)
            for second_vector in range(1, 7):
                second_dc = sum(actual[k] for k in range(3) if second_vector & (1 << k))
                second = BusSample(second_dc, second_vector, 1.00001, 0.000002, True)
                status = api.mc_bus_current(first, second, limits, result)
                dependent = first_vector == second_vector or (first_vector ^ second_vector) == 7
                checks.check("single_shunt", status == (7 if dependent else 0), "independent active-vector rank")
                if not dependent:
                    for value, expected in zip((result.currentA.a, result.currentA.b, result.currentA.c), actual):
                        checks.near("single_shunt", value, expected, "independent DC-link reconstruction")
                    checks.near("single_shunt", result.errorBoundA, 0.03, "conservative age/slope error bound", rel=1e-5)
    # 三相分别采到的异常不能用零和强行掩盖；两有效相只重构而不宣称检测第三相故障
    item = PhaseSample(Phase(2, -0.5, -1.0), 7, 0.1, 1, 1.00001, 0.0001)
    checks.check("phase_shunt_fault", api.mc_phase_current(item, phase_out) == 8, "three-phase zero-sum residual")
    item.validMask = 1
    checks.check("phase_shunt_fault", api.mc_phase_current(item, phase_out) == 7, "too few valid phases")
    item.validMask, item.sampleTimeS = 3, 0
    checks.check("phase_shunt_fault", api.mc_phase_current(item, phase_out) == 4, "stale phase sample")
    limits = ShuntLimits(1.00002, 0.000001, 0.0001, 0.00005, 1000, 0.1, True)
    first = BusSample(2, 1, 1, 0.000002, True)
    second = BusSample(-0.5, 2, 1.00001, 0.000002, True)
    for field, value, expected in (("valid", False, 6), ("switchState", 0, 3), ("switchState", 7, 3),
                                   ("validWindowS", 0.0000001, 8), ("sampleTimeS", 0.9, 4),
                                   ("busCurrentA", float("nan"), 2)):
        modified = BusSample.from_buffer_copy(first)
        setattr(modified, field, value)
        sentinel = Reconstructed(Phase(99, 88, 77), 66)
        checks.check("single_shunt_fault", api.mc_bus_current(modified, second, limits, sentinel) == expected and
                     sentinel.currentA.a == 99 and sentinel.errorBoundA == 66, f"{field} fails without partial output")
    limits.maxErrorA = 0.001
    checks.check("single_shunt_fault", api.mc_bus_current(first, second, limits, result) == 8,
                 "non-simultaneous current slope bound exceeded")
    limits.slopeBoundValid = False
    checks.check("single_shunt_fault", api.mc_bus_current(first, second, limits, result) == 7,
                 "missing slope evidence cannot assume constant current")


def test_contracts(api, checks):
    motor = Motor(0.2, 0.0003, 0.0005, 0.015, 7, 1)
    scalar = F(123)
    calls = (
        lambda: api.mc_dq_ff(motor, Dq(), 0, None),
        lambda: api.mc_pi_design(1, 1, 0.001, 1, 0, None),
        lambda: api.mc_pi_cfg(None, 1, 1, 0, 1),
        lambda: api.mc_align_angle(None, scalar),
        lambda: api.mc_rl_init(None, RlConfig()),
        lambda: api.mc_rl_add(None, RlSample()),
        lambda: api.mc_rl_fit(None, RlResult()),
        lambda: api.mc_mtpa(motor, Mtpa(1, 1, 1), None),
        lambda: api.mc_torque(motor, Dq(), None),
        lambda: api.mc_check_limits(motor, Dq(), 0, 1, 1, None),
        lambda: api.mc_deadtime(None, Phase(), Phase()),
        lambda: api.mc_friction(None, 0, scalar),
        lambda: api.mc_mech_ff(None, scalar),
        lambda: api.mc_dob_init(None, DobConfig()),
        lambda: api.mc_dob_update(None, 0, 0, True, 1, scalar),
        lambda: api.mc_notch(1, 0.1, 0.5, 0.001, None),
        lambda: api.mc_filter(None, Biquad(), 0, scalar),
        lambda: api.mc_pll_init(None, 0.001, 10, 0.7, 100, 1),
        lambda: api.mc_pll_update(None, 0, True, 1),
        lambda: api.mc_dual_error(0, 0, 1, 1, None),
        lambda: api.mc_schedule(0, 1, 0, None),
        lambda: api.mc_ripple(0, None, 2, scalar),
        lambda: api.mc_traj_plan(None, Trajectory()),
        lambda: api.mc_traj_sample(None, 0, TrajectoryPoint()),
        lambda: api.mc_frf(None, Frf()),
        lambda: api.mc_phase_current(None, Phase()),
        lambda: api.mc_bus_current(None, BusSample(), ShuntLimits(), Reconstructed()),
    )
    for index, call in enumerate(calls):
        checks.check("null_contract", call() == 1 and scalar.value == 123, f"API {index+1} rejects null")
    # 多实例无共享状态，初始化可用本实例配置安全复位
    first, second = Dob(), Dob()
    config = DobConfig(0.001, 0.002, 100, 2, 1)
    api.mc_dob_init(first, config)
    api.mc_dob_init(second, config)
    snapshot = bytes(second)
    api.mc_dob_update(first, 1, 0, True, 1, scalar)
    api.mc_dob_update(first, 1, 0, True, 1, scalar)
    checks.check("instance_contract", bytes(second) == snapshot, "axis states independent")
    checks.check("instance_contract", api.mc_dob_init(first, first.config) == 0 and not first.primed and
                 first.config.version == 1, "reset preserves aliased config")


def run_configuration(module, output, compiler, optimization):
    controller = module.parent
    bridge = output / "bridge.c"
    bridge.write_text(BRIDGE, encoding="ascii")
    library = output / ("motor_" + optimization[1:] + (".dll" if os.name == "nt" else ".so"))
    sources = [module / "motor.c", controller / "foc/src/foc_math.c", controller / "foc/src/foc_svpwm.c",
               controller / "foc/src/foc.c", controller / "pid/src/pid_pi.c", controller / "pid/src/pid.c", bridge]
    command = [compiler, "-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic", optimization, "-shared"]
    if os.name != "nt":
        command.append("-fPIC")
    command += ["-I", str(module), "-I", str(controller / "foc/src"), "-I", str(controller / "pid/src")]
    command += [*(str(path) for path in sources), "-lm", "-o", str(library)]
    environment = os.environ.copy()
    environment["PATH"] = str(Path(compiler).resolve().parent) + os.pathsep + environment.get("PATH", "")
    build = subprocess.run(command, text=True, capture_output=True, env=environment, timeout=120)
    (output / f"build_{optimization[1:]}.log").write_text(build.stdout + build.stderr, encoding="utf-8")
    if build.returncode:
        raise RuntimeError(build.stderr)
    api = load_api(library)
    checks = Checks()
    for test in (test_dq, test_pi, test_rl, test_feedback, test_allocation, test_compensation,
                 test_observers_filters, test_existing_foc, test_trajectory_frf, test_control_chain, test_shunts,
                 test_contracts):
        test(api, checks)
    # 包含ctypes跨语言调用开销；只能作宿主回归基准，不能作为ISR/WCET证据
    motor, out = Motor(0.2, 0.0003, 0.0005, 0.015, 7, 1), Dq()
    start = time.perf_counter_ns()
    for _ in range(10000):
        api.mc_dq_ff(motor, Dq(-2, 5), 3000, out)
    elapsed = time.perf_counter_ns() - start
    provenance = [path for path in sources if path != bridge]
    provenance += [module / "motor.h", module / "run_tests.py", controller / "foc/src/foc_math.h",
                   controller / "foc/src/foc_svpwm.h", controller / "foc/src/foc.h", controller / "pid/src/pid_pi.h",
                   controller / "pid/src/pid.h"]
    compiler_version = subprocess.run([compiler, "--version"], text=True, capture_output=True,
                                      env=environment, timeout=30).stdout.splitlines()[0]
    report = {"optimization": optimization, "compiler": compiler_version,
            "checks": sum(checks.counts.values()), "groups": checks.counts,
            "failures": checks.failures, "passed": not checks.failures,
            "host_benchmark": {"operation": "mc_dq_ff+ctypes", "iterations": 10000,
                               "mean_ns": elapsed / 10000, "target_wcet": "NOT_MEASURED"},
            "sources_sha256": {path.relative_to(controller).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in provenance}}
    # CDLL本身不拥有自动卸载语义，先结束全部调用再释放，默认临时目录才能在Windows清理
    import _ctypes
    if os.name == "nt":
        _ctypes.FreeLibrary(api._handle)
    else:
        _ctypes.dlclose(api._handle)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", help="GCC-compatible host compiler (default: gcc on PATH)")
    parser.add_argument("--output", type=Path, help="Persist build/log/JSON outside source module; default: temporary")
    args = parser.parse_args()
    module = Path(__file__).resolve().parent
    compiler = args.cc or shutil.which("gcc")
    if not compiler:
        parser.error("GCC unavailable; pass --cc")
    temporary = None
    if args.output:
        output = args.output.resolve()
        if output == module or module in output.parents:
            parser.error("--output must be outside motor source module")
        output.mkdir(parents=True, exist_ok=True)
    else:
        temporary = tempfile.TemporaryDirectory(prefix="motor-primitives-")
        output = Path(temporary.name)
    try:
        configurations = [run_configuration(module, output, compiler, option) for option in ("-O0", "-O2")]
        summary = {"evidence": ["Mathematical Reference", "Host Unit Test", "Discrete Simulation"],
                   "target_build": "NOT_MEASURED", "hardware_measurement": "NOT_MEASURED",
                   "passed": all(item["passed"] for item in configurations), "configurations": configurations}
        (output / "results.json").write_text(json.dumps(summary, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        print(json.dumps(summary, allow_nan=False))
        return 0 if summary["passed"] else 1
    finally:
        if temporary:
            # Windows加载的DLL须先释放；进程退出后系统会释放文件，但默认临时清理由子进程隔离处理
            if os.name == "nt":
                import gc
                gc.collect()
            temporary.cleanup()


if __name__ == "__main__":
    raise SystemExit(main())
