# evanxlsx 0.2.0

[中文](README.md) · [Bilingual guide](inst/guide/usage.html) · [Validation](validation/STATUS_0.2.0.md)

One Excel writer for ordinary data.frames/tibbles, duckplyr and R Polars.
Defaults: Times New Roman, 11 pt, centered body, blank missing values, frozen header and three-line borders.
No package installation during export, no data upload, and no font installation or embedding.

## Install with required dependencies

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", ref = "feature/0.2.0-backends",
                        dependencies = NA, upgrade = "never")
remotes::install_local(file.choose(), dependencies = NA, upgrade = "never")
```

Private GitHub access needs a local read credential; never share or commit it.
NA selects required dependency fields, not all optional Suggests. Base install.packages(repos=NULL)
cannot download missing dependencies. Offline use requires R and dependencies to be prepared separately.
This branch's acceptance status is recorded in STATUS_0.2.0.md; main is preserved separately.
Use the full tested code SHA as ref for reproducibility.

## Use

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
evanxlsx::write_xlsx(df, "Arial.xlsx", font = "Arial", font_size = 12, align = "left")
```

Body alignment: center, left, right or justify. header_align is independent.
An installed font is required for matching display. Explicit overwrite backs up and replaces the
whole workbook, not appending worksheets. Wrapping is not guaranteed row autofit.

## Optional backends

```r
install.packages("duckplyr")
Sys.setenv(NOT_CRAN = "true")  # Installation session; permit precompiled Polars components.
install.packages("polars", repos = "https://community.r-multiverse.org")
evanxlsx::write_xlsx(list(duck = q_duck, polars = p_df, query = p_query),
                       "mixed.xlsx", collect = TRUE, max_rows = 100000)
```

All duckplyr objects and Polars LazyFrames require collect=TRUE; eager Polars DataFrames do not.
Core R>=4.1.3 is separate from optional Polars R>=4.3. Adapter: duckplyr>=1.2.1, Polars>=1.16.0,<2.0.0.
Polars 2.x is rejected until revalidated. Ordinary exports do not require Python or Arrow.

max_rows is a per-sheet data-row cap, default1048575 (Excel capacity minus header), not a memory budget.
A final LIMIT/head(max_rows+1) collects once; excess rows fail without truncation or replacing output.
Engine joins/sorts/scans remain unbounded by this setting; the workbook is not a streaming writer.
Sort upstream when order matters.

Polars 64-bit integers are checked from exact strings before numeric conversion; unsafe columns stay
text. Decimal stays exact text. Datetime/Time is cast to text before POSIXct conversion. This is not
native Excel datetime or a full timezone-database round trip. Nested/binary/duration columns require
explicit conversion. Base/duckplyr integer64 must be explicitly converted to character.
Precision already lost upstream cannot be recovered.

## Installed examples and reproduction

```r
source(system.file("examples", "basic.R", package = "evanxlsx"), encoding = "UTF-8")
example_basic()
source(system.file("examples", "backends.R", package = "evanxlsx"), encoding = "UTF-8")
example_backends()
utils::browseURL(system.file("guide", "usage.html", package = "evanxlsx"))
```

Fixtures are deterministic, synthetic, and write to new temporary paths by default.
Run tools/check.R, tools/install_check.R, install the package, then tools/integration_check.R and
tools/dependency_check.R. Dedicated backend tasks fail rather than skip when dependencies are missing.
Dependency tasks exclude preinstalled site libraries; the outdated-version fixture is explicitly
synthetic metadata, not an older openxlsx2 implementation. Logs and outputs use new validation folders.
The old STATUS.md is for0.1.1 only; use STATUS_0.2.0.md for this version.
