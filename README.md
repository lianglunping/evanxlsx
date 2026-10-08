# evanxlsx

**读入用 `import()`，输出用 `export()`。文件格式由扩展名自动识别。**

## 1、包的安装

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
library(evanxlsx)
```

安装时自动处理读写所需依赖；私有仓库需要本机读取权限。`upgrade = "always"` 可能更新相关依赖。已经安装旧版时需更新到 **0.4.0** 才能使用下面两个入口。

## 2、数据读取

<!-- example: import -->
```r
df     <- import("data.xlsx", sheet = "var")
df_txt <- import("data.txt")
df_tsv <- import("data.tsv")
df_csv <- import("data.csv")
```

统一返回 tibble。默认读取 Excel 第一张表；CSV 按逗号分隔，TXT／TSV 按制表符分隔。

| 常用参数 | 用法 |
|---|---|
| `sheet` | Excel 工作表名称或序号，例如 `"var"`、`2` |
| `sep` | 文本分隔符，例如 `","`、`";"`、`" "` |
| `text_cols` | 必须保持为字符的列，例如 `"Sample_ID"`，保护前导零和长编号 |
| `na` | 文本缺失标记；默认空白，文本 `"NA"` 保留 |

<!-- example: import_options -->
```r
df1 <- import("data.xlsx", sheet = "id83")
df_id <- import("data.csv", text_cols = "Sample_ID")
```

例如逗号分隔的 TXT 使用 `import("data.txt", sep = ",")`。文本文件默认 UTF-8，类型自动推断；重要编号建议指定 `text_cols`。空字符串与空白单元格读入时可能都成为 `NA`，文本格式不保存完整的 R 类型信息。

## 3、数据输出

<!-- example: export -->
```r
export(df, "result.xlsx", sheet = "var")
export(df, "result.txt")
export(df, "result.tsv")
export(df, "result.csv")

# 同一个 Excel，不同 sheet
export(list(var = df, id83 = df1), "WES.xlsx")
```

Excel 默认统一 Times New Roman、11 磅、居中、缺失值留空、冻结首行和三线表。文本输出默认 UTF-8，TXT／TSV 使用制表符，CSV 使用逗号。

<!-- example: export_options -->
```r
export(df, "styled.xlsx", font = "Arial", font_size = 12, align = "left")
```

| 常用参数 | 用法 |
|---|---|
| `sheet` | 单表的 sheet 名称；多表用命名 list |
| `font` / `font_size` | Excel 字体和字号，例如 `"SimSun"`、`12` |
| `align` | Excel 对齐：`"center"`、`"left"`、`"right"`、`"justify"` |
| `sep` / `na` | 文本分隔符与缺失标记，默认与读取一致 |
| `overwrite` | 默认 `FALSE`；`TRUE` 会先备份再替换**整个文件**，不是追加 sheet |
| `collect` | 输入为 Polars／duckplyr 延迟查询时明确设为 `TRUE` |

例如 `export(df, "result.xlsx", overwrite = TRUE)`。TXT／TSV／CSV 只输出一张表；字体、sheet 等设置仅用于 Excel。旧的 `write_xlsx()` 仍可使用，无需修改旧脚本。

## 4、数据处理

这一节是可选功能；仅做读写不需要安装 Polars。首次使用时：

```r
install.packages(c("rlang", "tidyselect"))
Sys.setenv(NOT_CRAN = "true")
install.packages("polars", repos = c("https://community.r-multiverse.org", "https://cloud.r-project.org"))
```

<!-- example: process -->
```r
# 分组汇总：数量、均值、中位数、标准差、Q1、Q3、IQR
summary <- df |> summarise_numeric(c(height, weight), .by = treatment)
export(summary, "summary.xlsx", collect = TRUE)

# IQR 只标记，不删除数据
flagged <- df |> flag_iqr(height, .by = treatment)

# 严格拆列；列中字段数量不一致时报错
parts <- df |> separate_strict(locus, c("Chr", "Position"), sep = ":")
```

这些函数返回 Polars 查询，计算在 Polars 后端执行；需要查看小结果时用 `as.data.frame(summary$collect())`。长宽转换、清洗与补值继续使用 `tidypolars` 的相应 Tidy 动词，不再重复封装。

详细参数直接查看 `?import`、`?export`、`?summarise_numeric`、`?flag_iqr`、`?separate_strict`、`?assert_unique_keys`。与 bruceR 等包同时加载时，用 `evanxlsx::import()`、`evanxlsx::export()` 指定调用本包。
