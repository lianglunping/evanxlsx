#' Read common tables, optionally as a Polars lazy query
#' @export
import <- function(file, sheet = 1, sep = NULL, text_cols = NULL, na = "",
                   cols = NULL, types = NULL, comment = "", lazy = FALSE, ...) {
  format <- .io_format(file)
  .check_flag(lazy, "lazy")
  file <- path.expand(file)
  if (!file.exists(file) || dir.exists(file)) stop("Input file does not exist.", call. = FALSE)
  if (!is.character(comment) || length(comment) != 1L || is.na(comment)) {
    stop("`comment` must be one literal line prefix, or an empty string.", call. = FALSE)
  }
  if (!is.null(text_cols) && (!is.character(text_cols) || anyNA(text_cols) ||
      any(!nzchar(text_cols)) || anyDuplicated(text_cols))) {
    stop("`text_cols` must contain column names to keep as text.", call. = FALSE)
  }
  # Numeric XLSX type codes remain available for existing callers.
  legacy_types <- format == "xlsx" && is.numeric(types)
  if (!legacy_types) types <- .io_types(types, text_cols)
  if (format == "xlsx") {
    if (lazy) stop("XLSX has no scan backend; use `lazy = FALSE` or convert to Parquet first.", call. = FALSE)
    if (!is.null(sep) || nzchar(comment)) stop("`sep` and `comment` are only for text files.", call. = FALSE)
    args <- .io_args(list(file = file, sheet = sheet, na = na,
                          skip_empty_rows = FALSE, skip_empty_cols = FALSE), list(...))
    if (length(types)) {
      codes <- c(character = 0, double = 1, integer = 1, logical = 4, date = 2)
      args$types <- if (legacy_types) types else stats::setNames(unname(codes[types]), names(types))
    }
    if (length(text_cols)) args$types[text_cols] <- 0
    x <- do.call(openxlsx2::wb_to_df, args)
    if (!legacy_types) x <- .io_finish_types(x, types)
  } else {
    if (!missing(sheet)) stop("`sheet` is only for XLSX files.", call. = FALSE)
    # One native scanner handles lazy text, Parquet, and strict whole-line comments.
    if (lazy || format == "parquet" || nzchar(comment)) {
      if (format == "parquet" && (!is.null(sep) || nzchar(comment) || !missing(na))) {
        stop("Parquet has stored types/nulls; sep/comment/na are text-only settings.", call. = FALSE)
      }
      q <- .io_scan(file, format, sep, cols, types, comment, na, list(...))
      if (lazy) return(q)
      schema <- q$collect_schema()
      meta <- list(names = names(schema), types = vapply(schema, function(d)
        sub("\\(.*$", "", format(d, abbreviated = FALSE)), character(1)))
      x <- .polars_to_frame(q$collect(), meta, "import")
      return(tibble::as_tibble(x, .name_repair = "check_unique"))
    }
    args <- .io_args(list(file = file, delim = .io_sep(format, sep), na = na,
                          show_col_types = FALSE, progress = FALSE, lazy = FALSE,
                          trim_ws = FALSE, skip_empty_rows = FALSE,
                          name_repair = "check_unique"), list(...))
    if (length(types)) {
      if (!is.null(args$col_types)) stop("Use `types`/`text_cols` or `col_types`, not both.", call. = FALSE)
      readers <- list(character = readr::col_character, double = readr::col_double,
                      integer = readr::col_integer, logical = readr::col_logical, date = readr::col_date)
      args$col_types <- do.call(readr::cols, lapply(types, function(t) readers[[t]]()))
    }
    if (!is.null(cols)) {
      if (!is.null(args$col_select)) stop("Use `cols` or `col_select`, not both.", call. = FALSE)
      args$col_select <- cols
    }
    x <- do.call(readr::read_delim, args)
    readr::stop_for_problems(x)
  }
  # text_cols/types refer to retained columns; an incorrect declaration is never ignored.
  if (length(setdiff(text_cols, names(x)))) stop("A `text_cols` column was not found.", call. = FALSE)
  if (length(setdiff(names(types), names(x)))) stop("A `types` column was not found in the selected data.", call. = FALSE)
  if (!is.null(cols) && format == "xlsx") x <- x[.io_columns(cols, names(x))]
  tibble::as_tibble(x, .name_repair = "check_unique")
}

#' Write XLSX, TXT, TSV, CSV or Parquet with one function
#' @export
export <- function(x, file, sheet = "Sheet1", sep = NULL, overwrite = FALSE,
                   collect = FALSE, na = "", ...) {
  format <- .io_format(file)
  if (format == "xlsx") {
    if (!is.null(sep) || !identical(na, "")) stop("`sep` and custom `na` are only for text output.", call. = FALSE)
    return(invisible(write_xlsx(x, file, sheet = sheet, overwrite = overwrite,
                                collect = collect, ...)))
  }
  if (!missing(sheet)) stop("`sheet` is only for XLSX files.", call. = FALSE)
  .check_flag(overwrite, "overwrite")
  .check_flag(collect, "collect")
  file <- path.expand(file)
  if (!dir.exists(dirname(file)) || dir.exists(file)) stop("Use a file path in an existing directory.", call. = FALSE)
  if (file.exists(file) && !overwrite) stop("File already exists; choose a new name or set `overwrite = TRUE`.", call. = FALSE)
  if (file.access(dirname(file), 2L) != 0L) stop("Output location is not writable.", call. = FALSE)
  if (format == "parquet") {
    if (!is.null(sep) || !missing(na)) stop("Parquet has native nulls; sep/na are text-only settings.", call. = FALSE)
    return(.io_write_parquet(x, file, overwrite, collect, list(...)))
  }
  args <- .io_args(list(delim = .io_sep(format, sep), na = na,
                        quote = "needed", escape = "double", col_names = TRUE), list(...))
  allowed <- setdiff(names(formals(readr::write_delim)), c("x", "file", "append"))
  if (length(setdiff(names(args), allowed))) stop("Unsupported text output argument; sheet/font/append are not text settings.", call. = FALSE)
  x <- .io_frame(x, collect)
  tmp <- tempfile(".evanxlsx-", tmpdir = dirname(file), fileext = paste0(".", format))
  remove_tmp <- TRUE
  on.exit(if (remove_tmp) unlink(tmp), add = TRUE)
  do.call(readr::write_delim, c(list(x = x, file = tmp), args))
  remove_tmp <- FALSE
  .commit_file(tmp, file, overwrite, label = "file")
  remove_tmp <- TRUE
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}

.io_format <- function(file) {
  .check_string(file, "file")
  ext <- tolower(tools::file_ext(file))
  if (!ext %in% c("xlsx", "txt", "tsv", "csv", "parquet")) stop("Use .xlsx, .txt, .tsv, .csv or .parquet.", call. = FALSE)
  ext
}

.io_sep <- function(format, sep) {
  if (is.null(sep)) return(if (format == "csv") "," else "\t")
  if (!is.character(sep) || length(sep) != 1L || is.na(sep) ||
      nchar(sep, type = "bytes") != 1L || sep %in% c("\r", "\n", "\"")) {
    stop("`sep` must be one delimiter byte, such as ',', '\\t' or ';'.", call. = FALSE)
  }
  sep
}

.io_args <- function(defaults, dots) {
  if (length(dots) && (is.null(names(dots)) || any(!nzchar(names(dots))) || anyDuplicated(names(dots)))) {
    stop("Additional arguments must be uniquely named.", call. = FALSE)
  }
  defaults[names(dots)] <- dots
  defaults
}

.io_frame <- function(x, collect) {
  kind <- .input_kind(x)
  if (kind == "unsupported") stop("Text output requires one table; a named list is for XLSX only.", call. = FALSE)
  if (kind %in% c("duckplyr", "polars_lazy") && !collect) {
    stop("Set `collect = TRUE` to export a backend query.", call. = FALSE)
  }
  if (kind == "duckplyr") {
    .require_backend("duckplyr", "1.2.1", "install.packages('duckplyr')")
    x <- dplyr::collect(x)
  } else if (kind %in% c("polars", "polars_lazy")) {
    .require_backend("polars", "1.16.0", "install.packages('polars', repos = 'https://community.r-multiverse.org')")
    if (utils::packageVersion("polars") >= "2.0.0") stop("Polars 2.x requires revalidation.", call. = FALSE)
    schema <- if (kind == "polars_lazy") x$collect_schema() else x$schema
    meta <- list(names = names(schema), types = vapply(schema, function(d)
      sub("\\(.*$", "", format(d, abbreviated = FALSE)), character(1)))
    if (kind == "polars_lazy") x <- x$collect(engine = "in-memory")
    x <- .polars_to_frame(x, meta, "text")
  }
  x <- as.data.frame(x)
  if (!ncol(x) || anyNA(names(x)) || any(!nzchar(names(x))) || anyDuplicated(names(x))) {
    stop("Output needs non-empty, unique column names.", call. = FALSE)
  }
  if (.row_names_info(x, type = 1L) > 0L) warning("Custom row names are not exported; move IDs to a column.", call. = FALSE)
  if (any(vapply(x, function(v) is.list(v) || !is.null(dim(v)) || is.complex(v) || is.raw(v) ||
                 inherits(v, "integer64"), logical(1)))) {
    stop("Text columns must be ordinary vectors; convert nested values or integer64 explicitly.", call. = FALSE)
  }
  x
}
