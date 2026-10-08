#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
cfg <- readRDS(args[1]); method <- args[2]
lib <- file.path(cfg$out, paste0("user library ", method)); dir.create(lib)
.libPaths(c(lib, cfg$boot, .Library), include.site = FALSE)
options(repos = cfg$repos)
stopifnot(!requireNamespace("openxlsx2", quietly = TRUE),
          !requireNamespace("evanxlsx", quietly = TRUE),
          !requireNamespace("polars", quietly = TRUE),
          !requireNamespace("duckplyr", quietly = TRUE))
cat("PRECONDITION: openxlsx2 and optional backends absent from visible libraries\n")
cat("LIBRARIES:\n", .libPaths(), sep = "\n")
if (method == "outdated") {
  # Synthetic dependency metadata, NOT an older export implementation.
  fake <- file.path(cfg$out, "synthetic-old-dependency"); dir.create(fake)
  writeLines(c("Package: openxlsx2", "Version: 0.0.0", "Title: Synthetic Version Fixture",
    "Description: Tests dependency resolution only; no export implementation.",
    "Author: Test", "Maintainer: Test <test@example.invalid>", "License: MIT"), file.path(fake, "DESCRIPTION"))
  writeLines(character(), file.path(fake, "NAMESPACE"))
  utils::install.packages(fake, lib = lib, repos = NULL, type = "source")
  stopifnot(utils::packageVersion("openxlsx2", lib.loc = lib) == "0.0.0")
  cat("PRECONDITION: synthetic installed version 0.0.0 < required 1.29\n")
}
if (method == "github") {
  ref <- Sys.getenv("GITHUB_SHA")
  token <- Sys.getenv("GITHUB_TOKEN", Sys.getenv("GITHUB_PAT"))
  stopifnot(nzchar(ref), nzchar(token))
  remotes::install_github("lianglunping/evanxlsx", ref = ref, lib = lib,
                          auth_token = token, dependencies = NA, upgrade = "always",
                          build_vignettes = FALSE)
  stopifnot(utils::packageDescription("evanxlsx", lib.loc = lib)$RemoteSha == ref)
  rm(token)
} else {
  remotes::install_local(cfg$root, lib = lib, dependencies = NA, upgrade = "always",
                         build_vignettes = FALSE)
}
stopifnot(utils::packageVersion("openxlsx2", lib.loc = lib) >= "1.29", requireNamespace("openxlsx2"),
          utils::packageVersion("evanxlsx", lib.loc = lib) == cfg$version,
          normalizePath(find.package("evanxlsx"), winslash = "/") == paste0(normalizePath(lib, winslash = "/"), "/evanxlsx"),
          !requireNamespace("duckplyr", quietly = TRUE), !requireNamespace("polars", quietly = TRUE))
x <- data.frame(id = c("0001", "0002"), note = c("\u4e2d\u6587 English", NA_character_), value = c(1.25, 2.5))
f <- file.path(cfg$out, paste0("export_", method, ".xlsx"))
evanxlsx::write_xlsx(x, f)
y <- openxlsx2::read_xlsx(f, skip_empty_rows = FALSE)
stopifnot(identical(y$id, x$id), identical(y$note, x$note), identical(y$value, x$value))
for (kind in c("polars_data_frame", "duckplyr_df")) {
  dummy <- structure(list(), class = kind)
  err <- tryCatch(evanxlsx::write_xlsx(dummy, tempfile(fileext = ".xlsx"), collect = TRUE),
                  error = identity)
  stopifnot(inherits(err, "error"), grepl("Optional backend requires", conditionMessage(err)))
}
stopifnot(!requireNamespace("duckplyr", quietly = TRUE), !requireNamespace("polars", quietly = TRUE))
# Unified IO dependencies must also be resolved by the installer.
stopifnot(requireNamespace("readr", quietly = TRUE), requireNamespace("tibble", quietly = TRUE))
text_file <- file.path(cfg$out, paste0("export_", method, ".csv"))
evanxlsx::export(x, text_file)
stopifnot(identical(evanxlsx::import(text_file, text_cols = "id")$id, x$id))
cat("PASS: required dependencies resolved; optional absence produces installation hints only; export verified\n")
writeLines(c(capture.output(sessionInfo()), paste("openxlsx2:", packageVersion("openxlsx2")),
             paste("evanxlsx:", packageVersion("evanxlsx"))), file.path(cfg$out, paste0(method, "_session.txt")))
