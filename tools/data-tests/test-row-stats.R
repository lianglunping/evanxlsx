test_that("row means and sample SD preserve rows and exclude only explicitly missing observations", {
  d <- data.frame(id=sprintf("%03d",1:7),a=c(1,NA,NA,2,0,Inf,1e200),
                  b=c(3,2,NaN,2,0,1,2e200),c=c(5,NA,NA,2,0,2,3e200))
  before <- serialize(d,NULL)
  for (remove in c(TRUE,FALSE)) {
    q <- mutate_row_stats(d,c(a,b,c),na_rm=remove)
    expect_s3_class(q,"polars_lazy_frame")
    y <- as.data.frame(q$collect())
    expect_identical(y[names(d)],d)
    for (i in seq_len(nrow(d))) {
      v <- as.numeric(d[i,2:4]); n <- sum(is.finite(v))
      bad <- any(is.infinite(v)) || (!remove && anyNA(v))
      target_mean <- if (bad || n==0) NA_real_ else mean(v[is.finite(v)])
      # Scaled R reference avoids reference-side overflow for very large magnitudes.
      fin <- v[is.finite(v)]; scale <- if(length(fin) && any(fin!=0)) max(abs(fin)) else 1
      target_sd <- if (bad || n<2) NA_real_ else sd(fin/scale)*scale
      expect_equal(y$row_n[i],n)
      for (pair in list(c(y$row_mean[i],target_mean),c(y$row_sd[i],target_sd))) {
        if(is.na(pair[2])) expect_true(is.na(pair[1])) else if(pair[2]==0) expect_equal(pair[1],0) else
          expect_equal(pair[1]/pair[2],1,tolerance=1e-12)
      }
    }
    expect_identical(serialize(d,NULL),before)
  }
  expect_error(mutate_row_stats(d,id),"ordinary numeric")
  y <- mutate_row_stats(d,c(a,b)); expect_error(mutate_row_stats(y,c(a,b)),"overwrite")
  expect_equal(nrow(as.data.frame(mutate_row_stats(d[FALSE,],c(a,b))$collect())),0L)
  expect_true(all(is.na(as.data.frame(mutate_row_stats(data.frame(a=1:3),a)$collect())$row_sd)))
  small <- as.data.frame(mutate_row_stats(data.frame(a=1e-200,b=3e-200),c(a,b))$collect())
  expect_equal(small$row_sd/(sqrt(2)*1e-200),1,tolerance=1e-12)
})
