# 中文：可选后端需事先安装；此脚本不会安装软件或修改全局设置。
# English: Install optional backends separately. No package installation here.
example_backends <- function(file = tempfile("evanxlsx-backends-", fileext = ".xlsx")) {
  stopifnot(requireNamespace("duckplyr"), requireNamespace("polars"))
  d <- data.frame(Sample_ID = c("0001", "0002", "0003"),
                  Note = c("中文 English", NA_character_, "Synthetic 合成"),
                  Score = c(0.25, NA_real_, 1.5))
  duck <- duckplyr::as_duckdb_tibble(d, prudence = "stingy")
  polars_df <- polars::as_polars_df(d)
  polars_query <- polars_df$lazy()
  evanxlsx::write_xlsx(
    list(ordinary = d, duck = duck, polars = polars_df, query = polars_query),
    file, collect = TRUE, max_rows = 100L
  )
}
