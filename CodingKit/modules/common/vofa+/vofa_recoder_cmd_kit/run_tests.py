"""Compile the complete C99 kit; keep every build product in an OS temporary directory."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
CORE = ("vofa.c", "vofa.h", "recorder.c", "recorder.h", "command.c", "command.h")


def run(compiler: str) -> None:
    flags = [compiler, "-std=c99", "-pedantic-errors", "-Wall", "-Wextra", "-Werror",
             "-O3", "-fstrict-aliasing", "-Wstrict-aliasing=2"]
    with tempfile.TemporaryDirectory(prefix="vofa_recorder_cmd_") as folder:
        temporary = Path(folder)
        for endian, test in [(0, "test_kit.c"), (1, "test_endian.c")]:
            work = temporary / str(endian)
            work.mkdir()
            for name in CORE:
                shutil.copyfile(ROOT / name, work / name)
            if endian:
                header = work / "vofa.h"
                source = header.read_text(encoding="utf-8")
                assert source.count("#define VOFA_BIG_ENDIAN (0u)") == 1
                header.write_text(source.replace("#define VOFA_BIG_ENDIAN (0u)",
                                                 "#define VOFA_BIG_ENDIAN (1u)"), encoding="utf-8")
            objects = []
            sources = [work / name for name in ("vofa.c", "recorder.c", "command.c")]
            sources += [ROOT / "examples/example_business.c", ROOT / "tests" / test]
            for index, source in enumerate(sources):
                output = work / f"unit{index}.o"
                subprocess.run(flags + ["-I", str(work), "-I", str(ROOT / "examples"),
                                         "-c", str(source), "-o", str(output)], check=True)
                objects.append(str(output))
            executable = work / "kit_test.exe"
            subprocess.run([compiler, *objects, "-lm", "-o", str(executable)], check=True)
            subprocess.run([str(executable)], check=True, timeout=10)
    print("PASS: complete little/big-endian C99 kit; temporary products removed")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", default=os.environ.get("CC") or shutil.which("gcc"),
                        help="GNU/Clang-compatible C compiler executable")
    options = parser.parse_args()
    if not options.cc:
        parser.error("provide --cc or put gcc on PATH")
    run(options.cc)


if __name__ == "__main__":
    main()
