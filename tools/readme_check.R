# Run the exact marked README snippets in a fresh directory, not a second tutorial.
# Requires the installed package and Polars for the optional processing block.
local({
  root <- normalizePath(".")
  text <- readLines("README.md", encoding = "UTF-8", warn = FALSE)
  stopifnot(identical(grep("^## ", text, value = TRUE), c(
    "## 1、包的安装", "## 2、数据读取", "## 3、数据输出", "## 4、数据处理")))
  work <- tempfile("quickstart-", tmpdir = file.path(root, "validation"))
  dir.create(work, recursive = TRUE)
  old <- setwd(work); on.exit(setwd(old), add = TRUE)
  d <- data.frame(Sample_ID = c("S001", "S002", "S003", "S004"),
    treatment = c("A", "A", "B", "B"), height = c(80, 82, 90, 92),
    weight = c(2, 4, 6, 8), locus = c("Chr01:001", "Chr01:002", "Chr02:003", "Chr02:004"))
  d1 <- data.frame(category = c("DEL", "INS"), count = c(3, 2))
  evanxlsx::export(list(var = d, id83 = d1), "data.xlsx")
  for (ext in c("csv", "txt", "tsv")) evanxlsx::export(d, paste0("data.", ext))
  env <- new.env(parent = asNamespace("evanxlsx"))
  marks <- grep("^<!-- example:", text)
  results <- data.frame(example = character(), status = character())
  for (i in marks) {
    stopifnot(text[i + 1L] == "```r")
    end <- i + 1L + which(text[seq.int(i + 2L, length(text))] == "```")[1]
    eval(parse(text = text[seq.int(i + 2L, end - 1L)]), envir = env)
    results <- rbind(results, data.frame(example = text[i], status = "PASS"))
  }
  stopifnot(nrow(results) == 5L)
  for (ext in c("xlsx", "txt", "tsv", "csv")) {
    stopifnot(isTRUE(all.equal(as.data.frame(evanxlsx::import(paste0("result.", ext))), d)))
  }
  stopifnot(identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load("WES.xlsx"))), c("var", "id83")),
            isTRUE(all.equal(evanxlsx::import("summary.xlsx")$height__mean, c(81, 91))))
  write.csv(results, "examples.csv", row.names = FALSE)
  writeLines("PASS", "STATUS.txt")
})
