# evanxlsx 0.5.0 — verified acceptance / 实际验收

Date: 2026-10-08. Tested code: `0ce8bbb09a4c03be0d6286e6df45d0799d639b55`.
Workflow [37757603318](https://github.com/lianglunping/evanxlsx/actions/runs/37757603318) completed successfully, all eight jobs succeeded. This validation-only record does not change tested implementation, tests or README.

## 1. 完成范围 / Delivered scope

`import()` / `export()` remain the two I/O entry points. import adds cols, types, comment and lazy, retaining prior positional arguments and text_cols. Parquet is supported through native Polars scanning/sinking. Only one processing API was added: mutate_row_stats(). Existing cleaning/pivot/broadcast/append-row verbs are reused. README retains exactly four main sections: installation, input, output, processing; cleaning comes first.

cols selects/reorders names or positive positions. types declares character, double/numeric, integer, logical or date: these are data types, not Excel display formats. Identifier types are applied before inference. Old numeric openxlsx2 type codes remain available for XLSX. Contradictory/missing declarations are rejected.

Ordinary import returns a tibble. Lazy text/Parquet returns a genuine Polars LazyFrame, not an already-loaded table. Metadata/header/type-inference samples may still be read. XLSX rejects lazy=TRUE; selecting XLSX columns does not promise sparse decompression.

comment="#" uses optional Polars prefix parsing even for eager output. It skips comment records while preserving internal gene#tag and quoted multiline content. Both LF and CRLF bytes are tested exactly. Ordinary text remains on readr; declare important types because inference differs by backend.

Parquet has native types/nulls and rejects text sep/comment/na settings. Lazy Parquet preserves native types; eager conversion follows existing exact-text protection for wide integers/Decimal/high-precision times. Parquet output uses a native sink, not an intermediate full R frame. collect=TRUE permits execution. All formats retain default overwrite refusal and explicit backup/recovery. No mandatory dependency was added; Polars is optional for Parquet/lazy/comment parsing and statistics also use the existing optional rlang/tidyselect stack.

## 2. 实际测试 / Results

| Environment | R | R CMD check | Core | Exporter backend | Data/lazy/row | README blocks | Install routes |
|---|---|---|---:|---:|---:|---:|---:|
| macOS ARM | 4.6.1 | OK | 443 | 287 | 394 | 11 | 3 |
| macOS Intel | 4.6.1 | OK | 443 | 287 | 394 | 11 | 3 |
| Windows x64 | 4.6.1 | OK | 443 | 287 | 394 | 11 | 3 |
| Ubuntu release | 4.6.1 | OK | 443 | 287 | 394 | 11 | 3 |
| Ubuntu oldrel | 4.5.3 | OK | 443 | 287 | 394 | 11 | 3 |
| Ubuntu minimum/core only | 4.1.3 | 1 optional-package NOTE | 443 | Not in scope | Not in scope | Not in scope | 3 |

Executed assertions had zero failures, unexpected warnings, errors or test skips. Minimum R deliberately excludes optional backends; its NOTE is not Polars/data acceptance. Each data suite covers20 scenarios; each exporter-backend suite19. Eleven actual README blocks run on each full environment; these units are not summed as one test count.

Six environments passed source-directory/R-built-tar/authorized-GitHub installs:18 installations. Windows/Ubuntu each separately passed three dependency scenarios:6 total. The outdated fixture is synthetic dependency metadata, not an old implementation test. Linux additionally passed37 existing large-export assertions and10 Tidy recipe groups. No new speed ranking or peak-memory study was performed.

## 3. 规则与覆盖 / Semantics and coverage

New coverage includes named types/selection, XLSX integer fraction refusal, conflicting/absent declarations, genuine text/Parquet queries, continued source-file dependence, exact prefix-comment parsing, native Int64 retention, backup identity, deferred parser errors and row-statistic edge cases.

mutate_row_stats(.data,.cols,na_rm=TRUE,prefix="row") preserves original rows/columns and appends row_n, row_mean, row_sd, returning a LazyFrame. Measurements must have comparable units. _n counts finite values. Null/NA and NaN are missing; any infinity makes mean/SD missing. All-missing mean and singleton SD are missing. SD uses n-1; na_rm=FALSE propagates missingness. Binary scaling reduces intermediate range failures, not arbitrary precision or unrepresentable true results.

README distinguishes annotation filling from measurement imputation, drop_na from replace_na, non-destructive IQR flags, row statistics, grouped column summaries, broadcasting statistics into original rows and explicit Mean/SD presentation rows. Summary rows are not new raw observations.

## 4. 失败记录 / Earlier failed attempts

Candidate e89b810 / run37756316873 failed a retained-XLSX-declaration check. The implementation now selects before final declaration checks; original tests stayed. Source review also corrected null infinity flags in the new row expression.

Candidate2cd4a0e / run37756725456 failed two Windows multiline comparisons: writeLines() generated CRLF inside a quoted field while the expectation assumed LF. The parser preserved actual source bytes. Final tests construct both LF and CRLF explicitly and require exact corresponding content; no input normalization or dropped checks. Runtime is unchanged by that last test correction. Representative failed artifacts remain separately in the delivery, not counted as passing results.

## 5. 身份与复现 / Identity and reproduction

Installer: actual R-built evanxlsx_0.5.0.tar.gz, extracted unchanged from the successful macOS ARM artifact.
SHA256: `05fd4a94cb067b4d1ff53f35c5e23f88e80bc4bd9f658b4a03fc488f9f99e6e1`.
Eight original ZIPs passed advertised SHA256 and CRC verification; logs, statuses, CSVs and source identities were read. All11 runtime R files match across six Git snapshots and the installer. Against0.4.0, eight old runtime files remain byte-identical; io.R is extended and two runtime files are added.

A separate Python standard-library read-only audit checks actual row_stats.xlsx and summary.xlsx:40 headers and134 data cells, including types, missingness, IDs, sample SD and type-7 quartiles, passed. It does not regenerate files or re-execute R. Full artifact IDs/hashes, source, outputs and audit scripts are in the conversation delivery.

```sh
Rscript tools/check.R
Rscript tools/install_check.R
# Install the R-built archive into the test library.
Rscript tools/integration_check.R
Rscript tools/data_check.R
Rscript --vanilla tools/readme_check.R
Rscript tools/integration_check.R --large
Rscript --vanilla tools/tidy_smoke.R
Rscript tools/dependency_check.R
```

New inputs are deterministic; inherited random tests keep seed20260930. New validation directories retain results. No research data were used. Full environments used Polars1.16.0, tidypolars0.19.0, readr2.2.0, openxlsx2 1.29, dplyr1.2.1, tidyr1.3.2, rlang1.3.0, tidyselect1.2.1, tibble3.3.1; complete session details are in the original artifacts.

## 6. 边界 / Limits

Lazy is not zero I/O. Schema/inference, scans, joins/sorts and materialization cost resources; native sinks do not bound every query's memory. XLSX/CSV export can materialize. The API is one local file, not an untested remote/multifile framework. Future Polars2.x compatibility, all encodings or arbitrary backend argument combinations are not implied. XLSX empty-string readback limitations remain. File recovery is best-effort single-writer protection, not a transaction/crash/concurrency guarantee. HTML comes from tested README; a local browser executable was unavailable for visual checking. No native Excel visual review, unconditional offline installation or arbitrary-Tidy compatibility is claimed.
