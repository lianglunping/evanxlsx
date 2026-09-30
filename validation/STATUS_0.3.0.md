# evanxlsx 0.3.0 — 实际验收 / Verified acceptance

Date: 2026-09-30.
Tested code: `cac5893bd56eb4415219cdfae80b57ab7e73fe9c`.
Full workflow: [36716973212](https://github.com/lianglunping/evanxlsx/actions/runs/36716973212), completed successfully.
Eight original workflow artifact ZIPs were downloaded, their advertised SHA256 and ZIP CRC verified, and their actual logs/results inspected.
后续仅更新 validation 的提交不改变已测试的实现、测试、依赖及安装资源。报告提交与运行代码提交分别记录。

## 1. 已实现接口 / Implemented functions

The existing write_xlsx() exporter remains unchanged. Four new optional exports are installed:

| Function | Purpose | Returned object |
|---|---|---|
| summarise_numeric(.data, .cols, .by=NULL, na_rm=TRUE) | Counts, mean, median, sample SD, Q1/Q3/IQR for selected columns | Polars LazyFrame |
| flag_iqr(.data, .col, .by=NULL, k=1.5, min_n=4L, prefix="iqr") | Add fences, outlier flags and reasons; never delete rows | Polars LazyFrame |
| separate_strict(.data, col, into, sep, remove=FALSE, collect=FALSE) | Literal delimiter, exact nonmissing field count | Polars LazyFrame |
| assert_unique_keys(.data, .cols, allow_missing=FALSE, collect=FALSE) | Validate keys before reshaping without guessing an aggregation | Polars LazyFrame |

Tidy selection supports bare names, c(), all_of() and starts_with(); renaming and where() predicates are deliberately not supported. Native Polars expressions do the data calculations. No row-wise R callbacks or automatic fallback are added. Standard mutate/filter/pivot/fill operations continue to use supported tidypolars methods.

The data functions accept ungrouped R data.frames and Polars eager/lazy frames. They reject existing R or tidypolars group_by()/rowwise() state rather than silently pooling groups: explicitly ungroup() and use .by. The latter safeguard was added after the initial candidate, with real eager/lazy regression tests, before this final matrix was accepted.

普通数据框和Polars对象均可进入四个函数，结果统一是Polars LazyFrame，而非普通tibble。统计/标记仅构造表达式，元数据查询可能读取schema。严格拆列/键检查会执行校验：LazyFrame需明确collect=TRUE。它们只取小型校验统计回R，但扫描成本不受这个小结果限制；后续collect可能再次读取源，因此不是动态数据源的事务快照。

## 2. 最终测试矩阵 / Final matrix

| Environment | R | Core assertions | Existing backend assertions | New data assertions | Installation routes |
|---|---|---:|---:|---:|---|
| macOS ARM | 4.6.1 | 310 PASS | 287 PASS | 141 PASS | source/tar/GitHub PASS |
| macOS Intel | 4.6.1 | 310 PASS | 287 PASS | 141 PASS | source/tar/GitHub PASS |
| Windows x64 | 4.6.1 | 310 PASS | 287 PASS | 141 PASS | source/tar/GitHub PASS |
| Ubuntu release | 4.6.1 | 310 PASS | 287 PASS | 141 PASS | source/tar/GitHub PASS |
| Ubuntu oldrel | 4.5.3 | 310 PASS | 287 PASS | 141 PASS | source/tar/GitHub PASS |
| Ubuntu minimum, core only | 4.1.3 | 310 PASS | Not in scope | Not in scope | source/tar/GitHub PASS |

Every executed core, backend and new-data test had zero failures/errors/warnings/skips. New data tests comprise ten scenarios per full-backend environment; old backend tests remain nineteen scenarios. These counts are separate from grouped recipe checks and cell audits.

Five full environments returned R CMD check Status: OK. The minimum-R core environment returned exactly one NOTE because dplyr, duckplyr, polars, tidyselect, tidypolars, tidyr and stringr were deliberately absent. This is not Polars/data-module acceptance on R 4.1.3. CI steps outside their declared scope were intentionally not executed; no missing backend test was counted as passed through a skip.

Six environments times three installation routes = 18 installations. Separate Windows/Ubuntu jobs each passed three required-dependency scenarios (local, authenticated GitHub, outdated synthetic dependency metadata), total six. They start without openxlsx2 visible and do not silently install optional Polars/duckplyr. The outdated fixture is synthetic package metadata, not an older implementation compatibility test.

The existing 10000-row by 72-column exporter test passed 37 assertions on Linux. The ten previously qualified Tidy recipe groups also passed on Linux. No new peak-memory study or performance ranking is claimed.

## 3. 统计与数据规则 / Statistical and data contracts

For each measurement, n_total = n_valid + n_missing + n_infinite. Valid means finite. Null/NA and NaN count as missing. Any infinity invalidates the six descriptive statistics in that group/column while n_infinite exposes the condition. na_rm=FALSE also invalidates statistics in groups containing missing data. This is an explicit module policy, not a claim that arbitrary Tidy operations treat NaN identically.

SD uses ddof=1 (sample SD); quartiles use linear interpolation corresponding to R type=7 for the tested finite numeric inputs. All-missing or empty ungrouped summaries have missing descriptive statistics; singleton SD is missing. Empty grouped summaries have zero rows.

Measurements are limited to ordinary 8/16/32-bit integers, UInt32 and Float32/64. Int64/UInt64/Decimal measurements need explicit upstream conversion; no silent numeric coercion of exact identifiers. Grouping keys and character identifiers retain their types.

IQR fences are Q1-k*IQR and Q3+k*IQR. Strictly outside yields TRUE; equality yields FALSE. Default k=1.5 and min_n=4 are documented, configurable screening conventions, not significance tests or universal sample-size rules. Missing rows, any group infinity, too few finite observations and zero IQR yield NA flags with reasons. No observations are automatically removed; post-exclusion statistics require an explicit user decision. Filtering outlier==FALSE also removes unclassified NA flags, which must be considered deliberately.

Strict splitting uses literal delimiters, retaining character fields, leading zeros, whitespace and empty substrings. Missing strings produce missing fields. Too many/few fields cause an error, not truncation/padding. No quoted-CSV parser or guessed type conversion is provided. Key validation rejects duplicate combinations and, by default, missing keys. It never chooses mean/sum/first as an implicit pivot aggregation.

## 4. 参考结果与原始数据保护 / References and input protection

Ten new scenarios cover explicit R references for summary statistics, ordinary/NaN/infinite/empty inputs, multiple/null groups, literal column names, deterministic random finite data, IQR fences/reasons, exact boundary equality, malformed strings, duplicate/missing keys, existing grouping metadata, output-name collisions, actual Parquet scans, non-precollection, Tidy pivot composition, Excel output and installed example execution.

The randomized reference fixture uses set.seed(20260930). Other fixtures are deterministic. R comparisons use tolerance 1e-12. Original objects and synthetic Parquet hashes are checked where specified. Source-removal testing moves only a disposable synthetic file to prove a query was not already materialized, then restores it.

Tests and source were not weakened to manufacture success. The first candidate passed its initial cases, but review identified the grouping-metadata omission; the final tested commit includes the guard and additional tests.

## 5. 源码及交付身份 / Source and artifact identity

The 14 inherited R implementation/test files checked against the accepted 0.2.1 exporter source were byte-identical, including all four existing R implementation files and old core/integration/large tests. New files add the optional data layer; new Suggests do not change the sole direct mandatory dependency, openxlsx2.

All 33 non-validation .R files in the six final Git source snapshots matched byte-for-byte across platforms. Original artifact ZIPs were not rewritten. A Windows CRLF log-status terminator was normalized only when parsing the status field for the local report; the raw log remains unchanged.

Distributed installer: the actual R-built macOS ARM artifact, not a reconstructed Python archive.
File: evanxlsx_0.3.0.tar.gz.
SHA256: `f8438cbaf6335c46f8e6a29092b638a34422bd14f02a7f61542ee3a4f4feef97`.
It contains man/data_helpers.Rd, the installed bilingual guide, installed example and new runtime functions.

A separate Python-standard-library read-only audit checked the actual R-generated data_tools.xlsx: three worksheets, 26 headers and all 202 data cells, including numeric/text/Boolean types, leading zeros, coordinates and absence of formulas. Expected quartiles use an independent type-7 formula; means/SD use Python statistics; tolerance 1e-12. The audit passed. This is a targeted new audit, not the older multi-million-cell audit or native Excel visual acceptance.
Demo SHA256: `09a843364595bf564b643e9ce6a85dbe0d8300bb50e337d54700ed202321b789`.

## 6. Dependencies and reproduction / 依赖与复现

Full data environments used polars 1.16.0, tidypolars 0.19.0, tidyselect 1.2.1, rlang 1.3.0, dplyr 1.2.1, tidyr 1.3.2, openxlsx2 1.29, testthat 3.3.2 and xml2 1.6.0. Complete environment details are retained per artifact.

From a fresh checkout of the tested commit, with matching test dependencies:

```sh
Rscript tools/check.R
Rscript tools/install_check.R
# Install the actual R-built archive produced above in the test library.
Rscript tools/integration_check.R
Rscript tools/data_check.R
Rscript tools/integration_check.R --large
Rscript --vanilla tools/tidy_smoke.R
Rscript tools/dependency_check.R
```

Data test entry: tools/data_check.R. It writes a new validation/data-* directory containing environment.txt, tests.csv, test-output.txt, STATUS.txt, synthetic Parquet, data_tools.xlsx and the query plan. GitHub installation requires an authorized credential and the exact GITHUB_SHA. Do not put credentials or real research data in logs.

For the independent read-only checks supplied in the conversation delivery:

```sh
python audit/inspect_ci.py ci_artifacts evidence/ci_audit_new
python audit/verify_data_export.py examples/data_tools.xlsx evidence/data_audit_new.json
```

Only the listed versions, platforms and cases are validated. Optional data dependencies are separately installed; export itself never installs packages. Fixing an evanxlsx commit does not freeze the entire dependency environment. No unconditional offline/any-network/any-future-version installation claim. No arbitrary Tidy compiler, automatic imputation, outlier deletion, native Excel visual review, transaction-safe guard snapshot or engine-memory bound is claimed. Old acceptance reports remain in history and are not evidence for future versions.