"""Build only the C99 signal generator, its numerical checks and its small example."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", default=None, help="GCC executable; otherwise discover gcc on PATH")
    parser.add_argument("--output", type=Path, required=True, help="Build and report directory outside this module")
    args = parser.parse_args()
    module = Path(__file__).resolve().parent
    output = args.output.resolve()
    if output == module or module in output.parents:
        raise ValueError("--output must be outside the source module")
    output.mkdir(parents=True, exist_ok=True)
    compiler = args.cc or shutil.which("gcc")
    if not compiler:
        raise RuntimeError("GCC unavailable; pass --cc")
    environment = os.environ.copy()
    environment["PATH"] = str(Path(compiler).resolve().parent) + os.pathsep + environment.get("PATH", "")
    files = [module / "signal_gen.c", module / "signal_gen.h", module / "tests/test_signal_gen.c",
             module / "examples/minimal_example.c"]
    for file in files:
        raw = file.read_bytes()
        if raw.decode("cp936").encode("cp936") != raw or raw.startswith(b"\xef\xbb\xbf") or b"\r" in raw:
            raise ValueError(f"CP936/no BOM/LF source check failed: {file.name}")
    hashes = {file.relative_to(module).as_posix(): hashlib.sha256(file.read_bytes()).hexdigest() for file in files}
    configurations = []
    for real_type, label, optimization in (("float", "float_O0", "-O0"), ("float", "float_O2", "-O2"),
                                           ("double", "double_O0", "-O0"), ("double", "double_O2", "-O2")):
        definitions = [] if real_type == "float" else ["-DSIGNAL_GEN_REAL_TYPE=double"]
        executable = output / (f"signal_gen_{label}" + (".exe" if os.name == "nt" else ""))
        command = [compiler, "-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic", optimization,
                   *definitions,
                   "-I", str(module), str(module / "signal_gen.c"), str(module / "tests/test_signal_gen.c"),
                   "-lm", "-o", str(executable)]
        build = subprocess.run(command, capture_output=True, text=True, env=environment, timeout=60)
        (output / f"build_{label}.log").write_text(build.stdout + build.stderr, encoding="utf-8")
        if build.returncode:
            sys.stderr.write(build.stderr)
            return build.returncode
        execution = subprocess.run([str(executable)], capture_output=True, text=True,
                                   env=environment, timeout=60)
        (output / f"execution_{label}.log").write_text(execution.stderr, encoding="utf-8")
        result = json.loads(execution.stdout)
        result["configuration"] = label
        result["real_type"] = real_type
        result["exit_code"] = execution.returncode
        result["sources_sha256"] = hashes
        (output / f"results_{label}.json").write_text(
            json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        configurations.append(result)
        if execution.returncode:
            sys.stderr.write(execution.stderr)
    examples_passed = True
    for real_type in ("float", "double"):
        definitions = [] if real_type == "float" else ["-DSIGNAL_GEN_REAL_TYPE=double"]
        example = output / (f"signal_gen_example_{real_type}" + (".exe" if os.name == "nt" else ""))
        command = [compiler, "-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O2", *definitions,
                   "-I", str(module), str(module / "signal_gen.c"), str(module / "examples/minimal_example.c"),
                   "-lm", "-o", str(example)]
        build = subprocess.run(command, capture_output=True, text=True, env=environment, timeout=60)
        (output / f"build_example_{real_type}.log").write_text(build.stdout + build.stderr, encoding="utf-8")
        if build.returncode:
            sys.stderr.write(build.stderr)
            return build.returncode
        execution = subprocess.run([str(example)], capture_output=True, text=True, env=environment, timeout=60)
        (output / f"example_{real_type}.csv").write_text(execution.stdout, encoding="utf-8")
        examples_passed = examples_passed and execution.returncode == 0
    passed = examples_passed and all(item["passed"] and item["exit_code"] == 0 for item in configurations)
    summary = {"evidence": "signal-generator-host-c99", "passed": passed,
               "configurations": [{"name": item["configuration"], "checks": item["checks"],
                                   "failed": item["failed"]} for item in configurations]}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
