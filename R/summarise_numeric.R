#' Numeric summaries using Tidy selection and Polars execution
#' @export
summarise_numeric <- function(.data, .cols, .by = NULL, na_rm = TRUE) {
  .check_flag(na_rm, "na_rm")
  ctx <- .data_context(.data)
  idx <- .data_select(ctx, rlang::enquo(.cols))
  by <- .data_select(ctx, rlang::enquo(.by), empty = TRUE)
  .data_numeric(ctx, idx)
  groups <- .data_keys(ctx, by)
  if (length(intersect(idx, by))) stop("Summary and grouping columns must not overlap.", call. = FALSE)
  pl <- polars::pl
  exprs <- list()
  for (i in idx) {
    z <- pl$nth(i - 1L)$cast(pl$Float64)$fill_nan(NULL)
    finite <- pl$when(z$is_finite())$then(z)$otherwise(NULL)
    invalid <- z$is_infinite()$any()
    if (!na_rm) invalid <- invalid | z$is_null()$any()
    q1 <- finite$quantile(0.25, interpolation = "linear")
    q3 <- finite$quantile(0.75, interpolation = "linear")
    values <- list(n_total = pl$len(), n_valid = finite$count(), n_missing = z$null_count(),
                   n_infinite = z$is_infinite()$sum(), mean = finite$mean(),
                   median = finite$median(), sd = finite$std(ddof = 1),
                   q1 = q1, q3 = q3, iqr = q3 - q1)
    for (stat in names(values)) {
      e <- values[[stat]]
      if (!startsWith(stat, "n_")) e <- pl$when(invalid)$then(NULL)$otherwise(e)
      exprs[[length(exprs) + 1L]] <- e$alias(paste0(ctx$names[i], "__", stat))
    }
  }
  new <- unlist(lapply(ctx$names[idx], function(nm) paste0(nm, "__", names(values))), use.names = FALSE)
  .data_names(new, ctx$names[by])
  if (length(groups)) {
    g <- do.call(ctx$q$group_by, c(groups, list(.maintain_order = TRUE)))
    do.call(g$agg, exprs)
  } else do.call(ctx$q$select, exprs)
}
