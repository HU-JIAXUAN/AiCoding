# Latest Validation

2026-11-10：本地测试分层瘦身后的实际执行结果。原始 `test-results/` 不提交到仓库。

## Commands

```powershell
bin/aicoding.exe test
bin/aicoding.exe test --profile Full
bin/aicoding.exe test --profile Release
```

`test` 默认 Smoke；本次实跑 Smoke 与 Full，使用 `--json` 和独立 `--out` 保存报告。
Release 的完整发布动作本轮未运行。

## Summary

| Profile | Conclusion | 执行通过 | FAIL | WARN | 档位未选择 | CLI 墙钟 |
|---|---|---:|---:|---:|---:|---:|
| Smoke | PASS | 48 | 0 | 0 | 25 | 7.697 秒 |
| Full | PASS | 65 | 0 | 0 | 8 | 173.218 秒 |

## Notes

- 本次为 dirty 开发树真实执行，cache hit ratio 为 0；未签发或复用 Receipt。
- Full 包含全仓 Go 单测、Staticcheck、CLI/JSON、C Kit 与电机 host 验证。Release 另含 race、vet、漏洞和既有发布验证；不要求先重复执行一次 Full。
- 目录治理允许 `.agentpatch` 本地事务状态，禁止将其暂存，未知根目录仍会报错。
- 默认入口、开发脏树/Release 边界、profile 覆盖与 Receipt 节点回归通过。远端 CI 未在本轮运行；既有日常 job 改为执行一次 Full。
- `doctor perf` 和 `doctor --all` 的本机环境诊断按需执行，不混入测试 profile 的源码验收。
- 当前分工见 [ADR 0015](../../decisions/0015-lean-test-profiles.md)，性能上下文见 [Full 性能基线](../FULL_PERFORMANCE_BASELINE.md)。历史发布证据见 [TODO 0041](../../todolist/done/0041-release-only-publication.md)。
- 本地报告：`test-results/lean-tests-20261110/smoke-final/`、`test-results/lean-tests-20261110/full/`；Go 包事件基线在 `test-results/full-performance-investigation-20261110/`。
