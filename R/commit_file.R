.commit_file <- function(tmp, file, overwrite, label = "workbook") {
  # Single-writer recovery, not a filesystem transaction or a concurrent-writer lock.
  fail <- function(message) {
    stop(paste0(message, " Complete new ", label, " retained at: ",
                normalizePath(tmp, winslash = "/", mustWork = TRUE)), call. = FALSE)
  }
  copy <- function(from, to, replace) {
    isTRUE(suppressWarnings(tryCatch(file.copy(from, to, overwrite = replace),
                                    error = function(e) FALSE)))
  }
  backup <- NULL
  if (file.exists(file)) {
    if (!overwrite) fail("Output appeared during export; it was not overwritten.")
    backup <- tempfile(pattern = paste0(basename(file), "."),
                       tmpdir = dirname(file), fileext = ".bak")
    if (!copy(file, backup, FALSE)) {
      suppressWarnings(unlink(backup))
      fail("Could not back up the existing file; original was not replaced.")
    }
    message("Previous file backed up to: ", normalizePath(backup, winslash = "/"))
  }
  if (!copy(tmp, file, overwrite)) {
    if (!is.null(backup)) {
      restored <- copy(backup, file, TRUE)
      detail <- if (restored) "Original restored." else "Automatic restoration failed."
      fail(paste0("Could not save the output. ", detail, " Backup retained at: ", backup, "."))
    }
    # Only the single writer's newly-created incomplete target is eligible for removal.
    suppressWarnings(unlink(file))
    detail <- if (file.exists(file)) "Incomplete target could not be removed." else "Incomplete target removed."
    fail(paste0("Could not save the output. ", detail))
  }
  invisible(file)
}
