# 下一步的数据处理层 / Proposed next layer

已完成：0.2.1导出修正；Windows和Ubuntu的十组Tidy→Polars工作流资格验证。
未完成/未宣称：没有向evanxlsx新增summarise_numeric等公开函数，没有重写dplyr/tidyr，没有声称全Tidy兼容。

## 分工

Tidy表达式翻译复用R tidypolars；执行由R polars完成；Excel写出继续由evanxlsx完成。
把普通data.frame转为Polars Data/LazyFrame，或直接scan_parquet，才进入对应后端。加载tidypolars不会让普通数据框的所有操作自动切换引擎。

用户未来的便捷函数应当是可选的小模块或配套工具，而不是把统计和清洗设为Excel包的必需依赖。先实现常见规则的最小集合，再决定是否需要独立包；不预建后端注册器、配置类或表达式编译器。

## 值得自行封装的三个规则组

1. 数值汇总：同时返回总数、有效数、缺失数、均值、中位数、样本SD、Q1/Q3/IQR。明确NA/NaN、全缺失、单值、Inf、分位数算法以及分组语义，保留原始数据。
2. 严格拆列与宽表键检查：分隔符字面/正则明确，字段过多或过少不静默丢弃；长转宽的重复键先报错或按用户指定规则聚合，不自动求均值。填0与缺失观测需区分。
3. IQR异常值标记：明确Q1-1.5IQR与Q3+1.5IQR规则、分组、最小有效样本数、IQR=0和边界等情况。默认只生成标志，不删除行。基于标记再计算均值是独立的显式分析步骤，不等同IQR本身或mean(trim=...)。

这些是下一阶段建议，不是已发布功能。直接mean/sd、separate、pivot_longer/wider、replace_na、fill、trim/distinct优先复用已经支持的上游动词。

## 进入正式API之前的验收

函数返回Polars查询/表达式并检查计划；不为单次调用反复转回R；未知参数报错，不自动R回退。
用明确预期值和R参照双重检查。对语义上不完全等同R的部分定义并标注规则，不能只检查数值近似相等。
NA和NaN的差异已实际复现，原始观察保留；数据处理层不要偷偷替用户做统计插补。
范围包含真实Parquet扫描、组内填充的顺序、长表重复键和中文/特殊列名；输出数据类型和ID不变。

## Primary sources

- https://tidypolars.etiennebacher.com/articles/r-and-polars-expressions
- https://tidypolars.etiennebacher.com/reference/tidypolars_options
- https://tidypolars.etiennebacher.com/reference/pivot_wider.polars_data_frame
- https://pola-rs.github.io/r-polars/man/lazyframe__explain.html
- https://stat.ethz.ch/R-manual/R-devel/library/stats/html/IQR.html

See STATUS_0.2.1.md, tools/tidy_smoke.R and the retained workflow artifacts for tested versions and actual evidence. Primary documentation explains interfaces but does not replace execution results.
