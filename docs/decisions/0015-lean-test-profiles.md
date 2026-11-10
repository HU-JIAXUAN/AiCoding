# ADR 0015: 测试分层瘦身与日常默认入口

PrimitiveReview: n/a

## Status

Accepted。2026-11-10 用户要求精简过度保护和繁琐的测试体系。本次调整现有 profile 的执行分工，复用唯一 testengine，不新增 profile、配置面、缓存或调度器。

## 1. Context

当前 Full 实测 651.021 秒：GO-001 为 318.299 秒，GO-002 为 235.579 秒，合计约 85%。Go 输出显示这两轮的慢包测试分别约 32 秒和 36 秒，其余还包含包发现、构建、缓存及进程成本。独立 `go test -json ./...` 基线为 102.652 秒，说明机器状态和测试缓存会显著影响墙钟，不能把单次差值直接称为算法收益。

Smoke 原本也执行全仓单测、C Kit 编译和多命令性能采样。Full 又执行普通与 race 两轮、独立 vet、漏洞扫描及重复 DocSync。`doctor perf` 还会因本机 Visio/PPT MCP 归属状态阻断源码测试。开发脏树需要额外开关，但即使通过也不能复用 Receipt。这些成本和使用门槛不适合日常迭代。

## 2. Decision

| 入口 | 责任 |
|---|---|
| `test` / Smoke | 默认快速本地验证；不执行全仓 Go 单测、C Kit 编译、race 或漏洞扫描。 |
| Full | 一次全仓 Go 单测、Staticcheck、CLI 并发与领域验证。 |
| Release | Full 覆盖，加登记并发包 race、独立 vet、漏洞扫描和既有发布验证。 |

每档只运行一次 DocSync：Smoke 使用 `ci`，Full/Release 使用覆盖全仓和发布要求的 `release` 模式。移除重复 DOC-002；DOC-003 归入现有 DocSync 节点。性能探针 HEALTH-001 从自动 registry 移除，`doctor perf` 继续按需诊断。

PR/push CI 执行一次 Full，保留既有 `smoke` job ID。手动/周期性发布流程继续执行 Release，不先叠加 Full；其显式 `--reuse off` seed 和 `--verify-reuse` audit 保持原有规则。

Smoke/Full 默认接受脏开发树；脏结果仍不能查询或签发可复用 Receipt。Release 默认拒绝脏树，显式 `--allow-dirty` 继续只提供不可复用诊断。exact-tree、Receipt 完整性、发布别名和 pre-push 规则保持原有语义。

`.agentpatch` 登记为可存在的本地事务状态，并列入禁止暂存的生成目录。未知根目录继续报错。

## 3. Coverage And Compatibility

不删除业务单测、断言或领域行为用例。日常 Full 不再提供 race 和漏洞扫描结果；这些信号集中到 Release 或显式诊断。Release 保留原工具版本、raceScope、severity 和网络故障分类。

三档的副作用边界、报告 schema、退出码和唯一命令目录不变。旧 Receipt 因 registry/catalog/options 摘要变化而失效，不迁移或手工修改证据。此决定向前替代 ADR 0013 及当前运维文档中“Full 也执行 race/vet/漏洞”的要求；历史实测保持原文。

## 4. Validation And Rollback

回归验证默认 Smoke、脏树开发入口与 Release 边界、各档唯一 DocSync、Release 重检查覆盖，以及事务目录允许存在但不能提交。真跑 Smoke 和 Full，保留逐项报告与墙钟；Release 的发布桌面动作不因本次本地验证而自动启动。

回滚只需恢复本次 CLI 默认值、registry profile 映射和对应当前文档。Receipt 格式与数据无需迁移。

## §12 Checklist 自评

不适用：只调整现有 CLI、testengine registry 和目录数据，没有新增 Primitive、状态权威或第二套执行路径。
