"""回归执行失败、A/B不一致与正常结果的汇总语义；无设备操作。"""
from contextlib import redirect_stderr, redirect_stdout
import argparse
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

sys.dont_write_bytecode = True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work-dir', required=True, type=Path)
    args = parser.parse_args()
    example = Path(__file__).resolve().parent
    work = args.work_dir.resolve()
    if work == example or example in work.parents:
        raise ValueError('work-dir必须位于示例源码之外')
    work.mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location('servo_runner', example / 'run_validation.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    cases = []
    for exit_code, mismatch, expected in ((7, False, False), (0, True, False), (0, False, True)):
        with tempfile.TemporaryDirectory(dir=work) as directory:
            output = Path(directory)

            def fake_run(command, **kwargs):
                if '-std=c99' in command:
                    return subprocess.CompletedProcess(command, 0, '', '')
                with Path(command[1]).open('w', encoding='utf-8', newline='') as stream:
                    stream.write('scenario,time_s,p_ref_rad,v_ref_rad_s,a_ref_rad_s2\n')
                    for scenario in ('motion_baseline', 'motion_ff'):
                        for index in range(6000):
                            position = 1 if mismatch and scenario == 'motion_ff' and index == 7 else 0
                            stream.write(f'{scenario},{index/1000},{position},0,0\n')
                return subprocess.CompletedProcess(command, exit_code,
                    json.dumps({'passed': True, 'failed': 0, 'checks': []}), '')

            with patch.object(sys, 'argv', [str(example / 'run_validation.py'), '--cc', 'gcc', '--output', str(output)]), \
                    patch.object(module.subprocess, 'run', side_effect=fake_run), \
                    redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                status = module.main()
            result = json.loads((output / 'summary.json').read_text(encoding='utf-8'))
            assert result['passed'] is expected
            assert (status == 0) is expected
            cases.append({'binary_exit_code': exit_code, 'reference_mismatch': mismatch,
                          'reported_pass': result['passed'], 'runner_exit_code': status})
    print(json.dumps({'passed': len(cases), 'failed': 0, 'cases': cases}, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
