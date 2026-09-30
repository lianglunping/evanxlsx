# evanxlsx 0.2.1 — 验收记录 / Acceptance record

Date / 日期: 2026-09-30.

Exporter code / 导出包验收提交: `b598a8d7f5dd8f7c08d02a1497e579a61cd056c1`.
Full exporter workflow / 导出完整工作流: [36691972201](https://github.com/lianglunping/evanxlsx/actions/runs/36691972201), completed successfully, all eight jobs passed.
Optional recipe commit / 可选工作流提交: `bd4b057edd8e6b1ceaae41ff5f2d57895cf65427`.
Recipe workflow / 可选工作流验收: [36692337109](https://github.com/lianglunping/evanxlsx/actions/runs/36692337109), both Windows and Ubuntu jobs passed.

The recipe commit differs from the exporter-tested commit only in tools/tidy_smoke.R and its optional qualification workflow. R implementation, DESCRIPTION, NAMESPACE, installed documentation and all exporter tests are identical. Subsequent validation-only commits do not change those tested files.
可选工作流提交只修改示例验证脚本和对应工作流，不修改已验收的运行实现、包元数据、安装资源或原新导出测试。验收提交不能与后续报告提交混为同一个SHA。

## 1. 修正范围 / Changes

- Select Polars temporal columns by known positions, avoiding wildcard/regex interpretation of names.
- Warn about custom row names; important IDs remain explicit columns, with no guessed automatic column.
- Isolate the numeric/date/datetime/string-number/border formatting options actually used here, restoring them on exit. Other page/compression options remain outside this contract.
- With fixed numeric widths, do not evaluate max_width.
- Final-copy failure attempts restoration from backup, or removal of a new partial target. Retain the completed new workbook and valid backup paths. Recovery can itself fail; no transaction/concurrent-writer/crash-safety claim.
- Remove obsolete tools/package_source.py and tools/static_audit.py; Git history retains originals. R CMD build is the package builder.
- Derive CI archive versions from DESCRIPTION. Maintain one full HTML guide in inst/guide; docs/usage.html links to it.

无新增导出参数或直接必需依赖。公开入口仍为write_xlsx；tidypolars不是本包的必需依赖，也没有在本版增加通用数据清洗API。
No added exporter arguments or mandatory dependencies. Optional Tidy examples are not newly exported package functions.

## 2. 实际结果 / Results

| Environment | R | Core assertions | Backend assertions | Source/Tar/GitHub installs | Large case |
|---|---|---:|---:|---|---|
| macOS ARM | 4.6.1 | 310 PASS | 287 PASS | PASS/PASS/PASS | Not in scope |
| macOS Intel | 4.6.1 | 310 PASS | 287 PASS | PASS/PASS/PASS | Not in scope |
| Windows x64 | 4.6.1 | 310 PASS | 287 PASS | PASS/PASS/PASS | Not in scope |
| Ubuntu current R | 4.6.1 | 310 PASS | 287 PASS | PASS/PASS/PASS | 37 PASS |
| Ubuntu previous R | 4.5.3 | 310 PASS | 287 PASS | PASS/PASS/PASS | Not in scope |
| Ubuntu minimum R, core only | 4.1.3 | 310 PASS | Not in scope | PASS/PASS/PASS | Not in scope |

All executed core and backend assertions had zero failures/errors/warnings/skips. The five backend runs each cover 19 scenarios, including literal names, reordered temporal columns and real Parquet scans. This does not mean every CI step ran in every environment: the minimum R job deliberately excludes optional engines, and the large stage is Linux-only.

Five full R CMD checks returned Status: OK. The R 4.1.3 core job had one NOTE for deliberately uninstalled optional suggested packages. Do not claim Polars compatibility on minimum R from the core test.
六环境三安装路径，共18次。Windows与Ubuntu各另行通过本地、私有GitHub、过旧依赖元数据三个自动依赖场景，共6次。过旧场景是明确标记的合成元数据，不是假冒的旧版本功能实现。

The larger fixture has 10000 rows and 72 columns, exported via ordinary R, duckplyr and Polars LazyFrame; its existing 37 assertions passed. No new peak-memory study or performance ranking was performed.

## 3. Tidy→Polars 可选方案 / Optional recipes

Tested: R 4.6.1, tidypolars 0.19.0, polars 1.16.0, dplyr 1.2.1, tidyr 1.3.2, stringr 1.6.0, evanxlsx 0.2.1. Both Windows and Ubuntu passed ten grouped recipe checks. These groups are not added to the exporter assertion count.

The ten cases are mean/sd, an IQR expression helper, delimiter splitting, long/wide reshaping, replace_na, ordered within-group fill, trim/distinct, direct Excel export, statistical edge cases, and an actual Parquet scan. Numeric reference comparisons use tolerance 1e-12 and explicit sorting where needed.

`pl_iqr()` and `pl_nan_to_null()` are prototype helpers in the qualification script, not evanxlsx exports. The former returns a Polars expression using linear Q1/Q3 interpolation corresponding to R type=7 on the tested finite numeric cases. It ignores null/NaN and does not remove outliers. Arbitrary R functions are not automatically Polars functions.

### 实测差异 / Observed semantic difference

For c(1,2,NaN,NA_real_), the tested raw tidypolars mean/sd with na.rm=TRUE returned missing values, unlike R. After explicit numeric NaN-to-null normalization, the results were mean 1.5 and sample sd 0.707106781186548, matching the R reference. The original observation was retained in edge_statistics.csv; this is an explicit recipe policy, not a patch or blanket compatibility claim for tidypolars.

All-missing mean output is compared by missingness, not by preserving NA versus NaN. Singleton standard deviation stays missing; constant-data standard deviation is zero. Filling missing data with zero, dropping outliers or aggregating duplicate long-table keys is never inferred from these tests.

### 已知不直接支持 / Qualified limitations

In tidypolars 0.19.0, native IQR(), separate_wider_delim(), mean(trim=...), pivot_wider(values_fn=...) and dplyr::show_query() did not execute in the tested calls. Unknown arguments were configured to error and automatic R fallback was disabled. Use native LazyFrame$explain() for the recorded query plans. The public development website may describe a newer development version; it is not evidence of stable-version availability.

拆列只验证已给定分隔规则的案例；sep具有正则语义。长转宽只验证唯一键的例子。补值须明确类型与分组/排序，不能推断为一般统计插补。所有流程均使用合成数据，无真实研究数据。

## 4. 身份与交付 / Identity and delivery

Distributed R-built archive: evanxlsx_0.2.1.tar.gz, extracted unchanged from the successful macOS ARM CI artifact.
SHA256: `9b5f442007c3bd35615df94dec5033806326b05506d53f0f22e1d665503e54cc`.
It includes installed examples/guide and the new recovery helper; it is not a Python-built replacement.

The delivery retains eight original exporter/dependency artifact ZIPs and two final optional-recipe artifact ZIPs with SHA256/CRC checks. A separate read-only Python check validates four headers and eight data cells in the actual Tidy summary workbook, exact text/numeric cell types and absence of formulas. This limited new audit is not the older 0.2.0 multi-million-cell audit, and is not R re-execution.

Exact exporter source snapshot is source_b598a8d.zip. The final qualified optional script is separately retained as recipes/tidy_smoke.R, matching bd4b057. Older failed optional probes remain in GitHub history; they were not used as acceptance evidence.

## 5. 复现与边界 / Reproduction and limits

From a fresh checkout of the exporter-tested commit and matching installed dependencies:

```sh
Rscript tools/check.R
Rscript tools/install_check.R
# Install the R-built tar.gz from the check output into the test library.
Rscript tools/integration_check.R
Rscript tools/integration_check.R --large
Rscript tools/dependency_check.R
```

From the optional-recipe commit, with separately installed tidypolars/dplyr/tidyr/stringr/polars:

```sh
Rscript --vanilla tools/tidy_smoke.R
```

Use new output directories/checkouts; never delete prior results to simulate a clean run. GitHub installation tests require authorized credentials and the exact GITHUB_SHA; no credentials belong in scripts/logs. Fixtures are deterministic, with no sampling seed required.

Only the listed versions/environments/cases are validated, not all future packages, operating systems or Tidy syntax. Fonts must exist on the viewing computer. Native Microsoft Excel manual display acceptance was not performed. No automated data imputation or IQR outlier removal has been added. The row cap is not an engine memory limit, and copying recovery is best-effort single-writer recovery. Private GitHub access and dependency availability remain installation prerequisites.

旧版验收留档不变。本版的重点是正确性修正与移除重复工具，而不是扩大为一套新的数据处理框架。
