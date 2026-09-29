#!/usr/bin/env Rscript
# Run from the package root: Rscript tools/check.R
# Installs nothing and never overwrites a previous check directory.
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) stop("Run from the package root.")
packages <- c("openxlsx2", "testthat", "xml2", "tibble")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required check packages first: ", paste(missing, collapse = ", "))
if (utils::packageVersion("openxlsx2") < "1.29") stop("openxlsx2 >= 1.29 is required.")
parent <- file.path(root, "validation")
dir.create(parent, showWarnings = FALSE)
out <- tempfile(pattern = "local-", tmpdir = parent)
dir.create(out)
out <- normalizePath(out, winslash = "/")
writeLines(c(capture.output(sessionInfo()), "", "CHECK DEPENDENCY VERSIONS",
             vapply(packages, function(p) paste(p, utils::packageVersion(p)), character(1))),
           file.path(out, "sessionInfo.txt"))
files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE)
files <- files[!grepl("/validation/|/\\.git/", files) & !file.info(files)$isdir]
write.table(tools::md5sum(files), file.path(out, "source-md5.tsv"),
            sep = "\t", quote = FALSE, col.names = "md5")
writeLines("NOT_RUN", file.path(out, "STATUS.txt"))
setwd(out)
r <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "R.exe" else "R")
run <- function(args, logfile) {
  cat(paste(c(shQuote(r), args), collapse = " "), "\n",
      file = file.path(out, "commands.txt"), append = TRUE)
  # Keep an open subprocess log outside the source tree being copied by build.
  capture <- tempfile(pattern = "evanxlsx-command-", fileext = ".log")
  on.exit(unlink(capture), add = TRUE)
  status <- system2(r, args, stdout = capture, stderr = capture)
  if (!file.copy(capture, logfile, overwrite = FALSE)) stop("Cannot retain log: ", logfile)
  cat(readLines(capture, warn = FALSE), sep = "\n")
  if (!identical(status, 0L)) {
    writeLines("FAIL", file.path(out, "STATUS.txt"))
    stop("Command failed. Logs: ", out)
  }
}
run(c("CMD", "build", "--no-build-vignettes", shQuote(root)), "build.log")
version <- read.dcf(file.path(root, "DESCRIPTION"))[1, "Version"]
archive <- paste0("evanxlsx_", version, ".tar.gz")
if (!file.exists(archive)) stop("Expected build archive was not produced.")
run(c("CMD", "check", "--no-manual", shQuote(archive)), "check-command.log")
check_log <- file.path(out, "evanxlsx.Rcheck", "00check.log")
if (!file.exists(check_log)) stop("R CMD check log missing.")
lines <- readLines(check_log, warn = FALSE)
status_ok <- any(grepl("^Status: OK$", lines))
# Minimum-R job deliberately excludes optional backends. Accept ONLY its dependency NOTE.
minimum_core <- identical(Sys.getenv("EVANXLSX_BACKEND_TEST"), "false")
allowed_note <- minimum_core && any(grepl("^Status: 1 NOTE$", lines)) &&
  sum(grepl("[.][.][.] NOTE$", lines)) == 1L &&
  any(grepl("checking package dependencies [.][.][.] NOTE$", lines)) &&
  any(grepl("Packages suggested but not available", lines))
if (allowed_note) {
  at <- grep("Packages suggested but not available", lines)
  nearby <- paste(lines[seq.int(at[1], min(at[1] + 3L, length(lines)))], collapse = " ")
  # The fixture is only allowed to omit duckplyr, dplyr and polars, not core/test dependencies.
  expected_missing <- c("duckplyr", "dplyr", "polars")
  for (pkg in packages) if (grepl(paste0("['\"\u2018]", pkg, "['\"\u2019]"), nearby)) allowed_note <- FALSE
  if (!any(vapply(expected_missing, function(pkg) grepl(pkg, nearby, fixed = TRUE), logical(1)))) allowed_note <- FALSE
}
if (!status_ok && !allowed_note) {
  writeLines("REVIEW_REQUIRED", file.path(out, "STATUS.txt"))
  stop("R CMD check has unaccepted notes or warnings. Review: ", check_log)
}
writeLines(if (status_ok) "PASS" else "PASS_CORE_WITH_OPTIONAL_DEPENDENCY_NOTE",
           file.path(out, "STATUS.txt"))
cat("\nCheck accepted. Logs and R-built source archive: ", out, "\n", sep = "")
