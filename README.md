# evanxlsx

[English](README.en.md) · [Excel指南](inst/guide/usage.html) · [可选数据模块](inst/guide/data_tools.html)

一个Excel导出入口，另有四个可选的科研数据辅助函数。普通导出唯一直接必需依赖仍为openxlsx2。

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
```

## 安装

私有仓库需本机读取权限；不要分享凭据。固定版本及实测范围见对应validation/STATUS文件。

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
```

安装器处理必需依赖，导出函数不安装软件。always可能更新相关依赖；固定本包SHA不等于固定整个依赖环境。
本地tar.gz可用remotes::install_local(file.choose(), dependencies=NA, upgrade="always")补齐依赖。

## 可选数据模块：Tidy选择，Polars执行

仅需要这些函数时安装polars、rlang、tidyselect；组合Tidy动词另装tidypolars、dplyr、tidyr。

```r
summary <- evanxlsx::summarise_numeric(df, c(height, weight), .by = treatment)
flagged <- evanxlsx::flag_iqr(df, height, .by = treatment)
parts <- evanxlsx::separate_strict(df, locus, c("Chr", "Position"), sep = ":")
checked <- evanxlsx::assert_unique_keys(long_table, c(Sample_ID, trait))
evanxlsx::write_xlsx(summary, "summary.xlsx", collect = TRUE)
```

所有数据辅助函数返回Polars LazyFrame，不返回普通tibble。统计和标记只构造查询；拆列及键检查需执行校验，对LazyFrame须明确collect=TRUE。校验扫描只取小型汇总回R，但仍可能扫描全源，且不是动态数据源的事务快照。
NA与NaN统一为缺失；任何Inf使所在组该列描述统计为缺失，并输出n_infinite。样本SD分母n-1；分位数用linear/type7。IQR标记不删行，少样本/零IQR标志为NA并说明原因。
分隔符只按字面处理，缺字段/多字段报错，字符编号不转数值。重复键不默认求均值。
均值/清洗/长宽转换不重复实现Tidy翻译框架，继续复用tidypolars支持的动词。

Excel字体/NA/冻结/三线表/备份规则保持0.2.1；使用边界详见安装指南。0.3.0实际状态以对应验收记录为准。
