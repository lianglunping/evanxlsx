# evanxlsx

[中文](README.md) · [XLSX](#xlsx) · [CSV / TSV](#text) · [Parameters](#parameters) · [Integrations](#integration)

Write two frames to two named sheets:

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
```

`evanxlsx` does not define `read_xlsx()` or `write_csv()`. Use openxlsx2/readxl for Excel reads, readr/data.table/vroom for text reads, and R Polars or duckplyr for their respective engines. The package's five public functions are write_xlsx, summarise_numeric, flag_iqr, separate_strict and assert_unique_keys.

## Installation

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
```

Private access requires locally configured read credentials; never share them. NA installs mandatory dependencies, not every optional package. Always may update resolved dependencies. A pinned commit does not freeze the dependency environment. Local archives can use remotes::install_local(file.choose(), dependencies=NA, upgrade="always"); base install.packages(repos=NULL) does not download dependencies.

```r
# Optional I/O and Tidy packages; install only the routes you need.
install.packages(c("readr", "readxl", "tibble", "dplyr", "tidyr", "stringr"))
install.packages(c("data.table", "vroom", "duckplyr"))
install.packages(c("rlang", "tidyselect"))
Sys.setenv(NOT_CRAN = "true")
install.packages(c("polars", "tidypolars"),
                 repos = c("https://community.r-multiverse.org", "https://cloud.r-project.org"))
```

Excel-only use directly requires just openxlsx2. Data helpers also require Polars, rlang and tidyselect. Standard Tidy verbs on Polars require tidypolars and their owning packages. Runtime functions never install software.

## Runnable fixture

Run the following marked examples in order, in a fresh R session. All outputs use a new temporary directory. Replace the paths/data for actual work. This is deterministic synthetic data with Chinese/English, long and leading-zero IDs, nulls, empty text and embedded delimiters.

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
## XLSX reading and named-sheet writing

### One sheet or several sheets

`sheet` names a single object's sheet. With a named list, its names control worksheets and `sheet` is ignored.

<!-- mirror: xlsx_single -->
```r
evanxlsx::write_xlsx(
  df, file.path(demo_dir, "single.xlsx"),
  sheet = "var"
)
```

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

List order is sheet order. Invalid/duplicate names cause errors, not silent renaming.

### List and select sheets

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

Prefer sheet names when order can change. The tested openxlsx2 1.29 and readxl readers collapse empty-string cells and value-less cells to NA, even though the writer preserves the distinction in XML. Literal NA stays text. Retain source RDS/Parquet or use a documented text sentinel when empty strings and missingness must remain distinct. Forcing character cannot restore zeros or precision already lost upstream.

Reuse a loaded workbook to read all sheets:

<!-- mirror: xlsx_all -->
```r
all_sheets <- setNames(lapply(sheet_names, function(s) {
  openxlsx2::wb_to_df(wb, sheet = s) |>
    tibble::as_tibble(.name_repair = "check_unique")
}), sheet_names)
```

### Exact regions and types

<!-- mirror: xlsx_range -->
```r
part <- openxlsx2::wb_to_df(
  wb, sheet = "variant_info", dims = "A1:C4",
  col_names = TRUE, types = c(Sample_ID = 0),
  skip_empty_rows = FALSE, skip_empty_cols = FALSE,
  na = character()
) |> tibble::as_tibble(.name_repair = "check_unique")
```

| Parameter | Meaning |
|---|---|
| sheet | Name or 1-based index |
| dims | Exact Excel range; A1:C4 includes one header and three data rows |
| start_row/start_col | Discovery start, not an exact rectangular range |
| rows/cols | Spreadsheet indices, including the desired header row |
| col_names | Interpret first selected row as names |
| types | wb_to_df type codes: 0 character, 1 numeric, 2 Date, 3 datetime, 4 logical |
| na | Additional values treated as missing; do not remove valid NA text |
| skip_empty_rows/cols | TRUE removes wholly empty rows/columns and changes shape |
| detect_dates | Interpret date styles; does not repair identifiers |

The reader is not a formula engine. Reading values cannot preserve every formula, style, macro or other workbook object. Blank cells remain missing with na=character(). as_tibble removes reader-generated rownames, so meaningful IDs should be explicit data columns.

### Alternative reader: readxl returns a tibble

<!-- mirror: readxl -->
```r
from_readxl <- readxl::read_excel(
  xlsx_file, sheet = "variant_info",
  col_types = c("text", "text", "numeric", "numeric", "text"),
  na = character(), trim_ws = FALSE,
  .name_repair = "check_unique"
)
```

readxl reads both XLS and XLSX but does not write them. Its types are positional and use col_types, not openxlsx2's types. range="A1:C4" selects an exact region; skip=2 skips introductory rows when no range is supplied. trim_ws=FALSE preserves whitespace. Empty strings can become missing, as above.

### Appending to a copy versus replacing the entire workbook

`overwrite=TRUE` replaces the **whole file** after a backup; it is not an append/replace-one-sheet mode. For adding a sheet, use openxlsx2 and save to a different file. Its new sheet below does not automatically receive evanxlsx's style.

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

For **data-only reconstruction**, replace a list element and write to a new path. This discards original formatting/formula structures and is not appropriate for complex templates:

<!-- mirror: replace_sheet_data -->
```r
replacement <- all_sheets
replacement[["id83"]] <- data.frame(category = "SYN_REVISED", count = 9L)
evanxlsx::write_xlsx(replacement, file.path(demo_dir, "WES_rebuilt.xlsx"))
```

<a id="text"></a>
## CSV / TSV reading, writing and conversion

Text files have no sheets, fonts or complete type metadata. This fixture uses a sentinel absent from valid values to distinguish NA from empty text and literal NA; choose and validate your convention before import/export.

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

quote="needed" is deliberate: annotations contain tabs, quotes and newlines. Unquoted TSV may break record boundaries; other tools need compatible quoting or a separately specified exchange protocol.

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

col_types protects IDs; locale must match the real encoding. col_select selects columns, skip skips lines, and n_max is a preview limit, not a full dataset. show_col_types=FALSE only hides a message. Writers' append=FALSE can overwrite an existing file; it is not a safety guard. Use fresh paths.

<!-- mirror: convert -->
```r
readr::write_tsv(from_csv, file.path(demo_dir, "csv_to_tsv.tsv"),
                 na = "<MISSING>", quote = "needed")
readr::write_csv(from_xlsx, file.path(demo_dir, "xlsx_to_csv.csv"), na = "<MISSING>")
evanxlsx::write_xlsx(from_tsv, file.path(demo_dir, "tsv_to_xlsx.xlsx"), sheet = "var")
readr::write_excel_csv(df, file.path(demo_dir, "utf8_for_excel.csv"), na = "<MISSING>")
```

write_excel_csv produces CSV with a UTF-8 BOM, not an XLSX workbook. It cannot prevent Excel's type conversion or formula interpretation when double-clicked. Prefer typed XLSX for identifiers and potentially formula-like text. Changing a filename extension is not conversion.

<a id="parameters"></a>
## Export parameters

| Parameter | Default | Meaning |
|---|---|---|
| x, file | Required | Frame or named list; .xlsx destination in an existing directory |
| sheet | Sheet1 | Single-object sheet name; list names control multiple sheets |
| font, font_size | Times New Roman, 11 | Uniform font and pt size; font files not installed |
| align | center | Data center/left/right/justify |
| header_align | center | Independent header alignment |
| valign | center | center/top/bottom |
| wrap | TRUE | Wrap text, not guaranteed row autofit |
| widths | auto | Automatic, one width, or per-column widths matching every sheet |
| max_width | 40 | Automatic-width cap, ignored for numeric widths |
| freeze, freeze_first_col | TRUE, FALSE | Freeze row and optional first column |
| filter | FALSE | Header filtering, omitted for header-only sheets |
| three_line, grid_lines | TRUE, FALSE | Table rules and on-screen grid visibility |
| overwrite | FALSE | Explicit whole-file replacement with backup |
| collect | FALSE | Permission to execute backend queries |
| max_rows | 1048575L | Per-sheet data-row cap excluding header; not an engine memory budget |

Defaults can use evanxlsx.font/font_size/align options; explicit arguments take precedence. Reader parameters are not interchangeable with writer formatting parameters. File recovery is best-effort, not a concurrent transaction.

<a id="integration"></a>
## Integrations

### Ordinary readr/tibble/dplyr

Ordinary dataframes still calculate in R. Loading tidypolars alone does not switch their engine.

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

### data.table/vroom

The [Chinese README's executed examples](README.md#integration) provide fread/fwrite and vroom routes. fread uses colClasses/na.strings, not readr argument names. In data.table 1.18.6.1 our quoted TSV annotation probe retained doubled embedded quotes. Its demonstrated fread route therefore selects IDs/measurements; the full annotated table uses readr followed by as.data.table(), without guessed text repair. fwrite outputs are separately checked. vroom returns a tibble that the exporter accepts directly.

### Polars scans and writes

<!-- mirror: polars_io -->
```r
pl <- polars::pl
pl_types <- list(Sample_ID = pl$String, treatment = pl$String,
                 height = pl$Float64, weight = pl$Float64, note = pl$String)
q_csv <- pl$scan_csv(csv_file, schema_overrides = pl_types,
                    null_values = "<MISSING>", empty_string_is_null = FALSE,
                    infer_schema_files = 10)
q_tsv <- pl$scan_csv(tsv_file, separator = "\t", schema_overrides = pl_types,
                    null_values = "<MISSING>", empty_string_is_null = FALSE,
                    infer_schema_files = 10)
p <- q_tsv$collect()  # 本例小表明确执行；不是全流程保持零内存占用
p$write_csv(file.path(demo_dir, "polars.csv"), null_value = "<MISSING>")
p$write_csv(file.path(demo_dir, "polars.tsv"), separator = "\t", null_value = "<MISSING>")
p$write_parquet(file.path(demo_dir, "variants.parquet"))
q_parquet <- pl$scan_parquet(file.path(demo_dir, "variants.parquet"))
evanxlsx::write_xlsx(list(csv = q_csv, tsv = q_tsv, parquet = q_parquet),
                     file.path(demo_dir, "polars_sources.xlsx"), collect = TRUE)
```

R Polars uses separator for TSV, null_values for reading and singular null_value for writing. infer_schema_files=10 avoids relying on a changing default. This one-file fixture declares every column type. Text output explicitly collects a small table; it is not streaming-XLSX. q_tsv$explain() displays the native plan.

### tidypolars and optional data helpers

Load tidypolars to register its Tidy methods; unknown arguments should error, with no hidden R fallback. The [executed Chinese workflow](README.md#integration) includes summaries, pivot_longer, key checking, pivot_wider and annotation trimming/NA replacement. It does not fill measurement values. Dynamic pivoting may execute early.

| Helper | Important arguments and limits |
|---|---|
| summarise_numeric | .cols/.by/na_rm; counts plus mean, median, sample SD, linear quartiles |
| flag_iqr | One .col; k=1.5/min_n=4L/prefix; flags and reasons, never deletes rows |
| separate_strict | col/into/sep/remove; literal separator, exact fields and text IDs |
| assert_unique_keys | .cols/allow_missing; rejects duplicates, no guessed pivot aggregation |

All return Polars LazyFrames. Ungroup existing grouped/rowwise input before using .by. Lazy guards need explicit validation permission. where() predicates are unsupported. See R help for complete missing/infinite/numeric rules.

### duckplyr uses DuckDB, not Polars

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

The nested types list follows duckplyr's interface. Explicit collection of a small summary is not a recommendation to load a huge raw query. The exporter accepts duckplyr directly with permission, while the Polars data helpers require an explicit upstream conversion.

## Tests, help and sources

This is a documentation-only revision: runtime, public APIs, version 0.3.1 and dependencies are unchanged. Tests execute tagged Chinese README code directly and compare mirrored English snippets. Install commands and user-input illustrations are parsed, not executed automatically. Reader-specific behavior is explicitly checked separately from exact workbook XML. See [README acceptance](validation/README_IO_20261008.md) and [runtime acceptance](validation/STATUS_0.3.1.md).

GitHub displays repository HTML as source. Download it to a browser or use utils::browseURL(system.file("guide","usage.html",package="evanxlsx")) after installation. The installed workflow.R example can be sourced and called as evanxlsx_workflow(); it is not a new exported API.

Primary sources: [openxlsx2](https://janmarvin.github.io/openxlsx2/reference/wb_to_df.html), [readxl](https://readxl.tidyverse.org/reference/read_excel.html), [readr](https://readr.tidyverse.org/reference/read_delim.html), [Polars scan](https://pola-rs.github.io/r-polars/man/pl__scan_csv.html), [duckplyr](https://duckplyr.tidyverse.org/reference/read_csv_duckdb.html).
