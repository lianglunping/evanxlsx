#!/usr/bin/env Rscript
# No skips: optional data-layer acceptance runs only in fully provisioned backend jobs.
packages <- c("evanxlsx", "polars", "tidyselect", "rlang", "tidypolars", "dplyr", "tidyr", "testthat", "xml2")
stopifnot(all(vapply(packages, requireNamespace, logical(1), quietly = TRUE)))
stopifnot(packageVersion("evanxlsx") == read.dcf("DESCRIPTION")[1, "Version"])
dir.create("validation", showWarnings = FALSE)
out <- tempfile("data-", tmpdir = normalizePath("validation")); dir.create(out)
Sys.setenv(EVANXLSX_DATA_OUT = out)
writeLines(c(paste("Commit:", Sys.getenv("GITHUB_SHA")), capture.output(sessionInfo()),
             vapply(packages, function(p) paste(p, packageVersion(p)), character(1))), file.path(out, "environment.txt"))
writeLines("RUNNING", file.path(out, "STATUS.txt"))
library(evanxlsx)
source("tests/testthat/helper-xml.R")
sink(file.path(out, "test-output.txt"), split = TRUE)
tryCatch({
  results <- testthat::test_dir("tools/data-tests", reporter = "summary", env = globalenv(),
                                stop_on_failure = FALSE, stop_on_warning = FALSE)
  tab <- as.data.frame(results)
  write.csv(tab[setdiff(names(tab), "result")], file.path(out, "tests.csv"), row.names = FALSE)
  stopifnot(!any(tab$skipped), sum(tab$failed) == 0L, sum(tab$error) == 0L, sum(tab$warning) == 0L)
  writeLines("PASS", file.path(out, "STATUS.txt"))
}, error = function(e) {writeLines(c("FAIL", conditionMessage(e)), file.path(out, "STATUS.txt")); sink(); stop(e)})
sink()
