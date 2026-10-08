# evanxlsx 0.4.0 — unified import/export

Verified on 2026-10-08. Tested commit: `a994bd766b54c83334791989af42e5482bbd7b02`.
Workflow [37751091048](https://github.com/lianglunping/evanxlsx/actions/runs/37751091048) completed successfully; all eight jobs succeeded. This later record does not change tested code or README.

## Delivered behavior / 已完成

- `import(file, sheet=1, sep=NULL, text_cols=NULL, na="", ...)` reads XLSX, TXT, TSV and CSV and returns a tibble.
- `export(x, file, sheet="Sheet1", sep=NULL, overwrite=FALSE, collect=FALSE, na="", ...)` writes the same four formats, selected by extension.
- XLSX keeps the previous styled writer and named-list worksheets. CSV uses commas; TXT/TSV default to tabs. Other text delimiters use sep. Text output uses UTF-8 and normal quoting.
- Both new entry points are real public functions. Existing write_xlsx and four optional data helpers remain available.
- Default missing marker is blank; literal NA text stays text. text_cols protects specified identifiers before inference. No complete R-type preservation or distinction between every empty string and missing cell is promised.
- Text input is eager; backend text output collects the full result with explicit permission for lazy queries. It is not a streaming or memory-bounded API.
- All formats refuse overwriting by default and share backup/recovery on explicit overwrite. Overwrite replaces a whole file, not one worksheet; no append API was introduced.
- Required IO dependencies are openxlsx2, readr and tibble, resolved at installation. Polars remains optional. The exporter does not install software during use.
- README now has exactly four main sections: 安装、数据读取、数据输出、数据处理. The longer former IO reference is separate from the primary quickstart.

## Actual tests / 实际测试

| Environment | R | R CMD check | Core assertions | Backend assertions | Data assertions | README blocks | Install routes |
|---|---|---|---:|---:|---:|---:|---:|
| macOS ARM | 4.6.1 | OK | 396 | 287 | 280 | 5 | 3 |
| macOS Intel | 4.6.1 | OK | 396 | 287 | 280 | 5 | 3 |
| Windows | 4.6.1 | OK | 396 | 287 | 280 | 5 | 3 |
| Ubuntu release | 4.6.1 | OK | 396 | 287 | 280 | 5 | 3 |
| Ubuntu oldrel | 4.5.3 | OK | 396 | 287 | 280 | 5 | 3 |
| Ubuntu minimum, core only | 4.1.3 | 1 optional-package NOTE | 396 | Not in scope | Not in scope | Not in scope | 3 |

All executed test assertions passed without unexpected warnings/errors/skips. The minimum R job intentionally excluded optional backends; its NOTE lists absent Suggests and is not Polars/data acceptance. Source, R-built tar and authenticated GitHub installation routes passed in all six environments. Two separate Windows/Ubuntu jobs each passed local/GitHub/outdated-dependency scenarios (six total), including unified CSV export/import after dependency resolution. The outdated fixture is synthetic dependency metadata, not a historical implementation.

Linux additionally passed the existing 37 large-export assertions and ten grouped Tidy recipe checks. Core tests include four formats, uppercase extension, sheet names/index/ranges, font/size/alignment, Chinese/English, leading zeros and long IDs, quoting/tabs/newlines, literal NA, custom delimiters/markers, parse errors, >32767-character text fields, header-only tables, overwrite refusal and exact backup identity. The README's five marked blocks were executed directly, not replaced by different example code.

Initial run 37750636232 was not accepted: one test incorrectly required inferred all-missing text to remain character, and a deliberate missing-column declaration produced an uncaptured warning. The final tests separately verify missingness under inference and character type under text_cols, and explicitly expect the missing-column warning plus error. Runtime implementation was unchanged by that test correction; initial evidence remains in history and the delivery.

## Reproduction and artifacts / 复现

The downloaded eight original artifact ZIPs were checked against their advertised SHA256 and ZIP CRC. Test logs, status files, source snapshots and results were read. The R-built installer and Git snapshot agree on all nine runtime R files.

Installer: `evanxlsx_0.4.0.tar.gz`, taken unchanged from the successful macOS ARM artifact.
SHA256: `748925079c2e120bc4651dba67758d84a67a9fb1340f9be5bcdde2ac62fa6a87`.

From a fresh checkout of the tested commit with dependencies installed:

```sh
Rscript tools/check.R
Rscript tools/install_check.R
# Install the generated R-built archive into the test library.
Rscript tools/integration_check.R
Rscript tools/data_check.R
Rscript --vanilla tools/readme_check.R
Rscript tools/dependency_check.R
```

The workflow records actual dependency versions. Tests use synthetic inputs; new IO/README fixtures are deterministic. Existing random data tests retain their original seeds. Output goes to new validation directories; no research data are uploaded. This is automated acceptance for the listed environments, not a native Excel visual review or a guarantee for all future package versions. No new GitHub Release/CRAN publication is claimed.
