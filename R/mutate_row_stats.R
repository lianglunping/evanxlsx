#' Append row-wise mean and sample standard deviation for selected replicate columns
#' @export
mutate_row_stats <- function(.data, .cols, na_rm = TRUE, prefix = "row") {
  .check_flag(na_rm, "na_rm")
  .check_string(prefix, "prefix")
  ctx <- .data_context(.data)
  idx <- .data_select(ctx, rlang::enquo(.cols))
  .data_numeric(ctx, idx)
  nm <- paste0(prefix, c("_n", "_mean", "_sd"))
  .data_names(nm, ctx$names)
  pl <- polars::pl
  z <- lapply(idx, function(i) pl$nth(i - 1L)$cast(pl$Float64)$fill_nan(NULL))
  finite <- lapply(z, function(v) pl$when(v$is_finite())$then(v)$otherwise(NULL))
  invalid <- do.call(pl$any_horizontal, lapply(z, function(v) v$is_infinite()))$fill_null(FALSE)
  if (!na_rm) invalid <- invalid | do.call(pl$any_horizontal, lapply(z, function(v) v$is_null()))
  peak <- do.call(pl$max_horizontal, lapply(finite, function(v) v$abs()))
  scale <- pl$lit(2, dtype = pl$Float64)$pow(peak$log(2)$floor()$clip(-1022, 1023)$fill_null(0))
  values <- do.call(pl$concat_list, lapply(finite, function(v) v / scale))$list$drop_nulls()
  n <- values$list$len()
  mean <- pl$when(!invalid & (n > 0L))$then(values$list$mean() * scale)$otherwise(NULL)
  sd <- pl$when(!invalid & (n > 1L))$then(values$list$std(ddof = 1) * scale)$otherwise(NULL)
  ctx$q$with_columns(n$alias(nm[1]), mean$alias(nm[2]), sd$alias(nm[3]))
}
