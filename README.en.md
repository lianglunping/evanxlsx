# evanxlsx

[中文](README.md) · [Data API](inst/guide/data_tools.html) · [End-to-end workflow](inst/guide/workflow.html)

One Excel writer plus four opt-in Tidy-selection helpers backed by R Polars.
The only direct mandatory dependency remains openxlsx2. Optional engines are installed separately.

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
source(system.file("examples", "workflow.R", package = "evanxlsx"), encoding = "UTF-8")
result <- evanxlsx_workflow()
result$path
```

The installed synthetic workflow connects Parquet, annotation cleaning, ordered grouped fill,
exact-duplicate removal, strict split, long/wide reshape, summaries, IQR flags and Excel output.
It preserves raw inputs and records object classes and a query plan. It neither imputes traits
nor deletes flagged outliers. Dynamic pivoting is not claimed to remain fully unevaluated.
The example is sourced, not a new exported API or a pipeline framework.

Version 0.3.1 rescales mean/SD intermediates by powers of two to address reproduced finite-data
underflow/overflow. It is not arbitrary precision. Counts, missing/infinite policies, quartiles,
public signatures and the exporter are unchanged. Consult version-specific acceptance records.

Install with remotes::install_github("lianglunping/evanxlsx", dependencies=NA, upgrade="always").
Private access requires a local credential. This can update dependencies; a pinned package commit
alone does not pin the project environment. Export never installs software.
