# evanxlsx 0.3.1 — 实际验收 / Verified acceptance

Date: 2026-09-30.
Tested code: `ec9ca041053dd0a32b44e4daa5c5d598598c9fed`.
Full workflow: [36722679304](https://github.com/lianglunping/evanxlsx/actions/runs/36722679304), completed successfully.
All eight original artifact ZIPs were downloaded, verified against their advertised SHA256, CRC-checked and inspected. Validation-only commits after this code do not change implementation, tests, dependency declarations or installed examples.

## 1. Scope / 本轮改动

No new exported function, argument or mandatory dependency was added. The four existing Excel runtime files, three other data-helper runtime files, NAMESPACE and all inherited test files are unchanged. Of 20 inherited runtime/test files compared with the accepted 0.3.0 snapshot, only R/summarise_numeric.R changed. The patch adds power-of-two rescaling for mean and sample SD; counts, input missing/infinite-value policies, medians, quartiles and IQR calculation remain unchanged.

新增的是安装后可以source的工作流示例及中英文指南，不是新的通用管道框架或包公开函数。用户调用已有函数的方式不变。

## 2. Reproduced numeric issue / 数值问题的复现与修正

Unchanged 0.3.0 was separately reviewed in run [36720911770](https://github.com/lianglunping/evanxlsx/actions/runs/36720911770), commit `763e7a3fce22643e213d8c9c8145646ef9c12670`. The review contains eight input cases and six metrics, 48 observations; five metric mismatches were reproduced across four extreme finite-data cases. These observations are not release acceptance tests.

| Input | Metric | 0.3.0 observation | 0.3.1 verified result, rounded here |
|---|---|---|---|
| c(1,2,3,4)*1e-200 | sample SD | 0 | 1.29099444873581e-200 |
| c(1,2,3,4)*1e200 | sample SD | Inf | 1.29099444873581e200 |
| rep(1e308,4) | mean | Inf | 1e308 |
| rep(1e308,4) | sample SD | NaN | 0 |
| c(-1e308,0,0,1e308) | sample SD | Inf | 8.16496580927726e307 |

Normal, zero, singleton and missing-value controls were retained. Regressions compare dimensionless ratios so that zero cannot pass as an approximation to a tiny nonzero SD. Five binary-scale exponents (-1022, -665, 0, 665, 1020), grouped/ungrouped input and explicit missing/infinity policies are checked.

The internal power-of-two exponent is clipped to the normal Float64 range, not used as a data-exclusion threshold. Scaling reduces intermediate overflow/underflow in the reproduced mean/SD cases. It is not arbitrary precision and does not guarantee every extreme distribution, quantile calculation or mathematically unrepresentable result. Already-lost input precision is unrecoverable. No new benchmark or peak-memory claim is made.

首轮候选的已核验Mac ARM日志中，数值与工作流比较通过，但测试用数据框切片产生了显式行名，正确触发五条既有警告，导致该轮不被接受。仅将这份四值测试输入重建为默认行名；没有抑制警告、删除断言、放宽误差或修改运行实现。随后完整重跑本页记录的最终提交。

## 3. Final matrix / 最终矩阵

| Environment | R | R CMD check | Core assertions | Existing backend assertions | Data assertions | Install routes |
|---|---|---|---:|---:|---:|---|
| macOS ARM | 4.6.1 | OK | 310 PASS | 287 PASS | 266 PASS | source/tar/GitHub PASS |
| macOS Intel | 4.6.1 | OK | 310 PASS | 287 PASS | 266 PASS | source/tar/GitHub PASS |
| Windows x64 | 4.6.1 | OK | 310 PASS | 287 PASS | 266 PASS | source/tar/GitHub PASS |
| Ubuntu release | 4.6.1 | OK | 310 PASS | 287 PASS | 266 PASS | source/tar/GitHub PASS |
| Ubuntu previous R | 4.5.3 | OK | 310 PASS | 287 PASS | 266 PASS | source/tar/GitHub PASS |
| Ubuntu minimum, core only | 4.1.3 | 1 NOTE | 310 PASS | Not in scope | Not in scope | source/tar/GitHub PASS |

Each full data environment executed 14 scenarios; 266 data assertions include the previous 141 plus 125 new assertions in four scenarios. Existing backend tests remain 19 scenarios. All executed unit/integration assertions had zero failures, errors, warnings and skipped tests.

The minimum-R NOTE is for deliberately uninstalled optional suggested packages. It is not data-module or Polars acceptance on R 4.1.3. Some CI stages intentionally do not run outside their declared scope; these are not counted as successful skipped tests.

Six environments times three installation routes = 18 installations. Separate Windows/Ubuntu jobs each passed three required-dependency-resolution scenarios (local, authenticated GitHub, outdated synthetic dependency metadata), total six. The outdated fixture is synthetic metadata, not an older implementation. No optional Polars/duckplyr installation is silently required for Excel-only use.

Linux additionally passed the existing 10000-row by 72-column export case (37 assertions) and ten previously qualified Tidy recipe groups. These are separate counting units and are not added to the data assertion count.

## 4. Practical workflow / 实际可运行工作流

The installed `inst/examples/workflow.R` defines `evanxlsx_workflow()` after source(); it is not a new NAMESPACE export. Source alone does not write files. Calling the example refuses an existing output directory, creates a new one, and uses deterministic synthetic data only.

It connects Parquet scanning, text trimming, annotation-only missing replacement, explicit NaN-to-null conversion for one numeric column, exact-row duplicate removal, sorted within-treatment batch filling, strict locus splitting, long/wide conversion with key checks, grouped summaries, IQR flags and one five-sheet workbook.

Raw input has 13 rows, including one intentionally identical duplicate; raw.rds and raw.parquet are retained. The cleaned table has 12 rows. Trait missing values are not filled with zero, text "NA" is not treated as missing, and no IQR-flagged observation is removed. Original RDS preserves the NA/NaN distinction. The example contains one flagged height observation, with unclassified missing observations retained.

| Sheet | Rows | Columns | Purpose |
|---|---:|---:|---|
| clean | 12 | 9 | explicit cleaning and strict split |
| long | 24 | 9 | one sample-trait observation per row |
| wide | 12 | 4 | unique-key reshape back to wide |
| summary | 2 | 21 | grouped measurement counts/statistics |
| flagged | 24 | 16 | all observations plus IQR annotations |

Runtime stage classes and a native Polars plan are saved. All five final objects in this tested example were LazyFrames (some also carried tidypolars class). This alone does not prove that dynamic pivot discovery or validation performed no earlier query. Stable sources are needed because validation and later collection can reread inputs. No claim of arbitrary Tidy compatibility or automatic statistical imputation is made.

## 5. Independent checks and identities / 独立核验与文件身份

A separate Python-standard-library, read-only XML audit checked all 59 headers and 798 data cells in the actual macOS ARM R-generated five-sheet workbook. It checks coordinates, text/numeric/Boolean types, blank cells, leading-zero IDs and no formulas. Means/SD use Python statistics; quartiles use an independently written type-7 formula. Numeric tolerance for this moderate-valued workflow is 1e-12. Extreme numeric regressions use scaled ratios separately, not that absolute tolerance. Audit passed.

This is a new targeted workflow audit, not a repetition of an older multi-million-cell audit. An exploratory artifact_tool import read text IDs correctly; its preview displayed numeric-looking strings differently. The original XLSX was not rewritten. Native Microsoft Excel visual acceptance has not been performed, and the preview is not the value oracle.

All 36 non-validation .R files in the six final source snapshots matched byte-for-byte across platforms. Original artifact ZIPs and workbook bytes were retained unchanged.

Distributed installer is the actual R CMD build product from the successful macOS ARM artifact, not a reconstructed archive.
- evanxlsx_0.3.1.tar.gz SHA256: `00035d3051a00346a016c6847c588628f41c9b4d02ff7834bf906440e6cf4197`.
- workflow.xlsx SHA256: `889558007297458c4f3d30a43cd356fa52a8fc38abf3d9467466a39ea6acf5f8`.
- baseline review original ZIP SHA256: `9fe9ca2052cd225aa6b794fce9cfd7005fe23714703756c8b64f66f343381cf2`.

The installer includes the new example and bilingual workflow guide. Shared guides describing older API versions were retained; the 0.3.1 changes are recorded in NEWS and the new workflow guide. The source snapshot retains the pre-acceptance candidate status file; this validation-only update supersedes that status without altering tested package resources.

## 6. Reproduction / 复现

Full environments used polars 1.16.0, tidypolars 0.19.0, tidyselect 1.2.1, rlang 1.3.0, dplyr 1.2.1, tidyr 1.3.2, stringr 1.6.0, openxlsx2 1.29, testthat 3.3.2 and xml2 1.6.0. Complete environment logs are retained per original artifact.

From a fresh checkout of the tested commit with matching dependencies:

```sh
Rscript tools/check.R
Rscript tools/install_check.R
# Install the actual R-built archive from the check output in the test library.
Rscript tools/integration_check.R
Rscript tools/data_check.R
Rscript tools/integration_check.R --large
Rscript --vanilla tools/tidy_smoke.R
Rscript tools/dependency_check.R
```

Installed practical example:

```r
source(system.file("examples", "workflow.R", package = "evanxlsx"), encoding = "UTF-8")
result <- evanxlsx_workflow()
result$path
```

The example and range fixtures are deterministic. Existing randomized tests retain set.seed(20260930). The package never installs software while exporting or processing. Private GitHub access and optional dependencies remain explicit prerequisites. A pinned package commit does not freeze all dependencies. Font availability, native viewer rendering, finite-precision limits, query-resource costs and single-writer recovery limits remain as documented. No unconditional future-version or offline-installation guarantee is made.