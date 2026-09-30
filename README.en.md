# evanxlsx 0.2.0

[中文](README.md) · [Bilingual guide](inst/guide/usage.html) · [Validation](validation/STATUS_0.2.0.md)

One Excel writer for data.frames/tibbles, duckplyr and R Polars. Defaults: Times New Roman,
11 pt, centered body, value-less missing cells, frozen header and three-line borders.
No software installation during export, no data uploads, no font installation or embedding.

## Install required dependencies

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", ref = "feature/0.2.0-backends",
                        dependencies = NA, upgrade = "always")
remotes::install_local(file.choose(), dependencies = NA, upgrade = "always")
```

Private access requires a local read credential. Do not share or commit credentials.
NA selects required dependency fields, not all optional Suggests. Always permits the resolved
required dependencies to update, possibly beyond minimum versions; it does not update the whole library.
Never failed our installed-but-outdated dependency fixture, so use it only after checking versions.
Base install.packages(repos=NULL) does not download dependencies. Restart R after updating loaded packages.
Offline use requires R and dependencies separately. Consult this version's validation report before use.
Pin ref to the tested full commit SHA; do not transfer an older version's acceptance to newer code.

## Use

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
evanxlsx::write_xlsx(df, "Arial.xlsx", font = "Arial", font_size = 12, align = "left")
```

Alignment choices: center/left/right/justify. header_align is independent.
Actual display depends on installed fonts. Explicit overwrite backs up and replaces the entire
workbook, rather than appending worksheets. Wrapping is not guaranteed row autofit.

## Optional backends

```r
install.packages("duckplyr")
Sys.setenv(NOT_CRAN = "true")  # Polars installation session, permit precompiled components.
install.packages("polars", repos = "https://community.r-multiverse.org")
evanxlsx::write_xlsx(list(duck = q_duck, polars = p_df, query = p_query),
                       "mixed.xlsx", collect = TRUE, max_rows = 100000)
```

All duckplyr objects and Polars LazyFrames require collect=TRUE; eager Polars frames do not.
Core R>=4.1.3 is separate from optional Polars R>=4.3. Adapter: duckplyr>=1.2.1, Polars>=1.16.0,<2.0.0.
Polars2.x is rejected pending revalidation. Only openxlsx2 is a direct mandatory dependency.

The per-sheet row cap defaults to Excel capacity minus header, not a safe memory budget. One bounded
final collection retrieves at most max_rows+1 rows; excess causes failure, never silent truncation.
Engine resources remain unbounded by this setting. Per-sheet conversion is not streaming XLSX.
Exact integer strings are checked before numeric conversion; unsafe columns and Decimal remain text.
Polars Datetime/Time are cast to text before R conversion. Time explicitly retains nine fractional
second digits. This is text, not native Excel time or a full timezone-semantic round trip.
Nested/binary/Duration columns require explicit conversion. Base/duckplyr integer64 must be converted
explicitly. Already-lost precision cannot be recovered. See the guide for details.

## Installed examples

```r
source(system.file("examples", "basic.R", package = "evanxlsx"), encoding = "UTF-8")
example_basic()
source(system.file("examples", "backends.R", package = "evanxlsx"), encoding = "UTF-8")
example_backends()
utils::browseURL(system.file("guide", "usage.html", package = "evanxlsx"))
```

Deterministic synthetic data; fresh temporary paths by default.
Run tools/check.R and tools/install_check.R, install the R-built archive, then run
 tools/integration_check.R, tools/integration_check.R --large, and tools/dependency_check.R.
Backend tests cannot pass by skipping. Dependency tests exclude preinstalled libraries. The outdated
fixture is synthetic metadata, not an older implementation. STATUS.md covers0.1.1 only; use STATUS_0.2.0.md.
