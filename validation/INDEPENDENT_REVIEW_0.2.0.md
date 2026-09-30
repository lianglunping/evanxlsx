# evanxlsx 0.2.0：独立视角审查
## Independent-perspective review · 2026-09-30

**结论：保留简单的导出接口，优先小修正确性，并删除已经失效的辅助工具。没有证据支持继续扩充为通用报表框架。**

审查执行者为本会话助手，采用维护者与普通使用者视角；不是外部机构认证，也不声称另一名真人完成了审查。

**English summary.** The small runtime wrapper is justified. The excess complexity is concentrated in obsolete duplicate packaging/static-check tooling and an unnecessarily repetitive everyday validation path. Fresh synthetic probes reproduced a literal-column-selection defect, silent row-name omission, inherited display formatting, and incomplete recovery after an injected final-copy failure. A two-expression selector prototype passed 12 targeted exports, but it is not a released or fully regression-tested patch. Main remains unchanged.

## 1. 范围与实际执行 / Scope and execution

审查基线：`fcd2325aa7e685f19fa116dc4ef452d2d6078709`，版本 `0.2.0`。
三个运行源码文件共399行，包括注释和空行；一个导出函数、19个参数，唯一直接必需依赖为 `openxlsx2`。
文件大小和参数个数只是描述，不能单独证明是否过度工程。

独立审查分支：`audit/0.2.0-third-party-20260930`。
最终探针提交：`d0dbd6598ada43cc04f8ee7b148ea52f0b612a7a`。
最终运行：[36688189990](https://github.com/lianglunping/evanxlsx/actions/runs/36688189990)。
原始产物ID：`11084922546`。
原始ZIP SHA-256：`d0496045d0090e1451a3390043d0a9af20cadf7a0f5c13c0274eb80183bfd9c9`。

实际环境：Ubuntu 24.04.5 LTS、R 4.6.1、openxlsx2 1.29、R Polars 1.16.0、xml2 1.6.0。
这是针对未修改的0.2.0进行的单环境反例审查，不是重新执行所有平台的完整发布验收。

首轮探针中，三处构造数据时错误使用了 `rename(list(...))`；错误被标记为 `PROBE_ERROR`，没有当成产品缺陷。
修正为 `select(...$alias(...))` 并确认实际列名后，重新运行全部探针。首轮原始记录仍保留在证据包中。
最终工作流成功表示“探针执行完成”，**不表示探针观察到的产品问题消失**。

最终记录包含：8个问题观察、2个正常对照和1组修复原型观察。8个问题观察合并为5个运行层面问题；另有3个工具/维护层面问题，形成下表8项发现。不同计数单位不相加为测试总数。

## 2. 发现清单 / Findings

P1：优先修复的正确性问题；P2：可靠性、科研使用或维护问题；P3：较低影响的接口一致性问题。优先级是本次审查判断，不代表正式安全评级。

| ID | 优先级 | 发现 | 证据与边界 | 最小处理建议 |
|---|---|---|---|---|
| R01 | P1 | Polars时间列名被当成选择表达式 | `*`时间列导致无关数值列写成文本；`^value$`触发错误。实际复现 | 按已知列位置或明确的字面列名选择，新增对应回归测试 |
| R02 | P2 | 基因ID放在自定义行名时不写入且无提示 | 两条合成基因行名丢失，数值仍保留；属于接口语义/提示遗漏 | 对自定义行名明确警告，建议用户显式转为列，不擅自添加/命名列 |
| R03 | P2 | 最终复制失败后保留残缺目标文件 | 在复制函数局部副本中注入部分写入失败；新/旧目标均残缺，旧备份完整 | 改进失败后恢复与完整临时文件保留；不承诺跨平台事务性 |
| R04 | P2 | 未显式记录的全局数字格式影响显示 | 同一数值与调用，`openxlsx2.numFmt`改变单元格引用的数字格式；原数值未变 | 明确继承策略或局部固定相关默认值并恢复选项 |
| M01 | P2 | 旧Python打包器遗漏安装资源 | 实际运行后tar.gz不含`inst/`；正式交付的R构建包有`inst/` | 停用旧打包入口，只认`R CMD build`安装包 |
| M02 | P2 | 旧Python静态审计产生过时误报 | 实际运行退出码1，仍硬编码17参数、旧NAMESPACE和旧CI结构 | 删除重复的伪R解析/旧API硬编码，使用R原生检查 |
| M03 | P2 | CI硬编码0.2.0安装包名 | 静态确认工作流匹配`evanxlsx_0.2.0.tar.gz` | 从DESCRIPTION读取版本，避免下一版构建成功而安装阶段失败 |
| U01 | P3 | “固定列宽时忽略max_width”与行为不一致 | `widths=16,max_width=NULL`仍报max_width校验错误 | 只在auto时校验该参数，或准确修改文档 |

## 3. R01：可以导致无关列类型改变 / Literal column selection

复现数据只有两列：一个名为 `*` 的Datetime列，以及一个普通数值列 `value`。
0.2.0通过 `pl$col(datetime)` 选择待转换时间列，但Polars的 `col('*')` 表示全部列，而非字面名称 `*`。
实际工作簿 `F02.xlsx` 的 `B2`、`B3` 为 `inlineStr`，内容分别为文本 `1`、`2`，不是原本的数值单元格。

`^value$`也具有特殊含义：Time用例尝试对数值列运行时间格式化并报错；Datetime用例在转换到R时触发 `panic happened`。
这些是边界列名触发的问题，不能扩大为“所有Polars导出都错误”。普通字符串、数值与空值对照正常。

**已验证的最小原型只替换两处选择表达式，不添加公开参数或运行依赖：**

```r
polars::pl$nth(which(meta$types == "Datetime") - 1L)
polars::pl$nth(which(meta$types == "Time") - 1L)
```

原型在独立函数环境中加载，安装包命名空间、`R/`源码和main均未修改。
在三个列名（`^value$`、`*`、`ordinary`）、两种时间类型和eager/lazy组合下，共12次导出通过指定检查。
另用Python只读核对了对应工作簿的时间文本、数值列类型和空值。原型补丁位于证据包 `selector_prototype_NOT_RELEASE.patch`。

**这仅证明该候选修法通过了针对性案例，不等于完成跨平台、原有全部测试和多列/重排后的发布验收。**

## 4. R02：比新增格式参数更贴近科研风险 / Gene row names

以下对象的基因ID并不是数据列：

```r
x <- data.frame(
  value = c(10, 20),
  row.names = c("LOC_Os01g00010", "LOC_Os01g00020")
)
```

现有实现明确以 `row_names=FALSE` 写出，只留下 `value`、10、20，没有提示自定义行名未输出。
这不等于已有数据列被篡改，但容易让表达矩阵、差异分析结果或其他使用行名的表失去ID。

建议保持“数据列决定输出”的简单规则，并对非默认行名给出具体警告；不要自动猜测它们叫Gene_ID、Sample_ID还是其他名称。
在修正版前，应把重要ID明确放入数据列。无需为此增加复杂的自动命名、猜测或隐式类型转换机制。

## 5. R03与R04：可靠性边界 / Reliability boundaries

### 写盘失败

现有顺序是：完整临时工作簿生成 → 备份旧文件 → `file.copy(tmp, file)` → 退出时删除临时文件。
本次只在复制出来的函数环境中替换末次复制，让它写入 `PARTIAL!` 后返回FALSE。未碰任何真实数据、全局base函数或原包命名空间。

两种场景都正确报错，但目标路径仍留下残缺文件；已有文件场景的 `.bak` 内容完整。
因此不能称为“所有副本丢失”，也不能称为“失败后目标保持原样”。建议用少量文件提交/恢复逻辑改善这一点，并实际测试失败分支。
不建议因此开发通用文件事务、并发锁、数据库或自动重试框架；多个进程并发写同一路径仍可明确不支持。

### 隐式数字格式

设置 `options(openxlsx2.numFmt="0.00%")` 后，同一调用写出的 `0.12345`仍是数值 `0.12345`，但单元格引用的显示格式成为 `0.00%`。
独立XML检查同时验证了值节点与样式引用，不只是发现样式表多了一个未使用条目。

这是**显示口径依赖会话状态**，不是数据被改成12.345或被四舍五入存储。
下一版需要选定并记录策略：固定evanxlsx默认显示，或清晰声明继承哪些上游全局选项。不能笼统清空用户全部options。

## 6. 过度工程在哪里 / Where simplification helps

### 保留

单一`write_xlsx()`入口、命名list映射sheet、唯一必需写入后端、明确NA空值、类型检查、延迟查询授权、行数上限、旧文件保护和针对性回归测试都有明确用途。
19个参数中大部分有可直接使用的默认值。不能因为参数较多就改成要求用户学习配置对象、主题类、注册器或YAML。

### 删除或合并

**旧`tools/package_source.py`应退出安装包构建链。** 本次在全新源码副本中实际运行它，成功生成的同名0.2.0 tar.gz却没有`inst/`。
因此已安装示例和HTML指南缺失。该脚本自己的归档一致性检查仍能通过，因为它比较的是自己选择的错误文件集合。
正式交付的R构建包SHA-256为 `78b0077bcf932ac362c7678ed3ebdcb935ab99d737c251f0128e3ba7ff593471`，包含应有安装资源；它没有受到这次旧工具探针影响。

**旧`tools/static_audit.py`也不值得继续维护。** 它只进行字符串/括号层面检查，却重复硬编码API、NAMESPACE和CI形状。
0.2.0已经改变这些结构，它仍按旧规则报错。保留独立XML内容核验有价值，但用Python再造一套R语法/包结构裁判没有必要。
两个旧脚本共231行。建议从活动工具链中移除，历史由Git保留；不要新建“更通用”的替代框架。

**文档与版本应有单一来源。** 保留短README、R帮助和一个详细中英文指南即可。`docs/usage.html`与`inst/guide/usage.html`当前逐字节相同，不必人工维护两份内容；发布时复制或只保留一个入口。
工作流中的安装包文件名由DESCRIPTION推导，不把0.2.0写死。

### 精简执行频率，而不是取消证据

完整跨平台发布验收值得保留。普通开发提交不必总是重复全部环境的源码/本地tar/私有GitHub三路径安装。
建议普通改动采用核心跨系统检查与一个真实后端任务；发布前、依赖声明变更或读写核心变化时运行完整矩阵、自动依赖补齐和大表测试。
纯文档修改可只检查链接与打包资源。此处是执行频率建议，尚未修改工作流或删除原有测试。

## 7. 测试盲区与安装边界 / Remaining gaps

大量逐单元格比较证明的是所选案例中的数据一致性，不证明覆盖了所有接口行为。下一轮优先增加：

- 特殊/中文/非标准列名、列重排、多种类型混合后的内容与类型不变量；
- 自定义行名、非默认会话选项、文件失败和Excel占用场景；
- 实际声明支持的数据框子类、Parquet扫描产生的延迟结果，而不只测试内存表转出的lazy对象；
- 修正后的原有全部测试与跨平台检查，而不是继续主要追求断言总数。

尚未证明原生Excel显示在所有设备一致，也未测峰值内存；这些边界不应靠新增导出选项“解决”。
安装时固定evanxlsx提交不等于固定依赖版本。`upgrade="always"`是便利安装策略，但可能更新依赖。
科研项目的环境冻结可交给项目级工具，不应让evanxlsx自行安装、升级或锁定整个R环境。

## 8. 建议的最小修订范围 / Minimal next revision

下一修订版定位为**正确性修复与删减，不新增功能集**。

先修字面列选择、补回归测试；明确自定义行名提示和会话格式规则；改善最终写盘失败后的恢复策略。
同时停用两个失效工具，把版本号统一从DESCRIPTION读取。无需新增运行依赖或公开的后端框架。

验收应包括：上述反例按新约定通过、未转换列类型不变、失败时原始内容仍可恢复、R构建包含安装资源、原有全部测试保持通过。
部分现有默认行为（如行名提示、全局格式继承）发生变化时须在NEWS中说明。

本轮**没有发布0.2.1，没有修改main，没有把原型覆盖到日常安装包**。只有审查分支中的探针和报告被新增。

## 9. 复现 / Reproduction

在已有相关依赖的隔离R环境，从固定探针提交运行：

```sh
git checkout d0dbd6598ada43cc04f8ee7b148ea52f0b612a7a
R CMD INSTALL .
Rscript --vanilla tools/review_probe.R
```

输出：`validation/independent-review/observations.csv`、环境版本和合成工作簿。
脚本拒绝复用已有输出目录；请使用新的工作副本，不要删除原结果来重跑。
无随机抽样，未使用或上传真实研究数据。

旧工具的复现必须在新源码副本中进行：

```sh
python3 tools/static_audit.py
python3 tools/package_source.py /path/outside/source/new-output
```

后者仅为重现错误的归档诊断，**不可把生成的tar.gz当作可用安装包**。证据包保留目录清单和哈希，不配送这份错误安装包。

## 10. 官方接口依据 / Primary references

- [Polars col的通配与正则语义](https://pola-rs.github.io/r-polars/man/pl__col.html)
- [Polars nth按0基列位置选择](https://pola-rs.github.io/r-polars/man/pl__nth.html)
- [R文件复制和重命名语义](https://stat.ethz.ch/R-manual/R-devel/library/base/html/files.html)
- [remotes依赖及upgrade参数](https://remotes.r-lib.org/reference/install_github.html)

产品行为结论以本轮原始探针、实际工作簿及源码为依据；官方文档用于解释接口，不替代运行结果。
