# evanxlsx

[English](README.en.md) · [中英文指南](inst/guide/usage.html)

一致的 Excel 导出。一个 `write_xlsx()`，唯一直接必需依赖为 openxlsx2。
支持普通数据框、tibble、duckplyr、R Polars；默认统一字体、NA留空、冻结首行、三线表。

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
evanxlsx::write_xlsx(df, "Arial.xlsx", font = "Arial", font_size = 12, align = "left")
evanxlsx::write_xlsx(query, "query.xlsx", collect = TRUE, max_rows = 100000)
```

## 安装

私有仓库需要本机的读取凭据，不要共享或提交凭据。

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
# 或选择 R CMD build 生成的源码包：
remotes::install_local(file.choose(), dependencies = NA, upgrade = "always")
```

`upgrade="always"` 可能更新解析到的必要依赖；受控环境先固定依赖再安装。
`install.packages(..., repos=NULL)` 不会下载缺失依赖。导出函数从不安装软件。
版本及实际已测试提交以对应 `validation/STATUS_<version>.md` 为准。

## 0.2.1 的行为修正

时间列按位置处理，列名中的 `*` 或正则字符不再被当成选择表达式。
自定义行名不输出，但会警告；重要ID请显式放入列，不自动猜测ID列名。
数字/日期/字符编号/边框的约定不受对应 openxlsx2 全局格式选项影响，退出后恢复用户设置。
固定列宽时不读取 max_width。
最终复制失败会尽力恢复原文件或清理新残缺文件，并保留完整新工作簿；错误信息给出路径。
这不是跨平台事务或并发写入锁，恢复也可能因磁盘/权限原因失败。
旧Python打包与静态检查工具已移除，历史由Git保留；安装包只用 R CMD build。

## 范围

所有duckplyr对象和Polars LazyFrame需 `collect=TRUE`。max_rows约束最终返回行数，不保证引擎内存上限。
核心R>=4.1.3，可选后端版本要求独立；本适配不声明Polars2.x支持。
不嵌入字体、不自动修复研究数据、不追加到已有工作簿、不上传用户数据。
覆盖整个工作簿需 `overwrite=TRUE`，之前的文件会保留独立备份。

```r
utils::browseURL(system.file("guide", "usage.html", package = "evanxlsx"))
source(system.file("examples", "basic.R", package = "evanxlsx"), encoding = "UTF-8")
example_basic()
```

构建/验收入口：`Rscript tools/check.R`；完整安装与后端测试见 `.github/workflows/R-CMD-check.yaml`。
数据处理不在本包重新实现一套 tidyverse；Tidy→Polars 联动单独验证，Excel写出保持独立。
