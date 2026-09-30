# evanxlsx 0.2.0

[English](README.en.md) · [中英文完整指南](inst/guide/usage.html) · [本版验收状态](validation/STATUS_0.2.0.md)

一个 Excel 导出函数，支持 data.frame/tibble、duckplyr 和 R Polars。
默认 Times New Roman、11 pt、居中、缺失值空白、冻结首行、三线表。
不在导出时安装包、不上传数据、不安装或嵌入字体。仓库保持私有。

## 安装并补齐必要依赖

```r
install.packages("remotes")
remotes::install_github("lianglunping/evanxlsx", ref = "feature/0.2.0-backends",
                        dependencies = NA, upgrade = "always")
# 本地 tar.gz 也可由安装器补齐必要依赖
remotes::install_local(file.choose(), dependencies = NA, upgrade = "always")
```

私有仓库需要本机读取凭据，不要共享或提交凭据。`dependencies=NA` 不安装全部可选后端。
`upgrade="always"` 允许更新解析到的必要依赖，可能更新已满足最低要求的依赖；不是更新整个包库。
实测 `upgrade="never"` 不会更新已安装但过旧的依赖，不能无条件推荐。受控环境先确认版本再用 never。
基础 R 的 `install.packages(..., repos=NULL)` 不会下载缺失依赖。升级已加载包后重启 R。
离线环境需提前准备 R、所有必要依赖和系统组件。安装前请查看本版验收报告。
固定版本时用报告中的完整代码提交 SHA 替换 ref；不要把旧版本的通过结果套用到新版本。

## 日常调用

```r
evanxlsx::write_xlsx(list(var = df, id83 = df1), "WES.xlsx")
evanxlsx::write_xlsx(df, "Arial.xlsx", font = "Arial", font_size = 12, align = "left")
```

`align` 可选 center/left/right/justify；表头独立由 `header_align` 设置。
SimSun/宋体为统一字体。目标电脑缺字体会影响显示。
`overwrite=TRUE` 先备份再替换整个工作簿；不是追加 sheet。

## 可选后端

```r
install.packages("duckplyr")
Sys.setenv(NOT_CRAN = "true")  # Polars 安装会话：允许预编译组件
install.packages("polars", repos = "https://community.r-multiverse.org")

evanxlsx::write_xlsx(list(duck = q_duck, polars = p_df, query = p_query),
                       "mixed.xlsx", collect = TRUE, max_rows = 100000)
```

所有 duckplyr 对象和 Polars LazyFrame 要求 `collect=TRUE`；Polars DataFrame 不要求。
核心R>=4.1.3与可选后端要求分开，Polars当前需R>=4.3。
适配 duckplyr>=1.2.1、Polars>=1.16.0且<2.0.0；Polars2.x待重新验证。
普通导出只直接依赖openxlsx2，不要求Python、Arrow或全部后端。

`max_rows` 默认1048575为Excel容量，不是内存保证。对最终查询取至多上限+1行，执行一次，
超限报错、不截断。它不限制引擎内部连接/排序/扫描资源，逐sheet转换不等于流式XLSX。
Polars长整数转换前检查；不安全的整列、Decimal和高精度时间保留文本。
Time 明确输出九位小数秒；纳秒精度以文本保留，不声称是原生 Excel 时间。
嵌套/二进制/Duration显式报错；普通R/duckplyr integer64需先准确转字符。
上游丢失的精度不能恢复。详细类型和时区边界见指南。

## 安装后可用的中英文示例

```r
source(system.file("examples", "basic.R", package = "evanxlsx"), encoding = "UTF-8")
example_basic()
source(system.file("examples", "backends.R", package = "evanxlsx"), encoding = "UTF-8")
example_backends()
utils::browseURL(system.file("guide", "usage.html", package = "evanxlsx"))
```

确定性合成数据，不含真实研究观察值。默认新临时路径。

## 验收入口

```bash
Rscript tools/check.R
Rscript tools/install_check.R
# 安装 R 构建的 tar.gz 后：
Rscript tools/integration_check.R
Rscript tools/integration_check.R --large
Rscript tools/dependency_check.R
```

后端任务必须真实运行，不靠跳过通过。依赖测试排除预装包库。
过旧依赖场景用明确标记的合成元数据，不冒充旧版功能兼容性测试。
旧 validation/STATUS.md 只属于0.1.1；0.2.0请读 STATUS_0.2.0.md。
