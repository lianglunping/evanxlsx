# evanxlsx 0.2.0 — 验收通过 / Accepted on the tested matrix

Validation date / 验收日期: 2026-09-30.

Tested code commit / 已测试代码: `5f66941287942a370c620ff692ba846830a0c4dd`.
Workflow / 完整运行: [36684489160](https://github.com/lianglunping/evanxlsx/actions/runs/36684489160).
The workflow completed successfully with all eight jobs successful. / 八个任务均完成并通过。
Subsequent validation-only commits do not change the tested implementation, tests, dependencies or installed documentation.
后续仅更新 validation 文件的提交不改变已测试的实现、测试、依赖及安装文档。

## Results / 结果

| Environment / 环境 | R | Core assertions / 核心断言 | Backend assertions / 后端断言 | Source/Tar/GitHub installs |
|---|---|---:|---:|---|
| macOS ARM, Tahoe 26.6.2 | 4.6.1 | 267 PASS | 138 PASS | PASS / PASS / PASS |
| macOS Intel, Sequoia 15.7.9 | 4.6.1 | 267 PASS | 138 PASS | PASS / PASS / PASS |
| Windows Server 2022 x64, build 26100 | 4.6.1 | 267 PASS | 138 PASS | PASS / PASS / PASS |
| Ubuntu 24.04.5 LTS | 4.6.1 | 267 PASS | 138 PASS | PASS / PASS / PASS |
| Ubuntu 24.04.5 LTS | 4.5.3 | 267 PASS | 138 PASS | PASS / PASS / PASS |
| Ubuntu 22.04.5 LTS, core only | 4.1.3 | 267 PASS | Not in scope | PASS / PASS / PASS |

All executed unit/integration tests had zero failures, errors, warnings and skipped tests.
Each backend run covers 17 scenarios. Six environments times three installation routes = 18 installation tests.
Source/tar/GitHub export smoke checks passed 46/96/46 grouped checks per environment; grouped checks are not the same counting unit as individual assertions or cell checks.

所有已执行的单元及后端测试均无失败、错误、警告或跳过。后端每组17个场景。
六环境三安装路径，共18次安装测试。每组 source/tar/GitHub 导出检查分别通过46/96/46组。
分组检查、断言和逐单元格核验是不同计数单位，不混为一个测试总数。

R CMD check: five full environments returned Status: OK. Minimum-R core returned exactly one NOTE because optional suggested packages were deliberately not installed. This is not a warning-free full-backend result on R 4.1.3. The optional backend and large-export CI steps outside their declared matrix scope are intentionally not run; no backend test was counted as passed by skipping.

五个完整环境 R CMD check 为 Status: OK。R 4.1.3核心环境因特意不安装可选建议包而有一条 NOTE，不能表述为后端也通过。
大表阶段按设计只在 Linux-release 执行，其余环境未执行该阶段，不借跳过后端断言获得通过。

## Missing dependencies / 缺失依赖

Windows and Ubuntu each passed three fresh-visible-library scenarios: local installation, authenticated GitHub installation and an installed-but-outdated synthetic dependency metadata fixture. Total: six scenarios. The tests verified required dependencies were installed, optional duckplyr/Polars were not silently installed, absent optional engines produced installation hints, and a real workbook round trip succeeded.

Windows、Ubuntu各通过本地、私有GitHub、过旧依赖元数据三个场景，共6次。开始时可见包库没有openxlsx2；结束时必要依赖满足要求、可选后端未擅自安装、工作簿读写通过。过旧版本场景是明确标记的合成元数据，不是假冒的旧版openxlsx2实现兼容测试。

Use dependencies=NA with upgrade="always" for automatic repair, accepting possible updates to resolved required dependencies. Earlier tests showed upgrade="never" did not repair an already installed dependency below the minimum version. Export never installs software. A local archive installed with base install.packages(repos=NULL) does not resolve/download missing dependencies.

## Time fix / 时间精度修复

The returned local run verified physical Time nanoseconds before conversion. Default Time-to-String casting omitted fractions. Explicit `dt$to_string("%H:%M:%S%.9f")` retains nine digits, including `01:02:03.123456789`, in eager and lazy Excel exports. The old failing assertion is retained, not weakened. Four additional regressions cover nine boundary inputs, physical values, exact XML text, midnight limits, missing values, multiple columns and empty frames.

输入整数纳秒未丢失，问题出在默认Time转字符串省略小数秒。显式九位格式后原失败断言及新增四场景均通过。
这是将时间精度保留为文本，不声称原生Excel时间能精确保留纳秒或完整时区语义。

## Larger data and independent audit / 大表及独立核验

The 10,000-row by 72-column fixture passed 37 R assertions for ordinary R, duckplyr and Polars LazyFrame on Linux. A separate Python standard-library, read-only XML audit checked all 2,160,000 data cells across the three resulting workbooks, not just a row-count check. It checked coordinates, text IDs, blank cells, booleans/numerics as applicable, and absence of unexpected formulas; numeric tolerance was 1e-14. All passed.

10000行×72列三后端大表通过37项R断言。另用Python只读流式XML核验三个工作簿全部2160000个数据单元格；不是仅检查行数。输入为确定性合成数据，无随机抽样和真实研究数据。

Returned local results additionally passed 267 core assertions, 138 backend assertions and 37 large assertions; the returned archive is separate evidence, not a substitute for CI. Local independent checks covered 18 Time cells, 480 mixed-backend cells and 2,160,000 large-workbook cells. The final CI audit also checked 18 Time cells in each of five backend environments. Full scripts/logs are included in the conversation delivery.

本地返回结果另行通过267/138/37项断言，且独立核验18个Time单元格、480个混合单元格及2160000个大表单元格；不能将本地通过等同于跨平台通过。最终CI另核验五环境各18个Time单元格。

One-run Linux write times for the synthetic wide fixture were 2.954 s (R), 2.444 s (duckplyr), 2.067 s (Polars lazy); each output was 4,260,666 bytes. These are single-run observations, not a benchmark ranking or a peak-memory measurement.

## Source identity / 源码身份

Returned result archive SHA256: `b7d2e15985c1982cba1d573c2b6785f0a2c7905d0e3a663e41c23889e2991250`.
All 44 returned source-manifest entries matched the sent local candidate. The final CI implementation and old/new R tests matched those locally verified bytes. Windows archive metadata/documentation had CRLF/LF-only differences; R source and R test bytes matched. Original archives were not rewritten, and their raw SHA256 values are retained.

R/backends.R SHA256: `ec91106c3a89d5f05bf61de60b5da66301a36bfe242d9f462d381cc1f90d4230`.
Time regression SHA256: `74212992255950e9ff32338fd258e6d18761754d5041be73fa37fd4cbdd9e20c`.
The distributed evanxlsx_0.2.0.tar.gz is the actual R-built macOS ARM CI archive, SHA256 `78b0077bcf932ac362c7678ed3ebdcb935ab99d737c251f0128e3ba7ff593471`, not a Python-reconstructed source package.

The local preparation_status.json is a copied pre-run snapshot. Execution status and actual logs supersede that old NOT_RUN preparation state. / 本地preparation_status.json为运行前快照，以执行状态和实际日志为准。

## Versions and reproduction / 版本与复现

Full-backend CI used openxlsx2 1.29, testthat 3.3.2, xml2 1.6.0, dplyr 1.2.1, duckplyr 1.2.1, polars 1.16.0. See each environment log for complete transitive dependencies.

From a clean checkout of the tested commit, with the matching dependencies installed:

```sh
Rscript tools/check.R
Rscript tools/install_check.R
# Install the R-built tar.gz produced above into the test library.
Rscript tools/integration_check.R
Rscript tools/integration_check.R --large
Rscript tools/dependency_check.R
```

GitHub-install tests require an authorized credential and the tested GITHUB_SHA. No secret or real research data belongs in logs or the repository. All result folders are new folders; original inputs are retained.

## Limits / 边界

Acceptance covers the listed environments and tested versions, not every OS, future dependency or network condition. Core R>=4.1.3 does not imply optional Polars on R 4.1.3. Private GitHub installation requires access; offline installation needs pre-provisioned dependencies. Font installation/embedding is not performed, and native Microsoft Excel manual visual acceptance was not performed. The row cap limits final returned rows, not upstream query memory/time; per-sheet conversion is not streaming XLSX. Unsupported nested/binary/Duration types require explicit conversion. Precision already lost upstream cannot be recovered.

验收不等于任何地点/网络/未来版本无条件可安装，也不等于完成原生Excel人工显示验收。字体需目标机可用；行数预算不是峰值内存保证。本版未做峰值内存或多轮性能基准。

The old validation/STATUS.md documents version 0.1.1 only. Its previous stable commit remains in history: `ad379e47defcfb168891fd87d11bfc6fe343e9b0`. / 旧版本验收与历史提交保留。
