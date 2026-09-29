# evanxlsx

[English](README.en.md) · [中英文使用说明](docs/usage.html) · [测试状态](validation/STATUS.md)

把数据框输出为统一格式的 Excel，只有一个导出函数。版本 **0.1.1**。
正常使用只直接依赖 `openxlsx2`。仓库保持私有；测试和示例全部使用合成数据。
测试结果以对应代码提交的 GitHub Actions 日志为准，不把源码上传当成测试通过。

## 安装：在不同电脑上使用

需要 **R ≥ 4.1.3、openxlsx2 ≥ 1.29**，并有可写的 R 包库。
本包没有需要编译的 C/C++ 代码，但依赖包的源码安装可能需要编译工具。
“跨平台”不代表没有 R、没有依赖或受到网络限制的任意设备都能直接安装。

### 方法 A：下载的源码包，不依赖 GitHub 登录

在 R 中运行，选择交付的 `evanxlsx_0.1.1.tar.gz`，不是 ZIP：

```r
install.packages("openxlsx2")  # 依赖已安装且版本满足要求时跳过
install.packages(file.choose(), repos = NULL, type = "source")
packageVersion("evanxlsx")
```

可以把同一个源码包复制到 Windows、Mac、Linux。目标电脑仍须预装 R 和依赖；
这不是把所有依赖一起打包的离线安装器。使用实际测试后的 0.1.1 包，不要继续用旧的 0.1.0 候选归档。

### 方法 B：已登录 GitHub CLI 的电脑

在终端运行：

```sh
gh repo clone lianglunping/evanxlsx
cd evanxlsx
Rscript -e 'install.packages("openxlsx2", repos = "https://cloud.r-project.org")'
R CMD INSTALL .
```

以后更新：在这个仓库目录运行 `git pull --ff-only`，再运行 `R CMD INSTALL .`。
私有仓库需要账号拥有读取权限。不要把访问令牌发到聊天里。

### 方法 C：直接从 R 安装私有仓库

前提：本机已经安全配置了可读取该仓库的 `GITHUB_PAT`，且可访问 GitHub/CRAN：

```r
install.packages(c("openxlsx2", "remotes"))
remotes::install_github("lianglunping/evanxlsx", upgrade = "never")
```

需要固定代码版本时，增加 `ref = "报告中的完整提交SHA"`。
不要把令牌直接写进脚本、示例、日志或版本控制。

没有系统包库写权限时，可先创建自己的库：

```r
lib <- path.expand("~/R/library")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
install.packages("openxlsx2", lib = lib)
install.packages(file.choose(), repos = NULL, type = "source", lib = lib)
```

新 R 会话也需把该目录加入 `.libPaths()`；包不会替你修改 `.Rprofile`。

## 两个数据框，两个 sheet

```r
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  "WES.xlsx"
)
```

默认：Times New Roman、11 磅、数据与表头居中、表头加粗、首行冻结、三线表、
NA 空白、隐藏网格线、自动列宽上限 40、文字换行。不会默认覆盖已有文件。

## 字体、字号、对齐

```r
evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  "WES_Arial.xlsx",
  font = "Arial",
  font_size = 12,
  align = "left"
)
```

| 参数 | 选择 | 默认 |
|---|---|---|
| `font` | `Times New Roman`、`Arial`、`SimSun` / `宋体` 或其他字体名 | Times New Roman |
| `font_size` | 1–409 pt | 11 |
| `align` | `center`、`left`、`right`、`justify` | center |
| `header_align` | 同上，单独控制表头 | center |
| `valign` | `center`、`top`、`bottom` | center |
| `widths` | `"auto"`、单个数值或逐列向量 | auto |
| `max_width` | 自动列宽上限 | 40 |
| `freeze` / `freeze_first_col` | 冻结首行 / 首列 | TRUE / FALSE |
| `filter` | 表头筛选 | FALSE |
| `three_line` / `grid_lines` | 三线表 / 网格线 | TRUE / FALSE |
| `wrap` | 文字换行 | TRUE |
| `overwrite` | 替换整个工作簿，先保留独立 `.bak` 备份 | FALSE |

`align` 只控制数据；全表靠左还需 `header_align = "left"`。
`justify` 是两端对齐；短文本不一定有明显视觉差异。
字体仅记录名称，不安装、不嵌入字体。字体缺失或没有某些字形时，Excel/系统可能替代显示。

偏好可以在当前会话设置一次：

```r
options(evanxlsx.font = "Arial", evanxlsx.font_size = 12, evanxlsx.align = "left")
```

## 数据安全和边界

`NA` / `NaN` 写为空白，文本 `"NA"` 保留为文本。`"001"`、长字符编号和 `"=1+1"`
不转成数值或公式。因子写标签，日期与时间保留相应格式；Excel 日期时间不保存时区。
输入数据不会被原地修改。Inf、嵌套列、特殊公式类、非法工作表名等会报错，不静默改写。
替换是替换整个工作簿，不是向已有工作簿追加 sheet。

## 实际测试和合成数据

CI 请求六个环境：Linux 当前 R、Windows 当前 R、Apple Silicon Mac 当前 R、
Intel Mac 当前 R、Linux 上一代 R、Linux R 4.1.3。只有成功运行的环境才算已验证。
每个环境执行 `R CMD build/check`，并分别从源码目录、本地 tar.gz、当前提交的私有 GitHub
安装到独立包库，再用新的 R 进程调用已安装的包。

```sh
Rscript tools/check.R
Rscript tools/install_check.R
```

开发测试需要 `openxlsx2`、`testthat`、`xml2`、`tibble`；GitHub 安装测试另外需要 `remotes`
和本机安全配置的授权及 `EVANXLSX_REF`。本地缺授权时 GitHub 路径记为 NOT_RUN，而不是 PASS。

数据由 `tools/fixtures.R` 确定性构造，不用随机抽样：240 行 × 11 列，包含中英文、缺失值、
字面量 NA、空字符串、换行、特殊字符、18 位字符编号、因子、逻辑值、日期和时间。
`id83` 为 83 个 **TEST_ID** 合成类别，不是实际突变特征谱。另有 10,000 行 × 6 列的导出检查。
完整模式还生成三种字体 × 四种对齐的 12 个工作簿；XML 检查字体、字号、对齐和冻结状态。
所有原始单元格按类型逐一核对。耗时仅为该 runner 的单次观察，不作性能排名。

输出在新的 `validation/local-*` 和 `validation/portable-*` 中，包含输入 CSV/RDS、
示例 Excel、安装日志、断言结果及环境版本。CSV 用 `<MISSING>` 区分缺失值；类型以 RDS 为准。
程序检查不等于已在每种版本的 Excel 中人工查看字体与分页效果。

## 官方依据

[openxlsx2 数据写入](https://janmarvin.github.io/openxlsx2/reference/wb_add_data.html) ·
[字体](https://janmarvin.github.io/openxlsx2/reference/base_font-wb.html) ·
[对齐](https://janmarvin.github.io/openxlsx2/reference/wb_add_cell_style.html) ·
[私有 GitHub 安装](https://remotes.r-lib.org/reference/install_github.html) ·
[R 安装手册](https://cran.r-project.org/doc/manuals/r-release/R-admin.html)
