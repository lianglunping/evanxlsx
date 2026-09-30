.check_string <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop(sprintf("`%s` must be one non-empty string.", name), call. = FALSE)
  }
}

.check_number <- function(x, name, lo, hi) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lo || x > hi) {
    stop(sprintf("`%s` must be a number between %s and %s.", name, lo, hi), call. = FALSE)
  }
}

.check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be TRUE or FALSE.", name), call. = FALSE)
  }
}

.check_choice <- function(x, choices, name) {
  .check_string(x, name)
  if (!x %in% choices) {
    stop(sprintf("`%s` must be one of: %s.", name, paste(choices, collapse = ", ")),
         call. = FALSE)
  }
  x
}

# Called only on an already materialized, ordinary R data frame.
.validate_frame <- function(d, label) {
  d <- as.data.frame(d)
  if (.row_names_info(d, type = 1L) > 0L) {
    warning(paste0("Sheet '", label, "': custom row names are not exported; ",
                   "move important IDs to an explicit column before exporting."), call. = FALSE)
  }
  for (j in seq_along(d)) {
    v <- d[[j]]
    column_label <- paste0(label, "$", names(d)[j])
    if (inherits(v, "integer64")) {
      stop(paste0(column_label, ": convert integer64 IDs to character explicitly before exporting."),
           call. = FALSE)
    }
    if (is.factor(v)) v <- as.character(v)
    if (inherits(v, "POSIXlt")) v <- as.POSIXct(v)
    if (!is.atomic(v) || !is.null(dim(v)) || is.complex(v) || is.raw(v) ||
        (is.object(v) && !inherits(v, c("Date", "POSIXct")))) {
      stop(paste0(column_label, ": unsupported column type; use an ordinary vector, Date or POSIXct."),
           call. = FALSE)
    }
    if (is.numeric(v) || inherits(v, c("Date", "POSIXct"))) {
      if (any(is.infinite(v))) {
        stop(paste0(column_label, ": Inf/-Inf are not supported; handle them explicitly."), call. = FALSE)
      }
      if (any(is.nan(v))) v[is.nan(v)] <- NA
      if (!is.object(v) && any(abs(v) >= 1e15 & v == trunc(v), na.rm = TRUE)) {
        warning(paste0(column_label, ": large numeric integers may lose Excel precision; use character for IDs."),
                call. = FALSE)
      }
    }
    if (is.character(v)) .check_text(v, column_label)
    d[[j]] <- v
  }
  d
}

.check_text <- function(x, label) {
  x <- x[!is.na(x)]
  reserved <- c("_openxlsx_NA", "_openxlsx_NULL", "_openxlsx_Inf",
                "_openxlsx_nInf", "_openxlsx_NaN")
  if (any(x %in% reserved) || any(startsWith(x, "<r>")) || any(startsWith(x, "<r/>"))) {
    stop(paste0(label, ": contains text reserved internally by openxlsx2."), call. = FALSE)
  }
  # Check long strings in UTF-16 code units, without converting every short cell.
  chars <- nchar(x, type = "chars", allowNA = TRUE)
  if (anyNA(chars)) stop(paste0(label, ": invalid text encoding."), call. = FALSE)
  long <- chars > 16383L
  if (any(long)) chars[long] <- .utf16_units(x[long])
  if (any(chars > 32767L)) {
    stop(paste0(label, ": text exceeds Excel's 32767-character cell limit."), call. = FALSE)
  }
  # Enable Unicode mode even when all input strings are ASCII.
  invalid_xml <- "(*UTF)[\\x01-\\x08\\x0B\\x0C\\x0E-\\x1F\\x{FFFE}\\x{FFFF}]"
  if (any(grepl(invalid_xml, enc2utf8(x), perl = TRUE))) {
    stop(paste0(label, ": contains XML-invalid control characters."), call. = FALSE)
  }
}

.utf16_units <- function(x) {
  raw <- iconv(enc2utf8(x), from = "UTF-8", to = "UTF-16LE", toRaw = TRUE)
  if (any(vapply(raw, is.null, logical(1)))) {
    stop("Invalid text encoding.", call. = FALSE)
  }
  lengths(raw) / 2
}
