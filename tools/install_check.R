#!/usr/bin/env Rscript
# Source-folder, local-tar and authenticated GitHub installs in isolated libraries.
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
stopifnot(file.exists("DESCRIPTION"))
out <- tempfile("portable-", tmpdir = file.path(root, "validation"))
dir.create(out, recursive = TRUE)
out <- normalizePath(out, winslash = "/")
version <- read.dcf("DESCRIPTION")[1, "Version"]
r <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "R.exe" else "R")
rs <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
writeLines(c(paste("Commit:", Sys.getenv("GITHUB_SHA", "LOCAL_UNPINNED")),
             capture.output(sessionInfo())), file.path(out, "environment.txt"))
writeLines("RUNNING", file.path(out, "STATUS.txt"))
run <- function(exe, args, name) {
  capture <- tempfile("evanxlsx-install-", fileext = ".log")
  on.exit(unlink(capture), add = TRUE)
  cat(paste(c(shQuote(exe), args), collapse = " "), "\n",
      file = file.path(out, "commands.txt"), append = TRUE)
  status <- system2(exe, args, stdout = capture, stderr = capture)
  file.copy(capture, file.path(out, paste0(name, ".log")), overwrite = FALSE)
  cat(readLines(capture, warn = FALSE), sep = "\n")
  if (!identical(status, 0L)) {
    writeLines("FAIL", file.path(out, "STATUS.txt"))
    stop("Failed: ", name)
  }
}
setwd(out)
run(r, c("CMD", "build", "--no-build-vignettes", shQuote(root)), "build")
archive <- file.path(out, paste0("evanxlsx_", version, ".tar.gz"))
stopifnot(file.exists(archive))
results <- data.frame(method = character(), status = character())
for (method in c("source", "tar", "github")) {
  lib <- file.path(out, paste0("library ", method))
  dir.create(lib)
  if (method == "github") {
    token <- Sys.getenv("GITHUB_TOKEN", Sys.getenv("GITHUB_PAT"))
    ref <- Sys.getenv("GITHUB_SHA", Sys.getenv("EVANXLSX_REF"))
    if (!nzchar(token) || !nzchar(ref)) {
      if (identical(Sys.getenv("CI"), "true")) stop("CI requires authenticated GitHub installation.")
      results <- rbind(results, data.frame(method = method, status = "NOT_RUN_AUTH_OR_REF_MISSING"))
      next
    }
    # Secret values never appear in a command line or retained script.
    installer <- file.path(out, "install_github.R")
    writeLines(c(sprintf(".libPaths(c(%s, .libPaths()))", deparse(lib)),
      sprintf("remotes::install_github('lianglunping/evanxlsx', ref = Sys.getenv('GITHUB_SHA', Sys.getenv('EVANXLSX_REF')), lib = %s, auth_token = Sys.getenv('GITHUB_TOKEN', Sys.getenv('GITHUB_PAT')), dependencies = FALSE, upgrade = 'never', build_vignettes = FALSE)", deparse(lib))), installer)
    run(rs, shQuote(installer), "install_github")
    rm(token)
  } else {
    input <- if (method == "source") root else archive
    run(r, c("CMD", "INSTALL", paste0("--library=", shQuote(lib)), shQuote(input)), paste0("install_", method))
  }
  run(rs, c(shQuote(file.path(root, "tools", "smoke.R")), shQuote(lib),
             shQuote(file.path(out, paste0("examples_", method))),
             if (method == "tar") "full" else "smoke"), paste0("smoke_", method))
  results <- rbind(results, data.frame(method = method, status = "PASS"))
  utils::write.csv(results, file.path(out, "installation_results.csv"), row.names = FALSE)
}
utils::write.csv(results, file.path(out, "installation_results.csv"), row.names = FALSE)
writeLines(if (all(results$status == "PASS")) "PASS" else "PARTIAL", file.path(out, "STATUS.txt"))
cat("Installation results:\n"); print(results)
