.io_types <- function(types, text_cols) {
  if (is.null(types)) types <- character()
  if (!is.character(types) || (length(types) &&
      (is.null(names(types)) || anyNA(names(types)) || any(!nzchar(names(types))) ||
       anyDuplicated(names(types)) || anyNA(types)))) {
    stop("`types` must be named, e.g. c(Sample_ID = 'character', value = 'double').", call. = FALSE)
  }
  types[types == "numeric"] <- "double"
  if (any(!types %in% c("character", "double", "integer", "logical", "date"))) {
    stop("Column types: character, double/numeric, integer, logical or date.", call. = FALSE)
  }
  if (any(types[intersect(names(types), text_cols)] != "character")) {
    stop("Conflicting `types` and `text_cols` declarations.", call. = FALSE)
  }
  types[text_cols] <- "character"
  types
}

.io_columns <- function(cols, names) {
  if (is.null(cols)) return(seq_along(names))
  if (!length(cols) || anyNA(cols) || anyDuplicated(cols) || !is.null(base::names(cols))) {
    stop("`cols` must be unique column names or positive column numbers.", call. = FALSE)
  }
  idx <- if (is.character(cols)) match(cols, names) else cols
  if (!is.numeric(idx) || anyNA(idx) || any(idx != trunc(idx) | idx < 1 | idx > length(names))) {
    stop("A selected column was not found; use names or positive column numbers.", call. = FALSE)
  }
  as.integer(idx)
}

.io_finish_types <- function(x, types) {
  if (length(setdiff(names(types), names(x)))) stop("A `types` column was not found.", call. = FALSE)
  for (nm in names(types)[types == "integer"]) {
    v <- x[[nm]]
    if (any(!is.na(v) & (!is.finite(v) | v != trunc(v) | abs(v) > .Machine$integer.max))) {
      stop("Integer conversion would lose a value in column: ", nm, call. = FALSE)
    }
    x[[nm]] <- as.integer(v)
  }
  x
}

.io_polars <- function() {
  .require_backend("polars", "1.16.0", "install.packages('polars', repos = 'https://community.r-multiverse.org')")
  if (utils::packageVersion("polars") >= "2.0.0") stop("Polars 2.x requires revalidation.", call. = FALSE)
  polars::pl
}

.io_scan <- function(file, format, sep, cols, types, comment, na, dots) {
  pl <- .io_polars()
  dtypes <- list(character = pl$String, double = pl$Float64, integer = pl$Int32,
                 logical = pl$Boolean, date = pl$Date)
  schema <- lapply(types, function(t) dtypes[[t]])
  if (format == "parquet") {
    q <- do.call(pl$scan_parquet, .io_args(list(source = file), dots))
  } else {
    args <- .io_args(list(source = file, separator = .io_sep(format, sep),
      comment_prefix = if (nzchar(comment)) comment else NULL,
      schema_overrides = if (length(schema)) schema else NULL,
      null_values = na, empty_string_is_null = "" %in% na,
      infer_schema_length = 1000L, infer_schema_files = 10L), dots)
    if (length(types) && "schema_overrides" %in% names(dots)) {
      stop("Use `types` or `schema_overrides`, not both.", call. = FALSE)
    }
    q <- do.call(pl$scan_csv, args)
  }
  stored <- q$collect_schema()
  nm <- names(stored)
  idx <- .io_columns(cols, nm)
  if (length(setdiff(names(types), nm[idx]))) stop("A `types` column was not found in the selected data.", call. = FALSE)
  if (format == "parquet" && length(types)) {
    for (name in names(types)) {
      j <- match(name, nm)
      if (types[[name]] == "integer" && startsWith(format(stored[[j]], abbreviated = FALSE), "Float")) {
        stop("Explicitly round/check a floating Parquet column before converting it to integer.", call. = FALSE)
      }
      q <- q$with_columns(pl$nth(j - 1L)$cast(schema[[name]], strict = TRUE))
    }
  }
  # Numeric positions avoid interpreting literal '*' and regex-like names.
  do.call(q$select, lapply(idx, function(j) pl$nth(j - 1L)))
}

.io_write_parquet <- function(x, file, overwrite, collect, dots) {
  pl <- .io_polars()
  if (inherits(x, c("polars_lazy_frame", "duckplyr_df")) && !collect) {
    stop("Set `collect = TRUE` to execute and write a backend query.", call. = FALSE)
  }
  if (inherits(x, "duckplyr_df")) x <- .io_frame(x, collect = TRUE)
  q <- if (inherits(x, "polars_lazy_frame")) x else if (inherits(x, "polars_data_frame")) x$lazy() else {
    if (!is.data.frame(x)) stop("Parquet output requires one table.", call. = FALSE)
    if (.row_names_info(x, 1L) > 0L) warning("Custom row names are not exported; move IDs to a column.", call. = FALSE)
    polars::as_polars_lf(x)
  }
  if (length(intersect(names(dots), c("path", "file", "lazy", "mkdir")))) {
    stop("Parquet path and execution are controlled by export().", call. = FALSE)
  }
  args <- .io_args(list(compression = "zstd"), dots)
  tmp <- tempfile(".evanxlsx-", tmpdir = dirname(file), fileext = ".parquet")
  remove_tmp <- TRUE
  on.exit(if (remove_tmp) unlink(tmp), add = TRUE)
  do.call(q$sink_parquet, c(list(path = tmp), args))
  if (!file.exists(tmp)) stop("Parquet writer did not create a file.", call. = FALSE)
  remove_tmp <- FALSE
  .commit_file(tmp, file, overwrite, label = "file")
  remove_tmp <- TRUE
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}
