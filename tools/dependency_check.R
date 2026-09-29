#!/usr/bin/env Rscript
# New-library dependency resolution, excluding the runner's preinstalled site libraries.
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
stopifnot(file.exists("DESCRIPTION"))
dir.create("validation", showWarnings = FALSE)
out <- tempfile("dependencies-", tmpdir = file.path(root, "validation"))
dir.create(out)
out <- normalizePath(out, winslash = "/")
writeLines("RUNNING", file.path(out, "STATUS.txt"))
repos <- getOption("repos")
if (!length(repos) || any(repos == "@CRAN@")) repos <- c(CRAN = "https://cloud.r-project.org")
boot <- file.path(out, "bootstrap"); dir.create(boot)
utils::install.packages("remotes", lib = boot, repos = repos, dependencies = NA)
rs <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
config <- list(root = root, boot = boot, out = out, repos = repos,
               version = read.dcf("DESCRIPTION")[1, "Version"])
saveRDS(config, file.path(out, "config.rds"))
child <- file.path(root, "tools", "dependency_child.R")
result <- data.frame(method = character(), status = character())
for (method in c("local", "github", "outdated")) {
  args <- c("--vanilla", shQuote(child), shQuote(file.path(out, "config.rds")), method)
  cap <- tempfile(fileext = ".log")
  status <- system2(rs, args, stdout = cap, stderr = cap)
  file.copy(cap, file.path(out, paste0(method, ".log")), overwrite = FALSE)
  cat(readLines(cap, warn = FALSE), sep = "\n"); unlink(cap)
  result <- rbind(result, data.frame(method = method, status = if (status == 0L) "PASS" else "FAIL"))
  utils::write.csv(result, file.path(out, "results.csv"), row.names = FALSE)
  if (status != 0L) {
    writeLines("FAIL", file.path(out, "STATUS.txt")); stop("Dependency resolution failed: ", method)
  }
}
writeLines("PASS", file.path(out, "STATUS.txt"))
