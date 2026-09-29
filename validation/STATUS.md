# 验收状态 / Validation status

Version: 0.1.1. The source remains a candidate until its own CI run is verified.
源码仍按候选版处理，直到核对本提交对应的实际运行结果。

Repository: https://github.com/lianglunping/evanxlsx (private / 私有)
Workflow results: https://github.com/lianglunping/evanxlsx/actions

## Historical failure / 历史失败

The first 0.1.0 source upload was commit
b389cdd8a35786ff53beb91a9b709365b9611321, run 36541029450.
Linux/macOS examples and tests failed in the XML-validation regular expression;
Windows build failed while copying an open build log. These are not passing results.
0.1.0 首轮检查失败，不能作为已经验收的安装包使用。

0.1.1 fixes these issues and expands the runtime/installation test matrix.
The public function and defaults are preserved. CI success must be read from
actual logs; the existence of test code is not a passing result.

## Test scope / 验收范围

Six requested environments: Linux release, Windows release, macOS arm64 release,
macOS Intel release, Linux oldrel-1, Linux R 4.1.3. Three installation routes per
environment: source folder, local source archive, private GitHub at the exact SHA.
目标为六个环境、每个环境三种安装方式；未完成或失败的组合不得计为通过。

Each installed copy is loaded in a fresh process from a separately verified
library path. Synthetic inputs contain 240 rows × 11 columns and 83 test categories.
A 10,000-row × 6-column case and 12 font/alignment cases supplement the unit tests.
每个安装副本在独立包库、新 R 进程中加载；所有数据均为合成数据。

Reproduction / 复现:

```sh
Rscript tools/check.R
Rscript tools/install_check.R
```

Outputs use new validation/local-* and validation/portable-* directories.
CSV/RDS, workbooks, logs, actual versions and assertions are retained as artifacts.
Static-audit files describe a pre-commit snapshot and cannot establish runtime
correctness, installation success or current remote CI status.
静态检查与哈希不是运行测试；最终结论需要实际日志支持。

## Limits / 边界

Private GitHub installation requires authorization. Local tar installation
requires R and dependencies; dependencies are not bundled for fully offline setup.
No raw research data, credentials, screenshots or font files are uploaded.
Font names are checked in XML; no claim of native Excel visual review is made.
私有仓库仍需授权；源码包不含 R 与依赖。字体不嵌入，未宣称在原生 Excel 中完成视觉验收。
