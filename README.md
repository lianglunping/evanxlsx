# evanxlsx

[English](README.en.md) · [导出指南](inst/guide/usage.html) · [数据函数](inst/guide/data_tools.html) · [完整工作流](inst/guide/workflow.html)

一个Excel导出入口和四个可选数据函数。Tidy选列、Polars执行，直接必需依赖仍只有openxlsx2。

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
summary <- evanxlsx::summarise_numeric(df, c(height, weight), .by = treatment)
evanxlsx::write_xlsx(summary, "summary.xlsx", collect = TRUE)
```

## 安装

私有GitHub需本机读取凭据，不要共享凭据。

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", dependencies = NA, upgrade = "always")
```

安装器处理必要依赖；always可能更新相关包。固定包提交不等于固定项目依赖。
可选数据函数需另装polars、rlang、tidyselect；组合Tidy动词需tidypolars及对应dplyr/tidyr/stringr。
实际受测提交、版本和范围见对应validation/STATUS文件，不依据版本号猜测测试状态。

## 安装后可运行的完整示例

```r
source(system.file("examples", "workflow.R", package = "evanxlsx"), encoding = "UTF-8")
result <- evanxlsx_workflow()
result$path
```

示例串联Parquet读取、注释清理、组内补批次、去完全重复记录、拆列、长宽转换、统计、IQR标记及五个sheet。
不填补测量值，不自动删除异常值。原始RDS/Parquet、实际中间对象类型和查询计划保留在新目录。
source只定义示例函数；该函数不是新增的公开包API。不保证动态长转宽始终没有提前执行。

0.3.1只为均值/标准差加入内部二进制缩放，减少已复现的极端有限数中间上溢/下溢。
不是任意精度运算；原统计字段、缺失与Inf处理、分位数和公开接口保持不变。详见NEWS与工作流指南。

既有四个数据函数返回Polars LazyFrame；拆列/唯一键检查需要实际校验，Lazy输入需明确collect=TRUE。
不要同时传入已有group_by状态，先ungroup后用.by。旧的数据/导出指南介绍共有接口，新变更以NEWS为准。
