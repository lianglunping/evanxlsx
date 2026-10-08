# evanxlsx

One `import()` and one `export()` for XLSX, TXT, TSV, CSV and Parquet. [中文](README.md)

## 1. Installation

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
library(evanxlsx)
```

Private access needs a local credential; `always` may upgrade required dependencies. Install polars separately for Parquet, native lazy queries and line-prefix comments. The optional statistics need rlang/tidyselect; compose Tidy verbs with tidypolars. No installation occurs during data operations.

## 2. Input

```r
df <- import("data.xlsx", sheet = "var")
df <- import("data.csv", cols = c("Sample_ID", "rep1"),
             types = c(Sample_ID = "character", rep1 = "double"))
df <- import("data.tsv", comment = "#")
q <- import("data.parquet", lazy = TRUE)
```

Ordinary imports return tibbles; native lazy text/Parquet imports return Polars LazyFrames. XLSX rejects lazy=TRUE rather than materializing first. Types: character, double/numeric, integer, logical, date. `text_cols` remains a shortcut for identifiers. Names or positive positions select/reorder columns; XLSX selection is not a sparse-memory guarantee. `comment` uses Polars to skip prefix comment records, without truncating hashes within data fields. Automatic type inference is backend-specific: declare important types. Metadata/schema inference still reads data; lazy does not mean zero I/O. Parquet uses stored nulls and schemas, not textual separators or missing tokens.

## 3. Output

```r
export(df, "result.xlsx", sheet = "var")
export(df, "result.tsv")
export(df, "result.csv")
export(df, "result.txt")
export(df, "result.parquet")
export(list(var = df, id83 = df1), "WES.xlsx")
export(q, "query.parquet", collect = TRUE)
```

Styled Excel defaults remain. Every format refuses overwrite unless explicitly permitted and backed up. Overwrite replaces the whole file, not one sheet. Parquet uses a native sink (default zstd), not an intermediate R frame. Query execution still costs I/O and memory; CSV/TSV/XLSX export materializes results.

## 4. Processing

Clean first using explicit `distinct()`, `replace_na()` or `drop_na()` policies; do not automatically fill missing measurements with zero. `flag_iqr()` marks without deleting observations.

```r
by_row <- df |> mutate_row_stats(c(rep1, rep2, rep3))
by_group <- df |> summarise_numeric(c(rep1, rep2, rep3), .by = treatment)
```

Row statistics append row_n, row_mean and row_sd and return a LazyFrame. Replicates must have comparable units. Null/NaN are missing; an infinity invalidates that row's mean/SD; sample SD requires two finite values. `na_rm=FALSE` propagates missingness. Prefix collisions are errors, not overwrites. For ordinary tibbles, use `mutate(mean=mean(x), .by=group)` to broadcast column statistics and `bind_rows()` with explicit summary rows for presentation. Such summary rows are not raw observations.

Use tidypolars on lazy inputs for supported filter/mutate/pivot operations, not an automatic arbitrary-R translator. See the Chinese README for fully executed cleaning, broadcasting, appended rows and lazy examples; see version-specific validation for tested limits.
