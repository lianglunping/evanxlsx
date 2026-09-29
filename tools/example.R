#!/usr/bin/env Rscript
# All values below are synthetic. No research data are bundled.
library(evanxlsx)
variant_info <- data.frame(
  Chr = c("Chr01", "Chr02", "Chr03"),
  Sample_ID = c("001", "002", "003"),
  Description = c("\u793a\u4f8b\u6ce8\u91ca A", NA, "\u793a\u4f8b\u6ce8\u91ca B"),
  Value = c(1.5, NA_real_, 2.7)
)
id83 <- data.frame(type = c("DEL", "INS"), count = c(2L, 1L))
# A unique path keeps repeated example runs non-destructive.
out <- tempfile(pattern = "evanxlsx-example-", tmpdir = ".", fileext = ".xlsx")
write_xlsx(list(variant_info = variant_info, id83 = id83), out,
           font = "Times New Roman", font_size = 11, align = "center")
cat(normalizePath(out, winslash = "/"), "\n")
