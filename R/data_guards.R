#' Split one text column using a literal delimiter and reject malformed rows
#' @export
separate_strict <- function(.data, col, into, sep, remove = FALSE, collect = FALSE) {
  .check_flag(remove, "remove")
  if (!is.character(into) || !length(into)) stop("`into` must be a non-empty character vector.", call. = FALSE)
  if (!is.character(sep) || length(sep) != 1L || is.na(sep) || !nzchar(sep)) {
    stop("`sep` must be one non-empty literal delimiter.", call. = FALSE)
  }
  ctx <- .data_context(.data)
  idx <- .data_select(ctx, rlang::enquo(col))
  if (length(idx) != 1L || !ctx$types[idx] %in% c("String", "Categorical", "Enum")) {
    stop("Select exactly one string column.", call. = FALSE)
  }
  .data_names(into, ctx$names)
  .data_check_permission(ctx, collect)
  v <- polars::pl$nth(idx - 1L)$cast(polars::pl$String)
  parts <- v$str$split(sep)
  bad <- v$is_not_null() & (parts$list$len() != length(into))
  n_bad <- as.data.frame(ctx$q$select(bad$sum()$alias("n_bad"))$collect())[[1]][1]
  if (n_bad > 0L) stop(sprintf("%s rows do not contain exactly %s fields; nothing was silently dropped or padded.",
                               n_bad, length(into)), call. = FALSE)
  keep <- if (remove) setdiff(seq_along(ctx$names), idx) else seq_along(ctx$names)
  exprs <- c(lapply(keep, function(i) polars::pl$nth(i - 1L)),
             lapply(seq_along(into), function(j) parts$list$get(j - 1L, null_on_oob = FALSE)$alias(into[j])))
  do.call(ctx$q$select, exprs)
}

#' Check unique, nonmissing keys before reshaping, returning a Polars query
#' @export
assert_unique_keys <- function(.data, .cols, allow_missing = FALSE, collect = FALSE) {
  .check_flag(allow_missing, "allow_missing")
  ctx <- .data_context(.data)
  idx <- .data_select(ctx, rlang::enquo(.cols))
  groups <- .data_keys(ctx, idx)
  .data_check_permission(ctx, collect)
  count_name <- ".evan_count"
  while (count_name %in% ctx$names[idx]) count_name <- paste0(count_name, "_")
  g <- do.call(ctx$q$group_by, groups)
  counts <- g$agg(polars::pl$len()$alias(count_name))
  miss <- lapply(seq_along(idx), function(j) {
    v <- polars::pl$nth(j - 1L)
    if (ctx$types[idx[j]] %in% c("Float32", "Float64")) v$is_null() | v$is_nan() else v$is_null()
  })
  stats <- counts$select(
    (polars::pl$nth(length(idx)) > 1L)$sum()$alias("duplicate_groups"),
    do.call(polars::pl$any_horizontal, miss)$sum()$alias("missing_groups"))$collect()
  d <- as.data.frame(stats)
  if (!allow_missing && d$missing_groups > 0L) stop("Missing key values found; no implicit key filling is performed.", call. = FALSE)
  if (d$duplicate_groups > 0L) stop("Duplicate key combinations found; choose an explicit upstream aggregation rule before pivot_wider().", call. = FALSE)
  ctx$q
}
