# 中文：合成数据；不安装依赖、不写文件、不删除异常值。
# English: Synthetic inputs. No installation, file output or automatic outlier deletion.
data_tools_example <- function() {
  x <- data.frame(group = rep(c("A", "B"), each = 6),
                  value = c(1, 2, 3, 4, 5, 100, 2, 3, 4, 5, 6, 7))
  evanxlsx::summarise_numeric(x, value, .by = group)
}
# as.data.frame(data_tools_example()$collect())
# evanxlsx::write_xlsx(data_tools_example(), "summary.xlsx", collect = TRUE)
