# evanxlsx

**Read with `import()`, write with `export()`. The extension selects the format.**

## 1. Installation

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
library(evanxlsx)
```

Required IO dependencies are installed automatically. Private GitHub access requires a local credential; dependency upgrades may occur. The two unified functions require version 0.4.0.

## 2. Read data

```r
df <- import("data.xlsx", sheet = "var")
df_txt <- import("data.txt")
df_tsv <- import("data.tsv")
df_csv <- import("data.csv")
df1 <- import("data.xlsx", sheet = "id83")
```

Every import returns a tibble. XLSX defaults to the first sheet; CSV uses commas, TXT/TSV use tabs. Use `sheet` for a name/index, `sep` for a different delimiter, and `text_cols = "Sample_ID"` to protect identifiers. The default missing marker is blank; literal `"NA"` is retained. Text is UTF-8 with inferred types. Empty strings and missing spreadsheet cells can both read as NA. Text formats do not store complete R type information.

## 3. Write data

```r
export(df, "result.xlsx", sheet = "var")
export(df, "result.txt")
export(df, "result.tsv")
export(df, "result.csv")
export(list(var = df, id83 = df1), "WES.xlsx")
export(df, "styled.xlsx", font = "Arial", font_size = 12, align = "left")
```

Excel retains the existing default font, blank missing values, frozen header and three-line borders. All formats refuse overwrite by default. `overwrite = TRUE` backs up and replaces the whole file, not one sheet. `sep` and `na` customize text output. Text files contain one table and no Excel formatting. Lazy Polars/duckplyr input needs `collect = TRUE`. Existing `write_xlsx()` calls still work.

## 4. Process data

Only this optional section needs Polars, rlang and tidyselect installed separately.

```r
summary <- df |> summarise_numeric(c(height, weight), .by = treatment)
export(summary, "summary.xlsx", collect = TRUE)
flagged <- df |> flag_iqr(height, .by = treatment)
parts <- df |> separate_strict(locus, c("Chr", "Position"), sep = ":")
```

Helpers return Polars LazyFrames; flags never delete rows. Reuse tidypolars for general reshaping, cleaning and filling. Detailed parameters are in `?import`, `?export` and each helper's help page. With packages exporting the same names, use `evanxlsx::import()` and `evanxlsx::export()` explicitly.
