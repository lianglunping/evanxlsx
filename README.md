# evanxlsx

读入用 `import()`，输出用 `export()`；文件扩展名决定格式。支持 XLSX、TXT、TSV、CSV、Parquet。

## 1、包的安装

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
library(evanxlsx)
```

私有仓库需本机读取权限；`always` 可能更新必要依赖。普通读写不需要 Polars；**Parquet、延迟读取、行首注释和本包统计函数**需要安装一次可选包：

```r
install.packages(c("rlang", "tidyselect", "dplyr", "tidyr"))
Sys.setenv(NOT_CRAN = "true")
install.packages(c("polars", "tidypolars"),
  repos = c("https://community.r-multiverse.org", "https://cloud.r-project.org"))
```

不在函数运行中安装软件。`?import`、`?export` 查看完整参数；同名函数冲突时用 `evanxlsx::import()`。

## 2、数据读取

### 普通读取：直接得到 tibble

<!-- example: read -->
```r
df <- import("data.xlsx", sheet = "var")
df1 <- import("data.xlsx", sheet = "id83")
df_csv <- import("data.csv")
df_tsv <- import("data.tsv")
df_txt <- import("data.txt")
df_parquet <- import("data.parquet")
```

CSV 默认逗号，TSV/TXT 默认制表符；其他分隔符用 `sep = ";"`。XLSX 可按 `sheet = "var"` 或 `sheet = 1` 读取。

### 只读取指定列、固定列类型、跳过注释行

<!-- example: select_types -->
```r
picked <- import("data.tsv",
  cols = c("Sample_ID", "rep1"),
  types = c(Sample_ID = "character", rep1 = "double"))

annotated <- import("annotated.tsv", comment = "#",
  cols = c("Sample_ID", "rep1"),
  types = c(Sample_ID = "character", rep1 = "double"))
```

| 参数 | 常用写法 | 含义 |
|---|---|---|
| `cols` | `c("Sample_ID", "rep1")` 或 `c(1, 3)` | 选择列并按此顺序返回；不是先把编号读成数字再修复 |
| `types` | `c(Sample_ID="character", rep1="double")` | 指定数据类型：character、double/numeric、integer、logical、date（ISO日期） |
| `text_cols` | `"Sample_ID"` | 保留旧版便捷写法，等价于将指定列设为 character |
| `comment` | `"#"` | 只跳过行首以此字面前缀开头的注释记录；字段内部的 `gene#tag` 不截断，引用字段中的换行不自行拆分 |
| `na` | `c("", "NA")` | 只有明确列出的文本才当缺失；默认只有空白，文本 `"NA"` 默认保留 |
| `lazy` | `TRUE` | 返回 Polars LazyFrame，先构造查询，执行时才读取完整所需数据 |

列类型是**数据类型**，不是Excel小数位显示格式。未指定的列由读取器推断，全缺失列不保证推断为字符；编号要在读入时指定 character。`types`/`text_cols` 请针对保留的列；类型冲突、找不到列或解析失败会报错，不伪装成缺失值。

### 大文件：先不把整张表放进内存

<!-- example: lazy -->
```r
q <- import("data.parquet", lazy = TRUE,
  cols = c("treatment", "rep1", "rep2"))
q_csv <- import("data.csv", lazy = TRUE,
  types = c(Sample_ID = "character", rep1 = "double", rep2 = "double"))
```

`lazy = TRUE` 支持 CSV/TSV/TXT/Parquet，返回原生 Polars 查询；仍可能读取表头、schema或少量样本用于推断。**XLSX 不支持真正的扫描式读取，会明确拒绝 `lazy = TRUE`**，不先整表加载再冒充延迟。XLSX选列保证输出选列，不保证其解压读取只访问这些列。

`comment` 与延迟文本读取共用 Polars 的行首注释解析，避免自行逐行过滤损坏多行字段。普通文本读取仍用 readr；自动类型推断和日期解析可能有后端差异，重要列用 `types` 明确。Parquet保存自身类型和null，不使用文本的sep/comment/na；Lazy模式保留原生类型，转tibble时长整数、Decimal和高精度时间可能以文本保真。`""` 与空Excel单元格回读仍可能合并成NA。

## 3、数据输出

<!-- example: write -->
```r
export(df, "result.xlsx", sheet = "var")
export(df, "result.csv")
export(df, "result.tsv")
export(df, "result.txt")
export(df, "result.parquet")
export(list(var = df, id83 = df1), "WES.xlsx")
```

<!-- example: style -->
```r
export(df, "styled.xlsx", font = "Arial", font_size = 12, align = "left")
```

XLSX默认统一Times New Roman、11磅、居中、NA留空、冻结首行、三线表。格式参数不适用于文本/Parquet。
所有格式默认不覆盖，`overwrite = TRUE` 才备份并替换**整个文件**，不是仅替换一个sheet。

<!-- example: query_export -->
```r
export(q, "query.parquet", collect = TRUE)
```

对延迟对象 `collect = TRUE` 是执行许可。Parquet直接调用Polars写入结果，不先转R表格；默认zstd压缩，可用 `compression = "snappy"`。CSV/TSV/XLSX仍需要物化结果，不承诺恒定内存。查询中的排序/连接也可能用较多内存；不要把“延迟”理解为不做磁盘读取或无限内存容量。

## 4、数据处理

下面先对普通 `import()` 得到的tibble使用Tidy；已有清洗、填充、长宽转换不再增加同名包装函数。示例的rep1/rep2/rep3是**同单位的三次重复测量**，不是混合不同量纲求行均值。

### 4.1 先清洗：缺失值、重复记录、异常值

<!-- example: clean -->
```r
library(dplyr)
library(tidyr)
clean <- df |>
  distinct() |>
  mutate(note = na_if(trimws(note), "")) |>
  replace_na(list(note = "未记录"))

complete <- clean |> drop_na(rep1, rep2, rep3)
flagged <- clean |> flag_iqr(rep1, .by = treatment)
```

`replace_na()`仅填指定注释列，不把缺失测量值填0。`drop_na()`是明确删除缺失记录，与填补不是同一操作。`flag_iqr()`只标记、不删行；`iqr_outlier = NA` 表示未判定，要结合 `iqr_reason` 查看，不能当作正常值。`distinct()`在此只去整行完全重复记录。

### 4.2 每行求均值/标准差，追加结果列

<!-- example: row_stats -->
```r
by_row <- clean |> mutate_row_stats(c(rep1, rep2, rep3))
export(by_row, "row_stats.xlsx", collect = TRUE)
```

新增 `row_n`、`row_mean`、`row_sd`，原列和原行不变。默认忽略NA/NaN；全部缺失时均值/SD为NA，只有一个有效值时SD为NA。任何Inf使该行均值/SD为NA。SD为样本标准差（n−1）；`na_rm = FALSE` 不忽略缺失；`prefix = "repeat"` 可改前缀。本函数返回Polars LazyFrame，并拒绝覆盖已有同名列。

### 4.3 每列或按组统计；把列统计广播到每一行

<!-- example: column_stats -->
```r
summary <- clean |> summarise_numeric(c(rep1, rep2, rep3), .by = treatment)
export(summary, "summary.xlsx", collect = TRUE)

with_stats <- clean |>
  mutate(rep1_mean = mean(rep1, na.rm = TRUE),
         rep1_sd = sd(rep1, na.rm = TRUE), .by = treatment)
```

第一种缩减成每组一行，包含计数/均值/中位数/SD/Q1/Q3/IQR；第二种保留原始行，在每行显示所在组的列均值/SD。这与“同一行多列求平均”不同。

### 4.4 在表尾追加均值行、标准差行

<!-- example: append_rows -->
```r
mean_row <- clean |>
  summarise(Sample_ID = "Mean", across(c(rep1, rep2, rep3), ~ mean(.x, na.rm = TRUE)))
sd_row <- clean |>
  summarise(Sample_ID = "SD", across(c(rep1, rep2, rep3), ~ sd(.x, na.rm = TRUE)))
report <- bind_rows(clean, mean_row, sd_row)
```

这是面向阅读的结果表，不再作为原始观测参加统计。汇总行未给出的treatment/note等列为NA；没有自动对字符串、ID或不同量纲混合求平均。全缺失时普通R均值可为NaN，导出按缺失处理。

### 4.5 延迟查询也可以继续处理

<!-- example: lazy_process -->
```r
library(tidypolars)
options(tidypolars_unknown_args = "error", tidypolars_fallback_to_r = FALSE)
lazy_summary <- q |>
  filter(rep1 > 0) |>
  summarise_numeric(c(rep1, rep2), .by = treatment)
export(lazy_summary, "lazy_summary.parquet", collect = TRUE)
```

加载tidypolars不会把普通tibble自动改成Polars；延迟路径从 `import(..., lazy=TRUE)` 开始。本包汇总/行统计明确把NaN和null视作缺失；不能据此假设所有第三方Tidy动词完全等同R。`separate_strict()`、`assert_unique_keys()`保留，拆列/键校验对延迟输入仍需明确 `collect=TRUE`。输入已有group_by状态时先ungroup，再用本包函数的`.by`。

[English](README.en.md) · [函数参数](man) · [详细规则与实测范围](validation/STATUS_0.5.0.md)
