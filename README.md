# evanxlsx 0.2.0

[English](README.en.md) · [中英文完整指南](inst/guide/usage.html) · [本版验收状态](validation/STATUS_0.2.0.md)

一个 Excel 导出函数，支持 data.frame/tibble、duckplyr 和 R Polars。
默认 Times New Roman、11 pt、居中、缺失值空白、冻结首行、三线表。
不在导出时安装包、不上传数据、不安装或嵌入字体。仓库保持私有。

## 安装并补齐必要依赖

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", ref = "feature/0.2.0-backends",
                        dependencies = NA, upgrade = "never")
# 本地 tar.gz 也可由安装器补齐依赖：
remotes::install_local(file.choose(), dependencies = NA, upgrade = "never")
```

私有仓库需要本机配置有效的读取凭据，不要共享或提交凭据。
`dependencies=NA` 只解析必要依赖，不安装所有可选后端和测试包。
基础 R 的 `install.packages(..., repos=NULL)` 不会下载缺失依赖。
源码包不是包含 R、所有依赖和字体的完整离线环境。
开发分支需以本版验收报告为准，main 仍保留现有版本。
固定版本时可将 ref 替换为报告中的完整代码提交 SHA。

## 日常调用

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
evanxlsx::write_xlsx(df, "Arial.xlsx", font = "Arial", font_size = 12, align = "left")
```

`align` 可选 center/left/right/justify；表头独立由 `header_align` 设置。
中文字体可写 SimSun 或宋体。目标电脑缺少字体会影响显示。
明确 `overwrite=TRUE` 才替换整个工作簿，并保留独立备份；不是追加 sheet。

## 可选后端

```r
install.packages("duckplyr")
Sys.setenv(NOT_CRAN = "true")  # 仅安装会话，允许 Polars 使用预编译组件
install.packages("polars", repos = "https://community.r-multiverse.org")

evanxlsx::write_xlsx(list(duck = q_duck, polars = p_df, query = p_query),
                       "mixed.xlsx", collect = TRUE, max_rows = 100000)
```

任何 duckplyr 对象及 Polars LazyFrame 要求 `collect=TRUE`；Polars DataFrame 不要求。
核心 R>=4.1.3，可选 Polars 当前要求 R>=4.3；适配 duckplyr>=1.2.1、Polars>=1.16.0且<2.0.0。
2.x 必须重新验证，不自动放行。普通导出不依赖 Python、Arrow 或完整 tidyverse。

`max_rows` 为每个 sheet 的数据行数上限，不含表头。默认1048575为Excel硬限制，不是内存保证。
延迟查询先对最终结果加 LIMIT/head(max_rows+1)，执行一次，超限报错而不截断。
不限制引擎内部连接/排序/扫描资源；逐 sheet 转换不等于流式 XLSX。需要稳定顺序时上游显式排序。

Polars Int64/UInt64 先转准确字符再检查，无法安全表示的整列保留为文本；Decimal 保留精确文本。
Datetime/Time 在 Polars 内转文本，避免先转 POSIXct 损失精度，不声称保留完整时区数据库语义。
嵌套、二进制和Duration等类型报错，要求上游显式转换。普通 R/duckplyr 的 integer64 需先转字符。
已在上游丢失的数值精度无法恢复。

## 安装后的中英文示例

```r
source(system.file("examples", "basic.R", package = "evanxlsx"), encoding = "UTF-8")
example_basic()
source(system.file("examples", "backends.R", package = "evanxlsx"), encoding = "UTF-8")
example_backends()
utils::browseURL(system.file("guide", "usage.html", package = "evanxlsx"))
```

示例均为确定性合成数据，默认写入新临时文件。

## 复现

```bash
Rscript tools/check.R
Rscript tools/install_check.R
R CMD INSTALL .
Rscript tools/integration_check.R
Rscript tools/dependency_check.R
```

专门的后端任务要求真实安装并运行，不能靠跳过通过。
依赖测试在排除预装 site-library 的新进程、新包库中进行；过旧版本测试使用明确标记的
合成元数据，不冒充旧 openxlsx2 的功能兼容性测试。输出记录位于新的 validation 子目录。
旧 validation/STATUS.md 只属于0.1.1；0.2.0必须查看 STATUS_0.2.0.md。
