"""Compile and execute synthetic C99 servo cases without touching firmware or models."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Build and evidence directory")
    parser.add_argument("--cc", default=None, help="GCC executable; otherwise discover gcc on PATH")
    args = parser.parse_args()
    example = Path(__file__).resolve().parent
    kit = example.parents[1]
    source = example / "servo_validation.c"
    raw = source.read_bytes()
    if raw.startswith((b"\xef\xbb\xbf", b"\xff\xfe")) or b"\r" in raw:
        raise ValueError("new C source must be CP936, no BOM, LF")
    if raw.decode("cp936").encode("cp936") != raw:
        raise ValueError("C source CP936 roundtrip failed")
    output = args.output.resolve()
    if output == example or example in output.parents:
        raise ValueError("--output must be outside the example source directory")
    output.mkdir(parents=True, exist_ok=True)
    compiler = args.cc or shutil.which("gcc")
    if not compiler:
        raise RuntimeError("GCC not found; pass --cc with its executable path")
    controller = kit / "modules" / "common" / "controller"
    sources = [source, controller / "pid/src/pid_pi.c", controller / "foc/src/foc_math.c",
               controller / "foc/src/foc_svpwm.c"]
    include = [controller / "pid/src", controller / "foc/src"]
    environment = os.environ.copy()
    environment["PATH"] = str(Path(compiler).resolve().parent) + os.pathsep + environment.get("PATH", "")
    results = []
    for label, optimization in (("debug", "-O0"), ("release", "-O2")):
        binary = output / (f"servo_validation_{label}" + (".exe" if os.name == "nt" else ""))
        trace = output / f"trace_{label}.csv"
        command = [compiler, "-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic", optimization]
        for directory in include:
            command.extend(["-I", str(directory)])
        command.extend([*(str(path) for path in sources), "-lm", "-o", str(binary)])
        build = subprocess.run(command, text=True, capture_output=True, env=environment, timeout=120)
        (output / f"build_{label}.log").write_text(build.stdout + build.stderr, encoding="utf-8")
        if build.returncode:
            sys.stderr.write(build.stderr)
            return build.returncode
        execution = subprocess.run([str(binary), str(trace)], text=True, capture_output=True,
                                   env=environment, timeout=120)
        (output / f"execution_{label}.log").write_text(execution.stderr, encoding="utf-8")
        result = json.loads(execution.stdout)
        with trace.open(newline="", encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        reference_columns = ("time_s", "p_ref_rad", "v_ref_rad_s", "a_ref_rad_s2")
        baseline = [tuple(row[key] for key in reference_columns) for row in rows
                    if row["scenario"] == "motion_baseline"]
        feedforward = [tuple(row[key] for key in reference_columns) for row in rows
                       if row["scenario"] == "motion_ff"]
        paired = len(baseline) == 6000 and baseline == feedforward
        result["checks"].append({"name": "motion.identical_AB_reference_trace", "observed": int(paired),
                                 "threshold": 1, "comparison": ">=", "passed": paired})
        if not paired:
            result["failed"] += 1
            result["passed"] = False
        result["configuration"] = label
        result["exit_code"] = execution.returncode
        process_ok = execution.returncode == 0
        result["checks"].append({"name": "process.successful_exit", "observed": execution.returncode,
                                 "threshold": 0, "comparison": "==", "passed": process_ok})
        if not process_ok:
            result["failed"] += 1
        result["passed"] = (bool(result["passed"]) and result["failed"] == 0
                            and all(check["passed"] for check in result["checks"]))
        result["sources_sha256"] = {path.relative_to(kit).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                                    for path in sources}
        (output / f"results_{label}.json").write_text(
            json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")
        results.append(result)
        if execution.returncode or not result["passed"]:
            sys.stderr.write(execution.stderr)
    summary = {"evidence": "synthetic-host-c99",
               "passed": all(item["passed"] and item["exit_code"] == 0 for item in results),
               "configurations": [{"name": item["configuration"], "checks": len(item["checks"]),
                                   "failed": item["failed"]} for item in results]}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
