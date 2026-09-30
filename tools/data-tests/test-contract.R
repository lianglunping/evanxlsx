test_that("existing Tidy grouping is rejected rather than silently ignored", {
  library(dplyr, warn.conflicts = FALSE)
  library(tidypolars)
  d <- data.frame(g = c("A","A","B","B"), v = c(1,3,10,20))
  for (x in list(polars::as_polars_lf(d), polars::as_polars_df(d))) {
    grouped <- dplyr::group_by(x, g)
    expect_identical(dplyr::group_vars(grouped), "g")
    expect_error(summarise_numeric(grouped,v), "ungroup")
    expect_error(flag_iqr(grouped,v,.by=g), "ungroup")
    expect_error(assert_unique_keys(grouped,c(g,v),collect=TRUE), "ungroup")
    expect_identical(dplyr::group_vars(grouped), "g")
    got <- as.data.frame(summarise_numeric(dplyr::ungroup(grouped),v,.by=g)$collect())
    expect_equal(got$v__mean,c(2,15))
  }
  row <- dplyr::rowwise(d)
  expect_error(flag_iqr(row,v), "ungroup")
})

test_that("validated keys compose with actual Tidy pivots", {
  library(dplyr, warn.conflicts = FALSE)
  library(tidyr, warn.conflicts = FALSE)
  library(tidypolars)
  old <- options(tidypolars_unknown_args = "error", tidypolars_fallback_to_r = FALSE)
  on.exit(options(old), add=TRUE)
  d <- data.frame(id=c("001","001","002","002"), trait=c("height","weight","height","weight"),
                  value=c(10,2.5,12,NA_real_))
  wide <- d |> assert_unique_keys(c(id,trait)) |>
    tidyr::pivot_wider(id_cols=id,names_from=trait,values_from=value) |> dplyr::arrange(id)
  back <- if (inherits(wide,"polars_lazy_frame")) as.data.frame(wide$collect()) else as.data.frame(wide)
  expect_identical(back$id,c("001","002"))
  expect_equal(back$height,c(10,12))
  expect_equal(back$weight,c(2.5,NA))
  renamed <- d; names(renamed)[1] <- "*"
  expect_equal(nrow(as.data.frame(assert_unique_keys(renamed,tidyselect::all_of(c("*","trait")))$collect())),4L)
})

test_that("lazy summaries are not pre-collected and output collisions fail early", {
  d <- data.frame(v=1:4, v__mean=c("A","A","B","B"))
  expect_error(summarise_numeric(d,v,.by=v__mean), "overwrite")
  p <- tempfile(fileext=".parquet")
  polars::as_polars_df(d)$write_parquet(p)
  q <- summarise_numeric(polars::pl$scan_parquet(p),v)
  # Only a disposable synthetic file is moved; the query must still depend on its source.
  moved <- paste0(p,".saved")
  stopifnot(file.rename(p,moved))
  on.exit(if (file.exists(moved)) file.rename(moved,p), add=TRUE)
  expect_error(q$collect())
  stopifnot(file.rename(moved,p))
  expect_equal(as.data.frame(q$collect())$v__mean,2.5)
  expect_equal(nrow(as.data.frame(flag_iqr(data.frame(v=numeric()),v)$collect())),0L)
})
