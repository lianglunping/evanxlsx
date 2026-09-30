.input_kind <- function(x) {
  if (inherits(x, "duckplyr_df")) return("duckplyr")
  if (inherits(x, "polars_lazy_frame")) return("polars_lazy")
  if (inherits(x, "polars_data_frame")) return("polars")
  if (is.data.frame(x)) return("r")
  "unsupported"
}

.normalise_sheets <- function(x, sheet) {
  if (.input_kind(x) != "unsupported") {
    .check_string(sheet, "sheet")
    x <- list(x)
    names(x) <- sheet
  }
  if (!is.list(x) || !length(x) || is.null(names(x))) {
    stop("`x` must be a data.frame, a supported backend frame, or a non-empty named list.",
         call. = FALSE)
  }
  nm <- names(x)
  if (anyNA(nm) || any(!nzchar(trimws(nm))) || any(.utf16_units(nm) > 31L) ||
      anyDuplicated(tolower(nm))) {
    stop("Sheet names must be non-empty, at most 31 characters and unique (ignoring case).",
         call. = FALSE)
  }
  bad_chars <- c("[", "]", ":", "*", "?", "/", "\\")
  if (any(vapply(bad_chars, function(ch) any(grepl(ch, nm, fixed = TRUE)), logical(1))) ||
      any(grepl("^'|'$|[[:cntrl:]]", nm)) || any(tolower(nm) == "history")) {
    stop("Invalid sheet name: avoid []:*?/\\, control characters, edge apostrophes and History.",
         call. = FALSE)
  }
  for (i in seq_along(x)) {
    if (.input_kind(x[[i]]) == "unsupported") {
      stop(sprintf("Sheet '%s': expected a data.frame, duckplyr_df or R Polars frame.", nm[i]),
           call. = FALSE)
    }
  }
  x
}

.require_backend <- function(package, minimum, install) {
  if (!requireNamespace(package, quietly = TRUE) || utils::packageVersion(package) < minimum) {
    stop(sprintf("Optional backend requires %s >= %s. Install separately: %s",
                 package, minimum, install), call. = FALSE)
  }
}

.check_columns <- function(nm, label) {
  if (!length(nm)) stop(sprintf("Sheet '%s' must have at least one column.", label), call. = FALSE)
  if (length(nm) > 16384L) stop(sprintf("Sheet '%s' exceeds Excel's column limits.", label), call. = FALSE)
  if (anyNA(nm) || any(!nzchar(nm)) || anyDuplicated(nm)) {
    stop(sprintf("Sheet '%s' needs non-empty, unique column names.", label), call. = FALSE)
  }
  .check_text(nm, paste0("headers of ", label))
}

.check_rows <- function(n, label, max_rows) {
  if (n > max_rows) {
    stop(sprintf("Sheet '%s' exceeds row limits (`max_rows = %s`); no truncated file is written.",
                 label, max_rows), call. = FALSE)
  }
}

.inspect_sheet <- function(x, kind, label, max_rows) {
  types <- NULL
  if (kind == "duckplyr") {
    .require_backend("duckplyr", "1.2.1", "install.packages('duckplyr')")
    .require_backend("dplyr", "1.1.0", "install.packages('dplyr')")
    nm <- names(x)  # Metadata only, including for prudence = 'stingy'.
  } else if (kind %in% c("polars", "polars_lazy")) {
    .require_backend("polars", "1.16.0",
                     "install.packages('polars', repos = 'https://community.r-multiverse.org')")
    if (utils::packageVersion("polars") >= "2.0.0") {
      stop("R Polars 2.x requires a revalidated adapter; this version supports Polars 1.x.",
           call. = FALSE)
    }
    schema <- if (kind == "polars_lazy") x$collect_schema() else x$schema
    nm <- names(schema)
    types <- vapply(schema, function(d) sub("\\(.*$", "", format(d, abbreviated = FALSE)), character(1))
    allowed <- c("Boolean", "Int8", "Int16", "Int32", "Int64", "UInt8", "UInt16",
                 "UInt32", "UInt64", "Float32", "Float64", "Decimal", "String",
                 "Categorical", "Enum", "Date", "Datetime", "Time", "Null")
    bad <- !types %in% allowed
    if (any(bad)) {
      stop(paste0(label, "$", nm[which(bad)[1]], ": unsupported Polars type ",
                  types[which(bad)[1]], "; flatten or convert explicitly before export."),
           call. = FALSE)
    }
    if (kind == "polars") .check_rows(x$height, label, max_rows)
  } else {
    nm <- names(x)
    .check_rows(nrow(x), label, max_rows)
  }
  .check_columns(nm, label)
  list(kind = kind, names = nm, types = types)
}

.materialize_sheet <- function(x, meta, label, max_rows) {
  # Apply the bound to the final query, not its input. Collect once, never count first.
  if (meta$kind == "duckplyr") {
    x <- dplyr::collect(utils::head(x, max_rows + 1L))
  } else if (meta$kind == "polars_lazy") {
    x <- x$head(max_rows + 1L)$collect(engine = "in-memory")
  }
  if (meta$kind %in% c("polars", "polars_lazy")) {
    .check_rows(x$height, label, max_rows)
    x <- .polars_to_frame(x, meta, label)
  }
  .check_rows(nrow(x), label, max_rows)
  if (!identical(names(x), meta$names)) {
    stop(sprintf("Sheet '%s': column schema changed during collection.", label), call. = FALSE)
  }
  .validate_frame(x, label)
}

.polars_to_frame <- function(x, meta, label) {
  # Cast temporals in Polars, before POSIXct conversion could lose ns precision or timezone.
  temporal <- meta$names[meta$types %in% c("Datetime", "Time")]
  datetime <- meta$names[meta$types == "Datetime"]
  clock <- meta$names[meta$types == "Time"]
  if (length(datetime)) {
    x <- x$with_columns(polars::pl$nth(which(meta$types == "Datetime") - 1L)$cast(polars::pl$String))
  }
  if (length(clock)) {
    # Request all nine fractional digits rather than a default display format.
    x <- x$with_columns(polars::pl$nth(which(meta$types == "Time") - 1L)$dt$to_string("%H:%M:%S%.9f"))
  }
  d <- as.data.frame(x, int64 = "character", decimal = "character")
  # Polars Null converts to an R list-column; its schema guarantees all values are missing.
  for (j in which(meta$types == "Null")) d[[j]] <- rep(NA, nrow(d))
  text_columns <- c(temporal, meta$names[meta$types == "Decimal"])
  # Integer strings are exact. Only values of at most 15 decimal digits become numbers.
  for (j in which(meta$types %in% c("Int64", "UInt64", "UInt32"))) {
    v <- d[[j]]
    if (any(nchar(sub("^-", "", v)) > 15L, na.rm = TRUE)) {
      text_columns <- c(text_columns, names(d)[j])
    } else {
      d[[j]] <- as.numeric(v)
    }
  }
  if (length(text_columns)) {
    message("Sheet '", label, "': preserving as text: ",
            paste(unique(text_columns), collapse = ", "), ".")
  }
  d
}
