# 中文：合成数据；不安装依赖、不写文件、不删除异常值。
# 输入请先ungroup()，用.by显式指定分组；不要混用已有group_by()/rowwise()状态。
# English: Ungroup first, then use explicit .by. No installation, file output or row deletion.
data_tools_example <- function() {
  x <- data.frame(group = rep(c("A", "B"), each = 6),
                  value = c(1, 2, 3, 4, 5, 100, 2, 3, 4, 5, 6, 7))
  evanxlsx::summarise_numeric(x, value, .by = group)
}
# as.data.frame(data_tools_example()$collect())
# evanxlsx::write_xlsx(data_tools_example(), "summary.xlsx", collect = TRUE)
