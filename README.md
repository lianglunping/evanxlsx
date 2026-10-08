# evanxlsx

[English](README.en.md) · [安装](#install) · [XLSX 读写与 sheet](#xlsx) · [CSV / TSV](#text) · [参数速查](#parameters) · [包间联动](#integration) · [常见问题](#faq)

**常用目标：把 `df` 和 `df1` 写进同一个 Excel 的两个指定工作表。**

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
```

读取指定 sheet 使用已经依赖的 `openxlsx2`，或可选的 `readxl`；CSV/TSV 使用 `readr`、`data.table` 或 Polars。不要把这些上游函数写成不存在的 `evanxlsx::read_xlsx()` / `evanxlsx::write_csv()`。

| 任务 | 推荐入口 | 返回对象 / 结果 |
|---|---|---|
| XLSX 指定 sheet 读取 | `openxlsx2::read_xlsx(file, sheet)` | `data.frame`；可再 `tibble::as_tibble()` |
| XLSX 精确范围、列类型 | `openxlsx2::wb_to_df(file, sheet, dims, types)` | `data.frame` |
| XLS / XLSX → tibble | `readxl::read_excel(path, sheet, col_types)` | tibble |
| 单表 / 多表 → 指定 sheet | `evanxlsx::write_xlsx(x, file, sheet)` / 命名 list | 新工作簿；默认不覆盖 |
| CSV / TSV ↔ tibble | `readr::read_csv/read_tsv`、`write_csv/write_tsv` | tibble / 文本文件 |
| CSV / TSV ↔ data.table | `data.table::fread/fwrite` | data.table / 文本文件 |
| CSV / TSV / Parquet → Polars 查询 | `polars::pl$scan_csv/scan_parquet` | LazyFrame |
| DuckDB 查询 → Excel | `duckplyr` + `write_xlsx(collect = TRUE)` | 显式执行查询后导出 |

本包公开函数为 `write_xlsx()`、`summarise_numeric()`、`flag_iqr()`、`separate_strict()`、`assert_unique_keys()`。均值/标准差、IQR、严格拆列与唯一键检查是可选数据模块；不重新实现一套 Tidy 编译器。

<a id="install"></a>
## 1. 安装：按实际使用范围选择

### 只使用 Excel 输出

```r
install.packages("remotes")  # 首次使用时
remotes::install_github(
  "lianglunping/evanxlsx",
  dependencies = NA,
  upgrade = "always"
)
```

仓库为私有，需要本机具备读取权限；不要把 Token 写进脚本或发到会话。`dependencies = NA` 安装必要依赖，不安装全部可选包；`upgrade = "always"` 可能更新相关依赖。固定本包提交不等于固定所有依赖版本。

已有依赖齐全时，本地 R 构建包可用 `install.packages(file.choose(), repos = NULL, type = "source")` 安装；需要补齐依赖时用 `remotes::install_local(file.choose(), dependencies = NA, upgrade = "always")`。后者下载依赖仍需要网络。升级已加载的包后重启 R。

### 只安装本页实际会使用的其他包

```r
# 常见文本/Excel读取及Tidy工作流
install.packages(c("readr", "readxl", "tibble", "dplyr", "tidyr", "stringr"))
# 替代读取路线：仅需要时安装
install.packages(c("data.table", "vroom", "duckplyr"))
# 本包四个可选数据函数需要
install.packages(c("rlang", "tidyselect"))
Sys.setenv(NOT_CRAN = "true")  # Polars安装会话允许使用预编译组件
install.packages(
  c("polars", "tidypolars"),
  repos = c("https://community.r-multiverse.org", "https://cloud.r-project.org")
)
```

不需要一次安装所有路线。普通导出唯一直接必需依赖仍是 `openxlsx2`。使用数据函数另需 `polars`、`rlang`、`tidyselect`；组合 Tidy 动词再加载 `tidypolars`。包不会在读取、计算或导出过程中自动安装软件。

<a id="demo"></a>
## 2. 准备一批能从头运行的示例数据

本页以下示例依次运行，使用新临时目录，**不会覆盖你的项目文件**。真实使用时把 `file.path(demo_dir, ...)` 改成输入/输出路径，把 `df`、`df1` 换成自己的表。示例含中文、长编号、前导零、`NA`、文本 `"NA"`、空字符串、引号、制表符与换行。

<!-- example: setup -->
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
## 3. XLSX：读取指定 sheet，输出指定 sheet

### 3.1 单个数据框 → 指定 sheet

用 `sheet` 命名新工作表。**输入为一个数据框时 `sheet` 有效；输入为 list 时由 list 的名称决定。**

<!-- example: xlsx_single -->
```r
evanxlsx::write_xlsx(
  df, file.path(demo_dir, "single.xlsx"),
  sheet = "var"
)
```

### 3.2 多个数据框 → 同一文件的不同 sheet

<!-- example: xlsx_multi -->
```r
xlsx_file <- file.path(demo_dir, "WES.xlsx")
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  xlsx_file,
  font = "Times New Roman", font_size = 11,
  align = "center", freeze = TRUE, three_line = TRUE
)
```

得到 `variant_info` 和 `id83`，list 顺序就是 sheet 顺序。单表默认名字为 `Sheet1`；非法/重复名称会报错，不自动改名。默认 NA 是无值单元格，文本 `"NA"` 保留。

### 3.3 查看 sheet 名称，按名称或序号读取

`wb_load()` 加载工作簿对象；`wb_get_sheet_names()` 列出名称；`read_xlsx()` 读取一个 sheet 的数据。名称比序号更能避免 sheet 重排导致读错。

<!-- example: xlsx_read -->
```r
wb <- openxlsx2::wb_load(xlsx_file)
sheet_names <- unname(openxlsx2::wb_get_sheet_names(wb))
sheet_names
from_xlsx <- openxlsx2::read_xlsx(xlsx_file, sheet = "variant_info") |>
  tibble::as_tibble(.name_repair = "check_unique")
from_second <- openxlsx2::read_xlsx(xlsx_file, sheet = 2) |>
  tibble::as_tibble(.name_repair = "check_unique")
```

**回读边界：**本次测试的 openxlsx2 1.29 和 readxl 会把单元格中的空字符串 `""` 与真正空单元格都读为 `NA`，即使写出时二者在XML中仍可区分。文本 `"NA"` 不受影响。需要严格保留空字符串/缺失的区别时，应保留原始RDS/Parquet或明确的文本缺失标记；不要把“XLSX写出正确”等同于任意读取器无损往返。

读多个 sheet 可复用已加载的 `wb`，避免反复加载同一个文件。`as_tibble()` 不保留读取器产生的 Excel 行号行名；真正的基因/样本 ID 应在数据列里。

<!-- example: xlsx_all -->
```r
all_sheets <- setNames(lapply(sheet_names, function(s) {
  openxlsx2::wb_to_df(wb, sheet = s) |>
    tibble::as_tibble(.name_repair = "check_unique")
}), sheet_names)
```

### 3.4 只读范围、指定列类型、处理缺失值

精确选区域使用 `wb_to_df()` 的 `dims`；更适合需要确保表头起点的表。这里 `A1:C4` 含一行表头和三行数据，`Sample_ID = 0` 指定为字符。

<!-- example: xlsx_range -->
```r
part <- openxlsx2::wb_to_df(
  wb, sheet = "variant_info", dims = "A1:C4",
  col_names = TRUE, types = c(Sample_ID = 0),
  skip_empty_rows = FALSE, skip_empty_cols = FALSE,
  na = character()
) |> tibble::as_tibble(.name_repair = "check_unique")
```

| 读取参数 | 如何设置 | 影响 |
|---|---|---|
| `sheet` | `"variant_info"` 或 `1` | 选择一个工作表；不存在时应先检查名称 |
| `dims` | `"B3:F100"` | Excel坐标区域；首行按 `col_names` 解释 |
| `start_row`, `start_col` | 如 `3`, `2` | 从该位置开始寻找数据；不等同于精确区域 |
| `rows`, `cols` | 如 `rows = c(1, 3, 5)`, `cols = c(1, 2)` | Excel行列编号，包含所需表头行；不是数据框行号 |
| `col_names` | 默认 `TRUE` | 区域第一行作为列名；无表头时设 `FALSE` |
| `types` | 如 `c(Sample_ID = 0, height = 1)` | `wb_to_df()` 的列类型代码：0字符，1数值，2日期，3日期时间，4逻辑 |
| `na` | 如 `character()`、`c("", "NA")` | 额外哪些内容视为缺失；不要误把有效文本 NA 转掉 |
| `skip_empty_rows/cols` | 默认 `FALSE` | 设TRUE会去掉全空行/列，改变表的形状 |
| `detect_dates` | 默认 `TRUE` | 根据工作簿类型/格式识别日期，不猜测基因名含义 |

空单元格仍会读为缺失；`na = character()` 不表示把空单元格读成有效值。强制字符类型**不能恢复上游已经丢失的前导零或长整数精度**。读值不等于保存整个工作簿的公式、样式与对象；读取器也不是公式计算引擎。详见[官方读取接口](https://janmarvin.github.io/openxlsx2/reference/wb_to_df.html)。

### 3.5 readxl 联动：直接得到 tibble

`readxl` 同时读取 `.xls` / `.xlsx`，不写 Excel；它的类型参数叫 `col_types`，不是 `types`。类型向量按实际列顺序指定，选取部分列后须对应调整。

<!-- example: readxl -->
```r
from_readxl <- readxl::read_excel(
  xlsx_file, sheet = "variant_info",
  col_types = c("text", "text", "numeric", "numeric", "text"),
  na = character(), trim_ws = FALSE,
  .name_repair = "check_unique"
)
```

`range = "A1:C4"` 可限定区域，`skip = 2` 可跳过两行说明；明确 `range` 时它优先于 `skip` 等自动范围设置。readxl 可能把空字符串与空单元格都读为缺失，本页不声称两者可无损区分。`trim_ws = FALSE` 保留有意义的空白。见[readxl参数](https://readxl.tidyverse.org/reference/read_excel.html)。

### 3.6 重要区别：指定 sheet ≠ 修改已有工作簿

| 目标 | 方法 | 注意 |
|---|---|---|
| 新建文件中的一个 sheet | `write_xlsx(df, new_file, sheet = "var")` | 本包直接支持 |
| 新建文件中的多个 sheet | `write_xlsx(list(var = df, id83 = df1), new_file)` | 本包直接支持 |
| 覆盖整个旧文件 | `overwrite = TRUE` | 先备份；**不是追加/替换其中某一个sheet** |
| 保留旧文件并追加新 sheet | `openxlsx2::wb_load()` → 加sheet → 另存新文件 | 上游接口；不是本包自动排版追加功能 |
| 数据型工作簿替换某张表后另存 | 读成命名list → 替换元素 → 写新文件 | 重建所有sheet，不保留原公式/样式对象 |

**追加示例：**只在新名称不存在时添加，保存为另一个文件。下例新sheet是 openxlsx2 的普通数据写入，不自动套用 evanxlsx 三线表样式。

<!-- example: append_sheet -->
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

**替换示例，仅适用数据表重建：**不要对包含需要保留的公式、宏、图表或命名区域的复杂工作簿套用此方法。

<!-- example: replace_sheet_data -->
```r
replacement <- all_sheets
replacement[["id83"]] <- data.frame(category = "SYN_REVISED", count = 9L)
evanxlsx::write_xlsx(replacement, file.path(demo_dir, "WES_rebuilt.xlsx"))
```

<a id="text"></a>
## 4. CSV / TSV：读取、输出与格式互转

### 4.1 先约定列类型与缺失值

CSV/TSV没有工作表、字体和冻结设置，也不存储完整R列类型。为了保留ID，读取时明确为字符。本例以不出现在有效数据中的 `<MISSING>` 表示缺失，区别于空字符串和文本 `NA`；真实数据必须先检查这个标记不与有效内容冲突。

<!-- example: text_write -->
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

这里特意设置TSV的 `quote = "needed"`：注释含制表符、引号或换行时，不加引号会破坏字段边界。不要认为写TSV永远可以 `quote = "none"`。需要与不支持带引号TSV的外部工具交换数据时，先明确字符转义协议，不静默替换原文。

### 4.2 分别读取 CSV、TSV

<!-- example: text_read -->
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

| 参数 | 用法 | 选择理由 |
|---|---|---|
| `col_types` | `readr::cols(ID = col_character(), value = col_double())` | 防止ID被数字化；未指定列仍可能推断类型 |
| `na` | 与写出时同一约定 | 默认/人为的NA标记可能与真实文字冲突 |
| `locale` | `locale(encoding = "UTF-8")` | 原文件必须实际为该编码；不是任意乱码修复开关 |
| `col_select` | 如 `c(Sample_ID, height)` | 仅保留需要的列，采用Tidy选择 |
| `skip`, `n_max` | 跳过说明行/最多读几行 | `n_max` 是预览限制，不能把它的结果当成全量统计 |
| `show_col_types` | `FALSE` | 只隐藏类型提示，不修复解析错误 |
| `quote`（写出） | `"needed"` | 对含分隔符、引号、换行的字段做正确引用 |
| `append`（写出） | 默认 `FALSE` | FALSE会改写已有文本文件；**不是防覆盖开关** |

本页所有文本输出都在新建目录。对真实输出路径，先检查 `!file.exists(output_file)` 或选新文件名。readr/fwrite/Polars的写出参数不共享 evanxlsx 的备份策略。不要用“把扩展名改为.xlsx”替代文件转换。

### 4.3 CSV / TSV / XLSX 互转

<!-- example: convert -->
```r
readr::write_tsv(from_csv, file.path(demo_dir, "csv_to_tsv.tsv"),
                 na = "<MISSING>", quote = "needed")
readr::write_csv(from_xlsx, file.path(demo_dir, "xlsx_to_csv.csv"), na = "<MISSING>")
evanxlsx::write_xlsx(from_tsv, file.path(demo_dir, "tsv_to_xlsx.xlsx"), sheet = "var")
readr::write_excel_csv(df, file.path(demo_dir, "utf8_for_excel.csv"), na = "<MISSING>")
```

`write_excel_csv()` 仍输出CSV，只加UTF-8 BOM帮助Excel识别编码，**不提供sheet，也不阻止Excel自动改变ID/日期或把以 `=` 开头的文本解释为公式**。重视编号和显示规则时优先交付XLSX；本包在XLSX中将普通的公式样字符串作为文本处理。CSV/TSV在R里回读成功不代表Excel双击打开同样安全。

<a id="parameters"></a>
## 5. `write_xlsx()` 参数速查

所有名称都是本包的参数，不是 `openxlsx` 老版驼峰参数。读取接口没有这里的字体/冻结参数。

| 参数 | 默认值 | 用法及影响 |
|---|---|---|
| `x` | 必填 | 单数据框/支持的后端对象，或命名list |
| `file` | 必填 | `.xlsx`路径；父目录应存在 |
| `sheet` | `"Sheet1"` | 单对象工作表名称；list时忽略，用list名字 |
| `font` | `"Times New Roman"` | 全表统一；可设`"Arial"`或`"SimSun"`/`"宋体"`，不安装字体 |
| `font_size` | `11` | 磅数，支持1–409 |
| `align` | `"center"` | 数据区`center/left/right/justify` |
| `header_align` | `"center"` | 表头独立对齐；数据靠左不自动改变表头 |
| `valign` | `"center"` | 垂直`center/top/bottom` |
| `wrap` | `TRUE` | 文本换行；不能保证所有Excel版本自动调整行高 |
| `widths` | `"auto"` | 自动、一个数值如18、或每列一个数值；多表向量必须匹配各表列数 |
| `max_width` | `40` | 自动列宽上限；固定数值widths时完全忽略 |
| `freeze` | `TRUE` | 冻结第一行 |
| `freeze_first_col` | `FALSE` | 冻结第一列，可独立使用 |
| `filter` | `FALSE` | 加列筛选；空表不加筛选 |
| `three_line` | `TRUE` | 顶线、表头下线、底线；无数据时只剩两条外线 |
| `grid_lines` | `FALSE` | Excel界面是否显示网格线 |
| `overwrite` | `FALSE` | TRUE替换整个文件且先备份，不是替换单sheet |
| `collect` | `FALSE` | 显式允许duckplyr/Polars LazyFrame查询执行 |
| `max_rows` | `1048575L` | 每sheet数据行上限，不含表头；超限报错，不截断；不是内存保证 |

`font`、`font_size`、`align` 也可用会话级 `options(evanxlsx.font = "Arial", evanxlsx.font_size = 12, evanxlsx.align = "left")` 设置默认值；显式传参优先。数字/日期等对应openxlsx2全局格式已在写出期间局部隔离，退出后恢复。失败恢复是尽力而为，不是多进程事务锁。

<!-- example: formatting -->
```r
evanxlsx::write_xlsx(
  df, file.path(demo_dir, "formatted.xlsx"), sheet = "中文 表",
  font = "Arial", font_size = 12,
  align = "left", header_align = "center", valign = "top",
  widths = 18, wrap = TRUE, freeze = TRUE, freeze_first_col = TRUE,
  filter = TRUE, three_line = TRUE, grid_lines = FALSE
)
```

<a id="integration"></a>
## 6. 与其他包联动

### 6.1 readr / tibble / dplyr → Excel

读取函数返回普通tibble时，以下 `dplyr` 汇总仍在R中计算。要Polars执行，见6.3；加载tidypolars不会自动切换普通数据框的引擎。

<!-- example: dplyr -->
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

### 6.2 data.table / vroom → Excel，以及文本输出

`fread()` 的类型参数是 `colClasses`，缺失参数是 `na.strings`；不要与readr参数名混用。`fwrite()` 的分隔符参数是 `sep`，TSV应明确为制表符。

<!-- example: data_table -->
```r
# fread示例只选择编号、分组与测量列
measure_cols <- c("Sample_ID", "treatment", "height", "weight")
dt_measures <- data.table::fread(
  tsv_file, sep = "\t", select = measure_cols,
  encoding = "UTF-8", na.strings = "<MISSING>",
  colClasses = c(Sample_ID = "character", treatment = "character",
                 height = "numeric", weight = "numeric"),
  strip.white = FALSE
)
# 含复杂引号/换行的完整注释表：复用已验收的readr结果
# as.data.table()转换已有对象，不再次解析文本
dt <- data.table::as.data.table(from_tsv)
evanxlsx::write_xlsx(dt, file.path(demo_dir, "fread.xlsx"), sheet = "var")
data.table::fwrite(dt, file.path(demo_dir, "fwrite.csv"), sep = ",", na = "<MISSING>")
data.table::fwrite(dt, file.path(demo_dir, "fwrite.tsv"), sep = "\t", na = "<MISSING>")
```

**读取器差异：**本次 data.table 1.18.6.1 对测试TSV的内嵌双引号保留为两重引号，未与原始文字一致。因此这里不宣称任意复杂注释经fread无损读取，也不擅自用全局替换修复文字。编号/测量列可按上例选择；需要完整注释时采用readr读取后转data.table。fwrite输出仍独立回读核验。

<!-- example: vroom -->
```r
from_vroom <- vroom::vroom(
  tsv_file, delim = "\t", col_types = col_spec, na = "<MISSING>",
  trim_ws = FALSE, show_col_types = FALSE
)
evanxlsx::write_xlsx(from_vroom, file.path(demo_dir, "vroom.xlsx"), sheet = "var")
```

### 6.3 R Polars：CSV / TSV延迟读取、文本写出、Parquet

以下是 **R `polars` 包**，不是Python API。用 `schema_overrides` 明确ID/测量类型；`separator` 是单字节分隔符；空字符串是否视为缺失也显式指定。本例不忽略解析错误。

<!-- example: polars_io -->
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

`infer_schema_files = 10` 明确多文件类型推断范围，避免依赖将来版本的默认值；本例单文件且指定全部列类型。CSV扫描用 `null_values`（复数），CSV写出用 `null_value`（单数）。原生Polars方法不是 `write_tsv()`，而是 `write_csv(separator = "\t")`。本例写文本前显式collect；大数据应选择适合的持久化方案，不将本例当作流式XLSX。`q_tsv$explain()` 可查看计划。

### 6.4 tidypolars + 本包数据函数 → 多sheet

安装并加载 `tidypolars` 后才能注册相应Tidy方法；通过 `requireNamespace()` 加载可以避免附加包名冲突。严格模式遇到不支持参数报错，禁止静默回退R。

<!-- example: tidy_polars -->
```r
stopifnot(requireNamespace("tidypolars", quietly = TRUE))
old_tidy_options <- options(tidypolars_unknown_args = "error", tidypolars_fallback_to_r = FALSE)
metrics <- q_tsv |> evanxlsx::summarise_numeric(c(height, weight), .by = treatment)
long <- q_tsv |>
  tidyr::pivot_longer(c(height, weight), names_to = "trait", values_to = "value") |>
  dplyr::arrange(Sample_ID, trait)
wide <- long |>
  evanxlsx::assert_unique_keys(c(Sample_ID, trait), collect = TRUE) |>
  tidyr::pivot_wider(id_cols = c(Sample_ID, treatment), names_from = trait, values_from = value) |>
  dplyr::arrange(Sample_ID)
clean <- q_tsv |>
  dplyr::mutate(note = stringr::str_trim(note)) |>
  tidyr::replace_na(list(note = "Unknown / 未记录"))
evanxlsx::write_xlsx(list(summary = metrics, long = long, wide = wide, clean = clean),
                     file.path(demo_dir, "tidy_polars.xlsx"), collect = TRUE)
options(old_tidy_options)
```

这里填补的是注释，不是测量值；`str_trim()` 是明确的去首尾空白操作。动态长转宽可能提前执行，不能笼统说所有步骤都完全延迟。重复键先检查，不默认求均值。`fill(..., .by = ..., .direction = "down")` 应在显式排序后使用，不能跨样本填充。更多原有场景见[完整工作流源码](inst/examples/workflow.R)。

### 6.5 duckplyr：TSV读取、汇总、Excel和CSV/TSV输出

`read_csv_duckdb()` 也能读TSV，在 `options` 中指定DuckDB的 `delim`。`types` 按该接口要求提供 `list(c(...))`；`prudence = "stingy"` 不允许意外自动取回R，导出时再明确 `collect = TRUE`。

<!-- example: duckplyr -->
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

duckplyr使用DuckDB，不是Polars。把它传给本包的Excel导出可以直接适配；传给四个Polars数据函数时要先显式collect为普通表，避免猜测引擎切换。不要将小汇总取回R的示例用于未经筛选的超大表。

## 7. 四个数据函数的必要参数

| 函数 | 常用调用 | 参数与边界 |
|---|---|---|
| `summarise_numeric()` | `summarise_numeric(df, c(height, weight), .by = treatment)` | `.cols`测量列，`.by`分组，`na_rm=TRUE`；返回总数/有限数/缺失/Inf计数和均值、中位数、样本SD、Q1/Q3/IQR |
| `flag_iqr()` | `flag_iqr(df, height, .by = treatment)` | 单列`.col`；`k=1.5`，`min_n=4L`，`prefix="iqr"`；仅标记不删行；少样本/零IQR等为NA并有原因 |
| `separate_strict()` | `separate_strict(df, locus, c("Chr", "Position"), ":")` | `sep`是字面分隔符；默认`remove=FALSE`；LazyFrame验证需`collect=TRUE`，字段不符报错 |
| `assert_unique_keys()` | `assert_unique_keys(df, c(Sample_ID, trait))` | 默认`allow_missing=FALSE`；检查重复/缺失组合，LazyFrame需允许验证执行 |

都返回Polars LazyFrame；已有 `group_by()`/`rowwise()` 输入须先 `ungroup()`，再用`.by`。支持裸列名、`c()`、`all_of()`、`starts_with()`，暂不支持`where()`。分位数用linear/type7，SD为样本SD；NA/NaN统一缺失，Inf使所在组描述统计缺失并记录计数，不是自动填补。完整细则可在R中 `?evanxlsx::summarise_numeric` 或 `?evanxlsx::write_xlsx` 查看。

<a id="faq"></a>
## 8. 常见错误与最小检查

| 问题 | 先检查什么 |
|---|---|
| `argument 3 is empty` | `list()`最后一项后面不要多逗号 |
| Sheet不存在/读错表 | 先列出实际名称，优先按名字读取；readxl用`sheet`，不是`sheet_name` |
| ID变成数字或去掉前导零 | 在读取前设字符类型；保存后再转字符无法恢复已丢失精度 |
| 读取文字NA变成缺失 | 明确各读取器的NA标记；CSV/TSV与XLSX空值口径不同 |
| TSV列数错位 | 字段可能包含制表符/换行；写出应正确quote，读取采用一致协议 |
| 输出文件已存在 | 默认保护；换新路径。不要用overwrite当作“只更新一个sheet” |
| 本地装包缺依赖 | `repos=NULL`不会下载依赖；用支持依赖解析的安装器或先安装必要包 |
| `collect = TRUE` 报错提示 | 输入是待执行后端；明确是否允许加载结果，并用max_rows约束返回规模 |
| 字体未生效 | 写入的是字体名称，目标电脑需安装该字体；本包不分发字体 |
| GitHub点开HTML显示源码 | GitHub仓库不会把任意HTML当网页执行；下载后浏览器打开，或安装后用下方命令 |

```r
utils::browseURL(system.file("guide", "usage.html", package = "evanxlsx"))
source(system.file("examples", "workflow.R", package = "evanxlsx"), encoding = "UTF-8")
result <- evanxlsx_workflow()
result$path
```

上面是另一个已安装的完整合成示例，并非新增的 `evanxlsx::evanxlsx_workflow()` 函数。只source不会立即运行。

## 9. 示例测试、版本与来源

本次仅补README、跨包读写示例与文档测试，**未修改运行函数、公开参数或包版本（仍为0.3.1）**。本页带隐藏example标记的代码块由 `Rscript tools/readme_check.R` 直接提取执行，不另外维护一份不同的“测试专用用法”。安装指令和需要用户自己的df/文件的开头短例不在自动执行范围。

[本次文档测试记录](validation/README_IO_20261008.md) · [0.3.1运行实现验收](validation/STATUS_0.3.1.md)

官方接口： [openxlsx2读取](https://janmarvin.github.io/openxlsx2/reference/wb_to_df.html)、[sheet名称](https://janmarvin.github.io/openxlsx2/reference/sheet_names-wb.html)、[readxl](https://readxl.tidyverse.org/reference/read_excel.html)、[readr读取](https://readr.tidyverse.org/reference/read_delim.html)、[readr写出](https://readr.tidyverse.org/reference/write_delim.html)、[fread](https://rdatatable.gitlab.io/data.table/reference/fread.html)、[R Polars扫描](https://pola-rs.github.io/r-polars/man/pl__scan_csv.html)、[R Polars写出](https://pola-rs.github.io/r-polars/man/dataframe__write_csv.html)、[duckplyr读取](https://duckplyr.tidyverse.org/reference/read_csv_duckdb.html)。
