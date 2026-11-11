"""Reproduce the scalar PI comparison without modifying the library."""
from pathlib import Path
from math import exp, isfinite, sqrt
import csv
import json

OUT = Path.cwd()
CASES = {
    "positive_release": (2.0, 0.4, -1.0, 1.0),
    "negative_release": (-2.0, -0.4, -1.0, 1.0),
    "asymmetric_reversal": (2.0, -0.3, -0.7, 1.0),
    "no_saturation": (0.2, 0.4, -1.0, 1.0),
}
KP, KI, KAW, TAU = 1.2, 8.0, 20.0, 0.08


def simulate(mode, initial, final, lower, upper, ts=0.001):
    decay = exp(-ts / TAU)
    y, xi = 0.0, 0.0
    trace = []
    for k in range(round(2.0 / ts) + 1):
        time = k * ts
        ref = initial if time < 0.5 else final
        error = ref - y
        request = KP * error + xi
        command = min(upper, max(lower, request))
        residual = command - request
        trace.append((time, ref, y, xi, request, command, error))
        if mode == "library":
            xi += ts * (KI * error + KAW * residual)
        elif mode == "demo_matched":
            xi += ts * KI * (error + KAW / KI * residual)
        elif mode == "demo_gain20_project_pi":
            xi += ts * KI * (error + 20 * residual)
        elif mode == "demo_effective_28000":
            xi += ts * (KI * error + 28000 * residual)
        elif mode == "no_antiwindup":
            xi += ts * KI * error
        else:
            raise ValueError(mode)
        if not isfinite(xi) or abs(xi) > 1e6:
            return trace, False
        y = decay * y + (1.0 - decay) * command
    return trace, True


def metrics(trace, valid, ts=0.001):
    if not valid:
        return {"converged_to_end": False, "last_time_s": trace[-1][0], "last_xi": trace[-1][3]}
    tail = [r for r in trace if r[0] >= 0.5]
    out_of_band = [r[0] for r in tail if abs(r[6]) > 0.02]
    return {
        "converged_to_end": True,
        "tail_iae": sum(abs(r[6]) for r in tail) * ts,
        "tail_rms": sqrt(sum(r[6] ** 2 for r in tail) / len(tail)),
        "settled_0p02_after_release_s": (
            max(0.0, out_of_band[-1] + ts - 0.5) if out_of_band else 0.0
        ) if not out_of_band or out_of_band[-1] < tail[-1][0] else None,
        "tail_saturated_s": sum(r[4] != r[5] for r in tail) * ts,
        "peak_abs_integral": max(abs(r[3]) for r in trace),
    }


def main():
    result = {
        "fixture": {"Kp": KP, "Ki": KI, "Kaw": KAW, "tau_s": TAU, "Ts_s": 0.001, "Kd": 0},
        "release_s": 0.5,
        "cases": {},
        "matched_tolerance": 5e-13,
    }
    csv_rows = []
    for name, scenario in CASES.items():
        detail = {}
        traces = {}
        for mode in ("library", "demo_matched", "demo_gain20_project_pi", "demo_effective_28000", "no_antiwindup"):
            traces[mode], ok = simulate(mode, *scenario)
            detail[mode] = metrics(traces[mode], ok)
            if name == "positive_release":
                csv_rows.extend((mode, *row) for row in traces[mode][::10])
        reference, matched = traces["library"], traces["demo_matched"]
        assert len(reference) == len(matched)
        delta = max(abs(x - y) for a, b in zip(reference, matched) for x, y in zip(a, b))
        assert delta <= result["matched_tolerance"], (name, delta)
        detail["matched_max_abs_difference"] = delta
        result["cases"][name] = detail
    result["fixed_saturation_euler_pole"] = {
        str(ts): 1 - ts * 28000 for ts in (25e-6, 50e-6, 62.5e-6, 1e-3)
    }
    with (OUT / "antiwindup_comparison.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("mode", "time_s", "reference", "plant_output", "integral", "requested", "limited", "error"))
        writer.writerows(csv_rows)
    (OUT / "antiwindup_comparison.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
