#' Flag observations outside explicitly defined IQR fences without deleting rows
#' @export
flag_iqr <- function(.data, .col, .by = NULL, k = 1.5, min_n = 4L, prefix = "iqr") {
  .check_number(k, "k", 0, Inf)
  .check_number(min_n, "min_n", 2, .Machine$integer.max)
  if (min_n != trunc(min_n)) stop("`min_n` must be a whole number.", call. = FALSE)
  .check_string(prefix, "prefix")
  ctx <- .data_context(.data)
  idx <- .data_select(ctx, rlang::enquo(.col))
  if (length(idx) != 1L) stop("Select exactly one measurement column.", call. = FALSE)
  by <- .data_select(ctx, rlang::enquo(.by), empty = TRUE)
  if (idx %in% by) stop("Measurement must not also be a grouping column.", call. = FALSE)
  .data_numeric(ctx, idx)
  groups <- .data_keys(ctx, by)
  nm <- paste0(prefix, c("_n_valid", "_q1", "_q3", "_lower", "_upper", "_outlier", "_reason"))
  .data_names(nm, ctx$names)
  pl <- polars::pl
  over <- function(e) if (length(groups)) do.call(e$over, groups) else e
  z <- pl$nth(idx - 1L)$cast(pl$Float64)$fill_nan(NULL)
  finite <- pl$when(z$is_finite())$then(z)$otherwise(NULL)
  n <- over(finite$count())
  inf <- over(z$is_infinite()$any())
  q1 <- over(finite$quantile(0.25, interpolation = "linear"))
  q3 <- over(finite$quantile(0.75, interpolation = "linear"))
  usable <- !inf & (n >= min_n)
  lo <- q1 - k * (q3 - q1)
  hi <- q3 + k * (q3 - q1)
  reason <- pl$when(z$is_null())$then(pl$lit("missing"))$
    when(inf)$then(pl$lit("infinite_in_group"))$
    when(n < min_n)$then(pl$lit("insufficient_n"))$
    when(q1 == q3)$then(pl$lit("zero_iqr"))$otherwise(pl$lit("tested"))
  flag <- pl$when(usable & (q3 > q1) & z$is_not_null())$
    then((z < lo) | (z > hi))$otherwise(NULL)$cast(pl$Boolean)
  exprs <- list(n, pl$when(usable)$then(q1)$otherwise(NULL),
                pl$when(usable)$then(q3)$otherwise(NULL),
                pl$when(usable)$then(lo)$otherwise(NULL), pl$when(usable)$then(hi)$otherwise(NULL),
                flag, reason)
  do.call(ctx$q$with_columns, Map(function(e, name) e$alias(name), exprs, nm))
}
