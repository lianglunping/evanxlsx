# 中文：合成示例，无真实研究数据。运行函数后返回新文件路径。
# English: Synthetic fixture, no research data. Call the function to export.
example_basic <- function(file = tempfile("evanxlsx-basic-", fileext = ".xlsx")) {
  df <- data.frame(
    Sample_ID = c("0001", "0002", "0003"),
    Description = c("水稻 Rice", NA_character_, "合成示例 Synthetic"),
    Value = c(0.25, NA_real_, 1.5),
    stringsAsFactors = FALSE
  )
  df1 <- data.frame(Category = c("TEST_01", "TEST_02"), Count = c(10L, 0L))
  evanxlsx::write_xlsx(list(var = df, id83 = df1), file,
                       font = "Times New Roman", font_size = 11, align = "center")
}
