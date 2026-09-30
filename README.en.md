# evanxlsx

[中文](README.md) · [Exporter guide](inst/guide/usage.html) · [Optional data tools](inst/guide/data_tools.html)

Consistent Excel output plus four optional Polars data helpers. Excel-only use still directly requires only openxlsx2.

- summarise_numeric: Tidy column/group selection; finite-data counts, mean/median/sample SD and linear quartiles.
- flag_iqr: non-destructive fences and explicit reasons for unclassified observations.
- separate_strict: literal delimiter, exact field counts, no silent dropping or padding.
- assert_unique_keys: validate reshape keys without guessing an aggregation.

All four return native R Polars LazyFrames. Summaries/flags build expressions. Strict guards execute validation; lazy inputs require collect=TRUE. They are not snapshots of changing sources. Only small validation aggregates return to R; source/engine work may be large.
NaN/null are missing, infinity invalidates group statistics with a visible count. Unsupported exact numeric types need explicit conversion. This is not a reimplementation of Tidy translation; compose with tidypolars.

Install required dependencies via remotes (dependencies=NA). Optional functions need separately installed polars, rlang and tidyselect. No automatic installation during use; the repository remains private. See the version-specific validation record for tested commits and environments, not just the package version label.
