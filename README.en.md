# evanxlsx

[中文](README.md) · [XLSX and sheets](#xlsx) · [CSV / TSV](#text) · [Parameters](#parameters) · [Integrations](#integration)

**Typical use: write two tables into two named sheets of one workbook.**

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
```

`evanxlsx` exports workbooks and provides four optional Polars data helpers. It does not define `evanxlsx::read_xlsx()` or `evanxlsx::write_csv()`. Use the established readers/writers below; their argument names differ.

| Task | Entry point | Result |
|---|---|---|
| Read a named/indexed XLSX sheet | `openxlsx2::read_xlsx(file, sheet)` | data.frame |
| Read an exact range/types | `openxlsx2::wb_to_df(file, sheet, dims, types)` | data.frame |
| Read XLS/XLSX into a tibble | `readxl::read_excel(path, sheet, col_types)` | tibble |
| Create a workbook with named sheets | `evanxlsx::write_xlsx()` | New workbook; protected by default |
| CSV/TSV with Tidy readers | `readr::read_csv/read_tsv`, `write_csv/write_tsv` | tibble / text file |
| CSV/TSV with data.table | `data.table::fread/fwrite` | data.table / text file |
| Lazy CSV/TSV/Parquet | `polars::pl$scan_csv/scan_parquet` | Polars LazyFrame |
| DuckDB data to Excel | duckplyr + `write_xlsx(collect = TRUE)` | Explicit backend execution |

## Install only the routes you use

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
```

This is a private repository: configure read access locally, never share or commit credentials. NA resolves mandatory dependencies, not all Suggests; always may update resolved dependencies. A pinned package commit does not pin its dependencies. Excel-only use directly requires only openxlsx2. Runtime functions never install software.

```r
# Optional file readers and Tidy integration
install.packages(c("readr", "readxl", "tibble", "dplyr", "tidyr", "stringr"))
# Optional alternative readers
install.packages(c("data.table", "vroom", "duckplyr"))
# Optional Polars data helpers and Tidy translation
install.packages(c("rlang", "tidyselect"))
Sys.setenv(NOT_CRAN = "true")
install.packages(c("polars", "tidypolars"),
                 repos = c("https://community.r-multiverse.org", "https://cloud.r-project.org"))
```

For a local R-built archive, `remotes::install_local(file.choose(), dependencies=NA, upgrade="always")` resolves missing dependencies online. Base `install.packages(..., repos=NULL)` does not download them. Restart R after updating packages already loaded in the session.

## Runnable synthetic fixture

Run the following sections in order. They use a new temporary directory; substitute your own paths/tables for real work. Values include Chinese/English, leading-zero and long text IDs, missing values, literal NA, empty strings, quotes, delimiters and newlines. Alternative routes are optional, not a requirement to install every package.

<!-- mirror: setup -->
```r
demo_dir <- tempfile("evanxlsx-io-")
stopifnot(dir.create(demo_dir))
df <- data.frame(
  Sample_ID = c(sprintf("%04d", 1:7), "123456789012345678"),
  treatment = rep(c("A", "B"), each = 4),
  height = c(80, 82, NA, 84, 90, 92, 94, 160),
  weight = c(2, 4, 6, 8, 4, 6, 8, NA),
  note = c("幼苗 Rice", NA, "NA", "", " 含空格 ",
           "逗号,与\"引号\"", "制表\t换行\n中文", "=1+1"),
  stringsAsFactors = FALSE
)
df1 <- data.frame(category = c("SYN_DEL", "SYN_INS"), count = c(3L, 2L))
```

<a id="xlsx"></a>
## XLSX: select sheets for reading and writing

### One frame, one named sheet

`sheet` controls a single object's sheet name. For a named list, list names take precedence and `sheet` is ignored.

<!-- mirror: xlsx_single -->
```r
evanxlsx::write_xlsx(
  df, file.path(demo_dir, "single.xlsx"),
  sheet = "var"
)
```

### Multiple sheets in one new workbook

<!-- mirror: xlsx_multi -->
```r
xlsx_file <- file.path(demo_dir, "WES.xlsx")
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  xlsx_file,
  font = "Times New Roman", font_size = 11,
  align = "center", freeze = TRUE, three_line = TRUE
)
```

List order is sheet order. Invalid or duplicate names cause an error, not silent renaming. Missing cells are value-less; literal NA remains text.

### List sheets and read by name/index

<!-- mirror: xlsx_read -->
```r
wb <- openxlsx2::wb_load(xlsx_file)
sheet_names <- unname(openxlsx2::wb_get_sheet_names(wb))
sheet_names
from_xlsx <- openxlsx2::read_xlsx(xlsx_file, sheet = "variant_info") |>
  tibble::as_tibble(.name_repair = "check_unique")
from_second <- openxlsx2::read_xlsx(xlsx_file, sheet = 2) |>
  tibble::as_tibble(.name_repair = "check_unique")
```

Prefer names when sheet order could change. A tibble discards reader-generated row-number rownames; meaningful gene/sample identifiers should already be explicit columns. Reuse `wb` to read multiple sheets without repeatedly loading the file:

<!-- mirror: xlsx_all -->
```r
all_sheets <- setNames(lapply(sheet_names, function(s) {
  openxlsx2::wb_to_df(wb, sheet = s) |>
    tibble::as_tibble(.name_repair = "check_unique")
}), sheet_names)
```

### Exact ranges and column types

<!-- mirror: xlsx_range -->
```r
part <- openxlsx2::wb_to_df(
  wb, sheet = "variant_info", dims = "A1:C4",
  col_names = TRUE, types = c(Sample_ID = 0),
  skip_empty_rows = FALSE, skip_empty_cols = FALSE,
  na = character()
) |> tibble::as_tibble(.name_repair = "check_unique")
```

| Reader parameter | Meaning |
|---|---|
| `sheet` | Name or 1-based sheet index |
| `dims` | Exact Excel coordinates; this range contains one header and three data rows |
| `start_row/start_col` | Starting point for data discovery, not an exact range |
| `rows/cols` | Spreadsheet row/column indices; include the intended header |
| `col_names` | First selected row is the header when TRUE |
| `types` | wb_to_df named types: 0 character, 1 numeric, 2 Date, 3 datetime, 4 logical |
| `na` | Additional values interpreted as missing; do not accidentally remove valid literal NA |
| `skip_empty_rows/cols` | TRUE drops entirely empty rows/columns and changes shape |
| `detect_dates` | Recognize date styles; it does not recover corrupted IDs |

Blank cells remain missing even with `na=character()`. Forcing character cannot reconstruct precision/zeros already lost upstream. Reading data does not retain all workbook styles, formulas, macros or objects. The reader is not a formula calculation engine.

### Alternative: readxl directly returns a tibble

<!-- mirror: readxl -->
```r
from_readxl <- readxl::read_excel(
  xlsx_file, sheet = "variant_info",
  col_types = c("text", "text", "numeric", "numeric", "text"),
  na = character(), trim_ws = FALSE,
  .name_repair = "check_unique"
)
```

Here types are positional and use `col_types`, not openxlsx2's `types`. `range="A1:C4"` selects a region; `skip=2` skips introductory rows when no exact range is used. readxl can collapse empty strings and blank cells into missing values; no lossless distinction is claimed. `trim_ws=FALSE` preserves whitespace. readxl reads but does not write workbooks.

### Creating a sheet is not updating an existing workbook

`overwrite=TRUE` replaces the **entire workbook**, after making a backup. It is not an append/replace-one-sheet mode. To append a new sheet to a simple existing workbook, load it using openxlsx2, add the sheet and save to a different path. The new sheet below uses ordinary openxlsx2 formatting, not automatic evanxlsx formatting.

<!-- mirror: append_sheet -->
```r
original_md5 <- tools::md5sum(xlsx_file)
wb_more <- openxlsx2::wb_load(xlsx_file)
stopifnot(!"extra_summary" %in% unname(openxlsx2::wb_get_sheet_names(wb_more)))
wb_more$add_worksheet("extra_summary")
wb_more$add_data("extra_summary", data.frame(n_records = nrow(df)), na = NULL)
wb_more$freeze_pane("extra_summary", first_row = TRUE)
wb_more$save(file.path(demo_dir, "WES_added.xlsx"), overwrite = FALSE)
stopifnot(identical(tools::md5sum(xlsx_file), original_md5))
```

For a **data-only reconstruction**, replacing one list element and writing a new workbook is explicit and simple. It does not preserve original formulas/styles/objects and is inappropriate for complex workbook templates:

<!-- mirror: replace_sheet_data -->
```r
replacement <- all_sheets
replacement[["id83"]] <- data.frame(category = "SYN_REVISED", count = 9L)
evanxlsx::write_xlsx(replacement, file.path(demo_dir, "WES_rebuilt.xlsx"))
```

<a id="text"></a>
## CSV / TSV read, write and conversion

Text files have no sheets or cell formatting. The sentinel `<MISSING>` in this fixture distinguishes missing values from empty strings and literal NA. Choose a sentinel absent from real nonmissing values; specify column types on import.

<!-- mirror: text_write -->
```r
col_spec <- readr::cols(
  Sample_ID = readr::col_character(), treatment = readr::col_character(),
  height = readr::col_double(), weight = readr::col_double(),
  note = readr::col_character()
)
csv_file <- file.path(demo_dir, "variants.csv")
tsv_file <- file.path(demo_dir, "variants.tsv")
readr::write_csv(df, csv_file, na = "<MISSING>")
readr::write_tsv(df, tsv_file, na = "<MISSING>", quote = "needed")
```

`quote="needed"` is deliberate for TSV: text may contain tabs/newlines/quotes. Unquoted output can break field boundaries. Readers outside R must support the same quoting protocol; do not silently change the original text to suit a reader.

<!-- mirror: text_read -->
```r
from_csv <- readr::read_csv(
  csv_file, col_types = col_spec, na = "<MISSING>",
  locale = readr::locale(encoding = "UTF-8"), trim_ws = FALSE
)
from_tsv <- readr::read_tsv(
  tsv_file, col_types = col_spec, na = "<MISSING>",
  locale = readr::locale(encoding = "UTF-8"), trim_ws = FALSE
)
stopifnot(nrow(readr::problems(from_csv)) == 0L,
          nrow(readr::problems(from_tsv)) == 0L)
```

`col_select=c(Sample_ID,height)` selects columns; `skip` skips introductory rows; `n_max` limits a preview, not a complete dataset. `show_col_types=FALSE` only hides a message. `locale` must match the real encoding. Writers' `append=FALSE` overwrites an existing text file; it is not a safety guard. Use a new path or check it first.

<!-- mirror: convert -->
```r
readr::write_tsv(from_csv, file.path(demo_dir, "csv_to_tsv.tsv"),
                 na = "<MISSING>", quote = "needed")
readr::write_csv(from_xlsx, file.path(demo_dir, "xlsx_to_csv.csv"), na = "<MISSING>")
evanxlsx::write_xlsx(from_tsv, file.path(demo_dir, "tsv_to_xlsx.xlsx"), sheet = "var")
readr::write_excel_csv(df, file.path(demo_dir, "utf8_for_excel.csv"), na = "<MISSING>")
```

`write_excel_csv()` is still CSV, with UTF-8 BOM. It does not provide worksheets or prevent Excel ID/date conversion or formula interpretation. Prefer XLSX when exact text IDs and explicit cell types matter. Renaming an extension is not format conversion.

<a id="parameters"></a>
## Exporter parameters

| Parameter | Default | Meaning |
|---|---|---|
| `x`, `file` | Required | Supported frame or named list; .xlsx destination |
| `sheet` | Sheet1 | Name for a single object; list names control multiple sheets |
| `font`, `font_size` | Times New Roman, 11 | Uniform font and pt size; fonts are not installed |
| `align` | center | Body center/left/right/justify |
| `header_align` | center | Independent header alignment |
| `valign` | center | center/top/bottom |
| `wrap` | TRUE | Wrapping, not guaranteed row autofit |
| `widths` | auto | Automatic, one fixed width, or a per-column vector |
| `max_width` | 40 | Automatic-width cap; ignored for numeric widths |
| `freeze`, `freeze_first_col` | TRUE, FALSE | First row and optional first column |
| `filter` | FALSE | Column filtering; not on header-only sheets |
| `three_line`, `grid_lines` | TRUE, FALSE | Three-line rules and screen grid visibility |
| `overwrite` | FALSE | Explicit whole-workbook replacement with backup |
| `collect` | FALSE | Permit pending backend execution |
| `max_rows` | 1048575L | Per-sheet returned data rows, excluding header; not a memory budget |

Font, size and body alignment can also be set via `evanxlsx.font`, `evanxlsx.font_size`, `evanxlsx.align` options. Explicit arguments win. Recovery is best-effort, not a concurrent-writer transaction.

<a id="integration"></a>
## Integrating other packages

### readr / dplyr

Ordinary tibbles still execute in R. Loading tidypolars alone does not move ordinary frames into Polars.

<!-- mirror: dplyr -->
```r
r_summary <- from_tsv |>
  dplyr::summarise(
    n_valid = sum(!is.na(height)),
    mean_height = mean(height, na.rm = TRUE),
    sd_height = sd(height, na.rm = TRUE),
    .by = treatment
  )
evanxlsx::write_xlsx(r_summary, file.path(demo_dir, "dplyr_summary.xlsx"), sheet = "summary")
```

### data.table and vroom

`fread()` uses `colClasses` and `na.strings`; `fwrite()` uses `sep`. These are not readr parameter names. See the Chinese README's fully executed [alternative reader recipes](README.md#integration) for fread/fwrite and vroom exports. Their data.frames/tibbles pass directly to `evanxlsx::write_xlsx()` without conversion to Polars.

### R Polars: scan, write CSV/TSV, Parquet, then Excel

<!-- mirror: polars_io -->
```r
pl <- polars::pl
pl_types <- list(Sample_ID = pl$String, treatment = pl$String,
                 height = pl$Float64, weight = pl$Float64, note = pl$String)
q_csv <- pl$scan_csv(csv_file, schema_overrides = pl_types,
                    null_values = "<MISSING>", empty_string_is_null = FALSE)
q_tsv <- pl$scan_csv(tsv_file, separator = "\t", schema_overrides = pl_types,
                    null_values = "<MISSING>", empty_string_is_null = FALSE)
p <- q_tsv$collect()  # 本例小表明确执行；不是全流程保持零内存占用
p$write_csv(file.path(demo_dir, "polars.csv"), null_value = "<MISSING>")
p$write_csv(file.path(demo_dir, "polars.tsv"), separator = "\t", null_value = "<MISSING>")
p$write_parquet(file.path(demo_dir, "variants.parquet"))
q_parquet <- pl$scan_parquet(file.path(demo_dir, "variants.parquet"))
evanxlsx::write_xlsx(list(csv = q_csv, tsv = q_tsv, parquet = q_parquet),
                     file.path(demo_dir, "polars_sources.xlsx"), collect = TRUE)
```

Reader `null_values` is plural; writer `null_value` is singular. TSV uses `write_csv(separator="\t")`, not a made-up native write_tsv method. The small fixture is explicitly collected for text output; this is not a streaming-XLSX claim. `q_tsv$explain()` records the plan.

### tidypolars and data helpers

Load tidypolars to register supported Tidy methods; set unknown arguments to error and disable hidden R fallback. The Chinese README's [executed integration](README.md#integration) demonstrates summarise_numeric, pivot_longer, key validation, pivot_wider, explicit annotation cleaning and multi-sheet output. Dynamic pivoting can execute before the final collection. Only annotation missingness is filled; measurements are not replaced by zero.

| Helper | Main arguments | Contract |
|---|---|---|
| summarise_numeric | .cols, .by=NULL, na_rm=TRUE | Counts plus mean/median/sample SD/type-7 quartiles |
| flag_iqr | .col, .by, k=1.5, min_n=4L, prefix | Annotate; never delete rows or infer unclassified cases are normal |
| separate_strict | col, into, sep, remove=FALSE, collect=FALSE | Literal separator, exact field count, leading zeros retained |
| assert_unique_keys | .cols, allow_missing=FALSE, collect=FALSE | Duplicate/missing keys cause errors, no guessed aggregation |

All return Polars LazyFrames. Existing grouped/rowwise input must be ungrouped before explicit .by. Lazy guards execute validation with permission. where() predicates are not supported. See `?evanxlsx::summarise_numeric` for numerical/missing/infinite-value rules.

### duckplyr

Duckplyr uses DuckDB, not Polars. Its CSV reader also accepts TSV through DuckDB options. Type declarations must follow the reader's nested-list interface.

<!-- mirror: duckplyr -->
```r
duck <- duckplyr::read_csv_duckdb(
  tsv_file, prudence = "stingy",
  options = list(
    delim = "\t", header = TRUE, nullstr = "<MISSING>",
    types = list(c(Sample_ID = "VARCHAR", treatment = "VARCHAR",
                   height = "DOUBLE", weight = "DOUBLE", note = "VARCHAR"))
  )
)
duck_summary <- duck |>
  dplyr::summarise(mean_height = mean(height, na.rm = TRUE), .by = treatment) |>
  dplyr::arrange(treatment)
evanxlsx::write_xlsx(duck_summary, file.path(demo_dir, "duckplyr.xlsx"),
                     sheet = "summary", collect = TRUE)
duck_small <- dplyr::collect(duck_summary)
readr::write_csv(duck_small, file.path(demo_dir, "duckplyr_summary.csv"))
readr::write_tsv(duck_small, file.path(demo_dir, "duckplyr_summary.tsv"), quote = "needed")
```

The exporter accepts duckplyr directly with permission. The optional Polars data helpers instead require an explicit upstream collection/conversion. Collecting a small summary here is not a recommendation to collect a huge raw query.

## Validation and documentation scope

This revision changes documentation/tests only; package runtime and version remain 0.3.1. Marked Chinese README code is executed directly; mirrored English code is byte-compared with it. Installation commands and user-input illustrations are parsed but not automatically executed. See [documentation acceptance](validation/README_IO_20261008.md) and [runtime acceptance](validation/STATUS_0.3.1.md).

GitHub shows repository HTML files as source, not a running website. Download an HTML guide or use `utils::browseURL(system.file("guide","usage.html",package="evanxlsx"))` after installation. For the existing complete installed workflow, source `system.file("examples","workflow.R",package="evanxlsx")` with UTF-8, then call `evanxlsx_workflow()`; it is an example, not an exported API.

Primary documentation: [openxlsx2](https://janmarvin.github.io/openxlsx2/reference/wb_to_df.html), [readxl](https://readxl.tidyverse.org/reference/read_excel.html), [readr](https://readr.tidyverse.org/reference/read_delim.html), [Polars scan](https://pola-rs.github.io/r-polars/man/pl__scan_csv.html), [duckplyr](https://duckplyr.tidyverse.org/reference/read_csv_duckdb.html).
