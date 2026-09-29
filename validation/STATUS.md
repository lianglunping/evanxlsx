# evanxlsx 0.1.1 — 验收报告 / Validation report

**自动检查通过：6 个环境，18 次独立安装测试。**  
**Automated checks passed: 6 environments and 18 isolated installation tests.**

Tested code commit / 已测试代码提交: `0eae3af99f5ce09505fb12079b2b2dac15880e63`  
Workflow / 运行记录: [36544155717](https://github.com/lianglunping/evanxlsx/actions/runs/36544155717)  
Validation date / 验收日期: 2026-09-29

本报告针对上面的代码提交。后续文档或校验记录提交不改变已测试的 R 源码和测试。
This report covers the code commit above. Subsequent documentation/evidence updates
do not change the validated R implementation or tests.

## 安装环境 / Installation matrix

| Environment / 环境 | R | OS | Build/check | Source | Tar | GitHub |
|---|---|---|---|---|---|---|
| macOS ARM / Apple Silicon | 4.6.1 | macOS Tahoe 26.6.2 | OK | PASS | PASS | PASS |
| macOS Intel | 4.6.1 | macOS Sequoia 15.7.9 | OK | PASS | PASS | PASS |
| Windows x64 | 4.6.1 | Windows Server 2022 x64 (build 26100) | OK | PASS | PASS | PASS |
| Linux / current R | 4.6.1 | Ubuntu 24.04.5 LTS | OK | PASS | PASS | PASS |
| Linux / previous R | 4.5.3 | Ubuntu 24.04.5 LTS | OK | PASS | PASS | PASS |
| Linux / minimum R | 4.1.3 | Ubuntu 22.04.5 LTS | OK | PASS | PASS | PASS |

每个环境都在新的独立包库中安装，再由新 R 进程加载并检查实际包路径。
每个环境的单元测试均为 **231 PASS、0 FAIL、0 WARN、0 SKIP**，对应 36 个测试场景。
源目录、本地 tar.gz、私有 GitHub 三种安装方式分别执行了 46、96、46 组导出检查。
这些是分组检查数量；其中的逐单元格循环另行覆盖所有合成输入单元格。

Each environment passed **231 unit assertions with zero failures, warnings or skips**
across 36 test scenarios. Fresh-process source-folder, local-tar and authenticated
GitHub installs passed 46, 96 and 46 grouped export checks respectively. Full-cell
loops are additional checks, not extra rows in the grouped-assertion CSV.
The installed GitHub copy's `RemoteSha` was checked against the tested commit.

All environments / 所有环境: openxlsx2 1.29; testthat 3.3.2; xml2 1.6.0; tibble 3.3.1.

## 合成测试数据 / Synthetic fixtures

- `variant_info`: 240 rows × 11 columns; Chinese, English, mixed text, missing values,
  literal NA, empty strings, XML punctuation, line breaks, factors, logicals, dates,
  timestamps, leading-zero IDs and 18-character numeric-looking IDs.
- `id83`: 83 TEST_ID categories; **synthetic categories, not biological signatures**.
- `Readme_ZH_EN`: bilingual workbook explanation / 工作簿内中英文说明。
- 12 formatting cases: three fonts × four horizontal alignments, with sizes 10/12/14 pt.
- Medium input: 10,000 rows × 6 columns, including an ID/numeric round trip.

数据为确定性构造，没有真实研究数据、随机抽样或生物学结论。
Fixtures are deterministic: no research observations, random sampling or biological conclusions.

从成功运行的 macOS ARM 产物另行进行 Python 只读 XML 核验：2,640 个数据单元格、
179 个无值节点的缺失单元格、12 种字体/对齐组合和大表中 20,000 个编号单元格均通过。
Independent read-only XML checks on the successful macOS ARM output passed for
2,640 data cells, 179 value-less missing cells, 12 font/alignment combinations,
and 20,000 ID cells in the larger workbook. Script: `independent_xml_check.py`.

## 安装包与边界 / Archive and limits

交付的 `evanxlsx_0.1.1.tar.gz` 直接提取自成功的 macOS ARM 安装测试，不是用 Python
重新拼装的归档。各 runner 从相同提交分别构建并安装了源码包；各包的 R 源码和测试文件
均已逐字节核对一致。并未把一个完全相同的压缩文件在六个系统上传输后逐一安装。

The delivered archive is the actual successful macOS ARM R-built source package,
not a Python-generated replacement. Each runner built/installed a tarball from
the same commit; R/test source bytes were compared and matched. The exact same
compressed archive bytes were not transferred and installed across all six runners.

Archive SHA-256: `90f3c35e0dc78f3d8ff4312c98de6b3116d7350763dfbc3aaf2d5e2fec6903f1`

私有 GitHub 安装仍需授权。本地源码包安装不需要 GitHub 登录，但需要 R ≥ 4.1.3、
openxlsx2 ≥ 1.29 和可写的包库；源码依赖的安装有时还需要编译工具。本交付不包含 R、
依赖包或字体，也不是完整离线环境。未测试的 OS/R/依赖组合不应宣称已验证。

Private GitHub installation requires authorization. Local-tar installation needs
R ≥ 4.1.3, openxlsx2 ≥ 1.29 and a writable library. Building dependencies may need
compilers. R, dependencies and fonts are not bundled. Untested combinations are
not claimed as validated.

字体名称、字号、对齐与边框已检查 XML，但未在原生 Microsoft Excel 中做人工视觉验收。
字体缺失时可能替代显示；第三方预览器可能改变文本编号的显示，不应据此认定原文件丢失编号。
Font/style XML has been checked, but native Microsoft Excel visual review has not
been performed. Font substitution and third-party preview interpretation remain separate concerns.

## 复现 / Reproduce

```sh
gh repo clone lianglunping/evanxlsx
cd evanxlsx
git checkout 0eae3af99f5ce09505fb12079b2b2dac15880e63
Rscript -e 'install.packages(c("openxlsx2","testthat","xml2","tibble","remotes"), repos="https://cloud.r-project.org")'
Rscript tools/check.R
Rscript tools/install_check.R
```

本地私有 GitHub 安装检查另需安全配置的 GITHUB_PAT 和 EVANXLSX_REF（上述提交 SHA）。
缺少授权时该路径标记 NOT_RUN，不会冒充 PASS。输出写到新的 validation/local-* 和
validation/portable-* 目录。日志保留实际环境、命令、来源哈希和断言。

The local private-GitHub route additionally needs securely configured GITHUB_PAT
and EVANXLSX_REF set to the commit above. Without them it reports NOT_RUN, not PASS.
Outputs use fresh validation/local-* and validation/portable-* directories.
Logs retain actual environments, commands, source hashes and assertions.

GitHub Actions artifact retention is 14 days. Downloaded evidence is also supplied
in the delivery bundle; artifact SHA-256 digests are in `evanxlsx_validation_report.json`.
GitHub 原始产物保留 14 天；本次交付另附已下载的日志证据，摘要在 JSON 报告中。

## 已修复的问题 / Resolved failures

0.1.0 的 XML 正则表达式与 Windows 日志占用问题已修复。进一步修正了测试函数不支持的
参数；保留缺失单元格“无值、无字符串、无公式节点”的原始断言，没有放宽验收条件。

The ASCII/Unicode regex issue, Windows open-log copy issue and an unsupported
test-helper argument were fixed. The original zero-value/string/formula-node
requirement for missing cells was retained, not relaxed to obtain a pass.
