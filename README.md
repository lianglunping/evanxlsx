# evanxlsx

一个只做 Excel 导出的轻量 R 包。最常用时，只传入数据和文件名。

**当前版本：0.1.0 源码候选版，尚未创建稳定版 Release。**
源码上传至 `lianglunping/evanxlsx` 私有仓库；运行验收以对应提交的
[GitHub Actions](https://github.com/lianglunping/evanxlsx/actions) 日志为准，
不能把“源码已上传”当成“测试已通过”。所有测试和示例均使用合成数据。
详见 `validation/STATUS.md`。

## 安装

需要 R ≥ 4.1.0、openxlsx2 ≥ 1.29。正常使用只直接依赖 openxlsx2，
不需要安装 devtools、testthat 或整个 tidyverse。

已在本机登录 GitHub CLI 时，在终端克隆私有仓库：

```sh
gh repo clone lianglunping/evanxlsx
cd evanxlsx
Rscript -e 'install.packages("openxlsx2", repos = "https://cloud.r-project.org")'
R CMD INSTALL .
```

不需要把访问令牌写进脚本或发到聊天中。源码更新后，在这个目录运行
`git pull --ff-only`，再运行 `R CMD INSTALL .`。

也可以使用此前下载的 `evanxlsx_0.1.0.tar.gz`，在 R 中运行：

```r
install.packages("openxlsx2")  # 已安装且版本满足要求时可跳过

# 在弹出的文件选择窗口中选择 evanxlsx_0.1.0.tar.gz，不是源码 ZIP
install.packages(file.choose(), repos = NULL, type = "source")
```

此前提供的 tar.gz 是源码归档，不是 R CMD build 的已验收产物。
仓库安装命令已提供，但在目标电脑上的实际安装结果仍需本地验证。

## 问题 1：两个数据框，输出到一个 Excel 的两个 sheet

命名列表的名称就是工作表名称，顺序也是工作表顺序：

```r
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  "WES.xlsx"
)
```

只有一个数据框时：

```r
evanxlsx::write_xlsx(df, "variant.xlsx", sheet = "var")
```

`df` 可以是已经载入内存的 data.frame、tibble 或 data.table。
不能直接传入尚未收集的数据库查询、Arrow Dataset 或 Polars LazyFrame。
按相应工具的接口先转为普通数据框，再导出。

## 问题 2：统一字体、字号和对齐

无需识别中文或英文，整个工作簿只设置一种字体：

```r
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  "WES_Arial.xlsx",
  font = "Arial",
  font_size = 12,
  align = "left"
)
```

宋体：

```r
evanxlsx::write_xlsx(df, "WES_SimSun.xlsx", font = "SimSun", font_size = 11)
# font = "宋体" 也接受，内部映射到 SimSun
```

| 参数 | 可用值 | 默认 |
|---|---|---|
| `font` | 任意字体名称，例如 Times New Roman、Arial、SimSun | Times New Roman |
| `font_size` | 1–409，单位 pt | 11 |
| `align` | `center` / `left` / `right` / `justify` | center |
| `header_align` | 同上，只控制表头 | center |
| `valign` | `center` / `top` / `bottom` | center |

`align` 控制数据区；调整数据区为靠左时，表头仍默认居中。
需要全部靠左，就同时指定 `header_align = "left"`。

两端对齐适合较长的多行文字：

```r
evanxlsx::write_xlsx(
  df,
  "WES_justified.xlsx",
  align = "justify",
  wrap = TRUE,
  widths = 30
)
```

这是 Excel 的两端对齐设置，不会给字符串插入空格。
只有一行或很短的内容不一定有明显的两端对齐效果。
不主动设置固定行高；较长文本是否完全显示仍需在 Excel 中检查，必要时自动调整行高。

**字体边界：**包记录字体名称，不安装或嵌入字体。
目标电脑没有该字体，或该字体缺少中文等字形时，Excel/系统可能采用替代字体。
因此“统一设置一种字体”不代表所有平台每个字形都完全一致。
Mac 上可以指定已安装的 `Songti SC`，但它不是 Windows 的 SimSun。

## 问题 3：每次都想用同一套设置

只在当前 R 会话中设置一次：

```r
options(
  evanxlsx.font = "Arial",
  evanxlsx.font_size = 12,
  evanxlsx.align = "left"
)
```

之后继续使用最简单的两参数调用。单次调用显式传入的参数优先。
这些会话选项不改变 `header_align` 的默认值。包不会修改 `.Rprofile`。

## 问题 4：长注释、筛选和冻结

```r
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  "WES_browse.xlsx",
  max_width = 35,
  wrap = TRUE,
  filter = TRUE,
  freeze_first_col = TRUE
)
```

默认冻结首行。这里另外冻结首列，浏览宽表时仍能看到第一列。
`widths = "auto"` 使用 openxlsx2 的自动宽度算法，并由 `max_width` 限制最大宽度。
自动宽度是启发式估计，不是精确字体测量；数据特别大时可以用 `widths = 18`
避免自动列宽计算。没有在本版本上完成性能测试，不提供速度或内存占用数字。

| 参数 | 默认 | 用途 |
|---|---|---|
| `widths` | `"auto"` | 自动列宽，也可给单个数值或逐列宽度向量 |
| `max_width` | `40` | 自动列宽上限；手动列宽时不生效 |
| `wrap` | `TRUE` | 允许文字自动换行 |
| `freeze` | `TRUE` | 冻结首行 |
| `freeze_first_col` | `FALSE` | 冻结首列 |
| `filter` | `FALSE` | 开启表头筛选 |
| `three_line` | `TRUE` | 顶线、中线、底线；不加竖线 |
| `grid_lines` | `FALSE` | 是否显示 Excel 网格线 |
| `overwrite` | `FALSE` | 是否明确替换已有文件 |

三线表顶线和底线用 `medium`，表头下线用 `thin`。
零行数据只写表头和上下两条边线，不创建虚假的数据行。
需要纯数据网格视图时，可以设置 `three_line = FALSE, grid_lines = TRUE`。
这里的三线表针对工作表数据区域，不负责论文 Word 排版或分页打印表头。

## 问题 5：NA、编号和数据类型会怎样

`NA` 写成没有值的单元格，而不是 `#N/A` 或空字符串。数值 `NaN` 也按缺失值处理。
原本的文本 `"NA"` 不会被替换；空字符串 `""` 和缺失值不会在输入对象中混为一谈。

普通文本不会转换成公式：`"=1+1"`、`"1-2"` 和 `"001"` 均按文本写入。
因子写标签；数值列不因为存在缺失值而整列转换为字符；日期交由 openxlsx2
写入日期单元格。Excel 日期时间没有时区字段，必须保留时区的信息请提前明确转成文本。

`Inf/-Inf`、嵌套 list 列、矩阵列、integer64 和特殊公式类会报错，不做静默转换。
大数值整数会提示 Excel 的精度风险。长编号应在**读入数据时**就保存为字符，
而不是等到数值已经丢失精度后再转字符。

```r
# 前提是 ID 此时尚未发生精度损失
df$Sample_ID <- as.character(df$Sample_ID)
```

工作表名称过长、重复、含非法字符，或者超出 Excel 容量时，会明确报错。
不会擅自重命名工作表，不会悄悄截断行、列或超长单元格文本。

## 问题 6：已经有同名文件怎么办

默认停止，不覆盖。可以改文件名。明确需要替换时：

```r
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  "WES.xlsx",
  overwrite = TRUE
)
```

新工作簿先完整写入临时文件。原文件随后复制到同目录下唯一的
`WES.xlsx.<unique>.bak` 文件，再执行替换，控制台会显示备份路径。
备份需要手动管理；包不会删除旧备份。写入失败时优先检查 Excel 是否占用文件和目录权限。
这不是并发写入锁，也不承诺跨平台原子替换。不要由多个进程同时写一个输出路径。

**替换意味着整个工作簿被新内容替换，不是向原工作簿追加 sheet。**
原工作簿中的其他 sheet、图片、公式和手工格式不会合并进新文件，但原文件会保留在备份中。

## 检查和测试

普通使用不需要测试依赖。开发验收先安装：

```r
install.packages(c("openxlsx2", "testthat", "xml2", "tibble"))
```

在源码根目录的终端运行：

```sh
Rscript tools/check.R
```

入口会记录实际 R 和依赖版本、源码 MD5、运行命令、`R CMD build` 与
`R CMD check --no-manual` 的日志。只有检查日志为 `Status: OK` 才写入 `PASS`。
每次结果写进新的 `validation/local-*/`，不覆盖旧检查。

测试不只检查文件存在，还解包 XLSX，检查工作表、单元格值、字体、字号、
对齐、边框、冻结窗格、缺失值，以及覆盖前后的备份内容。输入均为合成数据，无随机抽样。

附有 Linux/macOS/Windows 的 GitHub Actions 配置。请查看对应提交的检查结果，
而不是仅凭存在工作流文件就认定通过。R 的 PDF 手册不在本次检查范围内，
因为检查使用 `--no-manual`。

安装本包后，可运行一个不会覆盖原文件的合成示例：

```sh
Rscript tools/example.R
```

openxlsx2 保存时需要系统可用的 ZIP 工具或其支持的替代程序。
如果导出失败，先查看其原始错误；不要把归档工具缺失误判为数据问题。
Mac 终端通常可以使用 `which zip` 检查。

## GitHub 发布状态

仓库：[`lianglunping/evanxlsx`](https://github.com/lianglunping/evanxlsx)，可见性为私有。
初始 README 所在提交保留在 Git 历史中。这里只保存包代码、文档和合成测试，
不包含真实研究数据、上传截图、访问凭据或字体文件。

源码入库与稳定版发布分开：运行检查未确认通过前，不创建稳定版 Release。
当前结果请查看仓库的 Actions 页面；本地验收入口为 `Rscript tools/check.R`。

## 依据与范围

此包不是 openxlsx2 的完整替代品：只负责新建格式统一的工作簿。
不提供图表、合并单元格、逐字富文本、追加已有工作簿、流式大数据导出、
自动分割超过 Excel 行数的表或科学统计。仍然只有一个导出函数。

下列官方文档于 2026-09-29 查阅，网页显示 openxlsx2 版本为 1.29：

- [数据写入与缺失值](https://janmarvin.github.io/openxlsx2/reference/wb_add_data.html)
- [默认字体与字体替代](https://janmarvin.github.io/openxlsx2/reference/base_font-wb.html)
- [字体和字号](https://janmarvin.github.io/openxlsx2/reference/wb_add_font.html)
- [对齐与换行](https://janmarvin.github.io/openxlsx2/reference/wb_add_cell_style.html)
- [边框](https://janmarvin.github.io/openxlsx2/reference/wb_add_border.html)
- [自动列宽及其限制](https://janmarvin.github.io/openxlsx2/reference/col_widths-wb.html)
- [冻结窗格](https://janmarvin.github.io/openxlsx2/reference/wb_freeze_pane.html)
- [保存及 ZIP 工具要求](https://janmarvin.github.io/openxlsx2/reference/wb_save.html)
- [Excel 规格与限制](https://support.microsoft.com/en-us/excel/excel-specifications-and-limits)
- [工作表命名规则](https://support.microsoft.com/en-us/excel/rename-a-worksheet)
- [R 包结构和检查](https://cran.r-project.org/doc/manuals/r-release/R-exts.html)
- [R GitHub Actions](https://github.com/r-lib/actions)
