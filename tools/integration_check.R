#!/usr/bin/env Rscript
# Real optional-backend integration; absence is a failure, never a skip.
root <- normalizePath(".", winslash = "/")
pkgs <- c("evanxlsx", "openxlsx2", "testthat", "xml2", "duckplyr", "dplyr", "polars")
stopifnot(all(vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)))
stopifnot(packageVersion("evanxlsx") == read.dcf("DESCRIPTION")[1, "Version"])
large <- "--large" %in% commandArgs(trailingOnly = TRUE)
out <- tempfile(if (large) "large-" else "integration-", tmpdir = file.path(root, "validation"))
dir.create(out, recursive = TRUE)
Sys.setenv(EVANXLSX_INTEGRATION_OUT = out)
writeLines(c(paste("Commit:", Sys.getenv("GITHUB_SHA")), capture.output(sessionInfo()),
             vapply(pkgs, function(p) paste(p, packageVersion(p)), character(1))),
           file.path(out, "environment.txt"))
writeLines("RUNNING", file.path(out, "STATUS.txt"))
library(evanxlsx)
source("tests/testthat/helper-xml.R")
sink(file.path(out, "test-output.txt"), split = TRUE)
tryCatch({
  path <- if (large) "tools/large-tests" else "tools/integration-tests"
  results <- testthat::test_dir(path, reporter = "summary", env = globalenv(),
                                stop_on_failure = FALSE, stop_on_warning = FALSE)
  tab <- as.data.frame(results)
  utils::write.csv(tab[setdiff(names(tab), "result")], file.path(out, "tests.csv"), row.names = FALSE)
  stopifnot(!any(tab$skipped), sum(tab$failed) == 0L, sum(tab$error) == 0L, sum(tab$warning) == 0L)
  writeLines("PASS", file.path(out, "STATUS.txt"))
}, error = function(e) {
  writeLines(c("FAIL", conditionMessage(e)), file.path(out, "STATUS.txt"))
  sink()
  stop(e)
})
sink()
