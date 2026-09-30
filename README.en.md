# evanxlsx

[中文](README.md) · [Bilingual guide](inst/guide/usage.html)

One consistent Excel writer. The only direct mandatory dependency is openxlsx2.
Ordinary data.frames, tibbles, duckplyr and R Polars frames use the same entry point.

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
evanxlsx::write_xlsx(df, "Arial.xlsx", font = "Arial", font_size = 12, align = "left")
```

Install with `remotes::install_github("lianglunping/evanxlsx", dependencies=NA, upgrade="always")`
or `remotes::install_local(file.choose(), dependencies=NA, upgrade="always")`.
Private access requires a local credential. Updating resolved required dependencies is allowed;
use a separately controlled project library for frozen environments. Export never installs software.
Base install.packages(repos=NULL) does not download missing dependencies.

0.2.1 fixes literal temporal column selection, warns about custom row names, isolates relevant
numeric/date/ID/border formatting options, and ignores max_width with fixed widths. Final-copy
failure attempts original-file restoration or new-partial-target removal; it preserves the complete
new workbook and valid backups. Recovery may itself fail and is not a transaction or a concurrent lock.
Only R CMD build creates installation archives. Obsolete Python packaging/static-check scripts were
removed; their history remains in Git. The installed guide is the single maintained HTML source.

All duckplyr objects and Polars LazyFrames require collect=TRUE; max_rows is a returned-row limit,
not an engine memory budget. Fonts are not embedded or installed. No automatic data repair, upload,
append-to-existing-workbook operation or new data processing framework is included.
See NEWS.md and the version-specific validation report for changes, tested commits and scope.

Run `Rscript tools/check.R` for the native package check. Full acceptance is defined in the workflow.
`system.file("guide", "usage.html", package="evanxlsx")` locates the installed bilingual guide.
