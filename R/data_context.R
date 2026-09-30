# Optional data layer. Schema/selection work is in R; data calculations are Polars expressions.
.data_context <- function(x) {
  .require_backend("polars", "1.16.0", "install.packages('polars', repos = 'https://community.r-multiverse.org')")
  .require_backend("rlang", "1.1.0", "install.packages('rlang')")
  .require_backend("tidyselect", "1.2.0", "install.packages('tidyselect')")
  if (utils::packageVersion("polars") >= "2.0.0") stop("Polars 2.x requires revalidation.", call. = FALSE)
  if (inherits(x, c("duckplyr_df", "grouped_df", "rowwise_df"))) {
    stop("Collect duckplyr explicitly or ungroup R data first; specify grouping with `.by`.", call. = FALSE)
  }
  lazy <- inherits(x, "polars_lazy_frame")
  if (!lazy && !inherits(x, "polars_data_frame") && !is.data.frame(x)) {
    stop("Use a data.frame or an R Polars DataFrame/LazyFrame.", call. = FALSE)
  }
  if (is.data.frame(x) && .row_names_info(x, type = 1L) > 0L) {
    warning("Custom row names are not data columns; move important IDs into a column first.", call. = FALSE)
  }
  q <- if (lazy) x else if (is.data.frame(x)) polars::as_polars_lf(x) else x$lazy()
  schema <- q$collect_schema()
  nm <- names(schema)
  if (!length(nm) || anyNA(nm) || any(!nzchar(nm)) || anyDuplicated(nm)) {
    stop("Input needs non-empty unique column names.", call. = FALSE)
  }
  types <- vapply(schema, function(d) sub("\\(.*$", "", format(d, abbreviated = FALSE)), character(1))
  list(q = q, names = nm, types = types, lazy = lazy)
}

.data_select <- function(ctx, expr, empty = FALSE) {
  idx <- tidyselect::eval_select(expr, stats::setNames(seq_along(ctx$names), ctx$names),
                                 allow_rename = FALSE, allow_empty = empty,
                                 allow_predicates = FALSE)
  unname(idx)
}

.data_numeric <- function(ctx, idx) {
  # Deliberately avoid implicit Float64 conversion of exact Decimal/64-bit integer measurements.
  supported <- c("Int8", "Int16", "Int32", "UInt8", "UInt16", "UInt32", "Float32", "Float64")
  if (any(!ctx$types[idx] %in% supported)) {
    stop("Select ordinary numeric measurements. Int64/UInt64/Decimal and nonnumeric columns require an explicit upstream conversion.", call. = FALSE)
  }
}

.data_keys <- function(ctx, idx) {
  if (any(!ctx$types[idx] %in% c("String", "Boolean", "Categorical", "Enum", "Date", "Datetime",
                                "Int8", "Int16", "Int32", "Int64", "UInt8", "UInt16", "UInt32",
                                "UInt64", "Float32", "Float64", "Null"))) {
    stop("Grouping/key columns must be supported scalar types, not nested values.", call. = FALSE)
  }
  lapply(idx, function(i) polars::pl$nth(i - 1L))
}

.data_names <- function(new, existing) {
  if (anyNA(new) || any(!nzchar(new)) || anyDuplicated(c(existing, new))) {
    stop("New column names must be non-empty, unique and must not overwrite existing columns.", call. = FALSE)
  }
}

.data_check_permission <- function(ctx, collect) {
  .check_flag(collect, "collect")
  if (ctx$lazy && !collect) stop("Validation executes a lazy query; set `collect = TRUE` explicitly.", call. = FALSE)
}
