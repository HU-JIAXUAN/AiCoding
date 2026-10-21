# 编码说明

S2 按实际字节核对，本模块原有 C 源码为 UTF-8（src 文件为 CRLF），示例为 ASCII 子集；本次保留原文件编码与行尾：

- `src/*.c`：UTF-8
- `src/*.h`：UTF-8
- `examples/*.c`：ASCII 子集，原文件不改写
- `../tests/*.c`：UTF-8，共享宿主测试

相邻 PID 的 src/examples 保持其原有 GBK，PID 测试 C 文件为 UTF-8。现有检查器接受 UTF-8 或 GBK 并检查作者，不执行编码转换；不能仅凭检查器文件名断言源码是 GBK。使用工具链若要求统一编码，应另行处理，不能在算法变更中混入隐式转换。

非 C 文件使用 UTF-8：

- `README.md`
- `docs/*.md`
- `tests/*.py`
- `tools/*.py`
- `simulink/*.m`

检查命令：

```bash
python tools/check_c_gbk.py
```
