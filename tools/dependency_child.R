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
  # A synthetic DESCRIPTION-only fixture tests resolver minimum-version logic.
  # It is NOT an old openxlsx2 implementation or a compatibility test of one.
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
                          auth_token = token, dependencies = NA, upgrade = "never",
                          build_vignettes = FALSE)
  stopifnot(utils::packageDescription("evanxlsx", lib.loc = lib)$RemoteSha == ref)
  rm(token)
} else {
  remotes::install_local(cfg$root, lib = lib, dependencies = NA, upgrade = "never",
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
cat("PASS: required dependencies resolved; no optional backend installed; export verified\n")
writeLines(c(capture.output(sessionInfo()), paste("openxlsx2:", packageVersion("openxlsx2")),
             paste("evanxlsx:", packageVersion("evanxlsx"))), file.path(cfg$out, paste0(method, "_session.txt")))
