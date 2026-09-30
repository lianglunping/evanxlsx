# Scaled assertions compare dimensionless ratios: 0 cannot pass for a tiny nonzero SD.
test_that("mean and sample SD remain scale-equivariant over wide Float64 magnitudes", {
  for (power in c(-1022, -665, 0, 665, 1020)) {
    unit <- 2^power
    d <- data.frame(group = rep(c("A","B"), each=4), value = c(1:4,-(1:4))*unit)
    got <- as.data.frame(summarise_numeric(d,value,.by=group)$collect())
    expect_true(all(is.finite(got$value__mean)))
    expect_true(all(is.finite(got$value__sd)))
    expect_equal(got$value__mean/unit,c(2.5,-2.5),tolerance=1e-12)
    expect_equal(got$value__sd/unit,rep(sqrt(5/3),2),tolerance=1e-12)
    expect_equal(got$value__n_valid,c(4,4))
    expect_equal(got$value__n_infinite,c(0,0))
    single <- as.data.frame(summarise_numeric(data.frame(value=d$value[1:4]),value)$collect())
    expect_equal(single$value__mean/unit,2.5,tolerance=1e-12)
    expect_equal(single$value__sd/unit,sqrt(5/3),tolerance=1e-12)
  }
})

test_that("finite large means and nonzero SDs are not replaced by Inf, NaN or zero", {
  fixtures <- list(small=c(1,2,3,4)*1e-200, large=c(1,2,3,4)*1e200,
                   huge_constant=rep(1e308,4), wide=c(-1e308,0,0,1e308))
  means <- c(2.5e-200,2.5e200,1e308,0)
  sds <- c(sqrt(5/3)*1e-200,sqrt(5/3)*1e200,0,sqrt(2/3)*1e308)
  rows <- list()
  for (i in seq_along(fixtures)) {
    d <- data.frame(v=fixtures[[i]])
    before <- serialize(d,NULL)
    got <- as.data.frame(summarise_numeric(d,v)$collect())
    expect_true(is.finite(got$v__mean))
    expect_true(is.finite(got$v__sd))
    if (means[i]==0) expect_identical(got$v__mean,0) else
      expect_equal(got$v__mean/means[i],1,tolerance=1e-12)
    if (sds[i]==0) expect_identical(got$v__sd,0) else
      expect_equal(got$v__sd/sds[i],1,tolerance=1e-12)
    expect_identical(serialize(d,NULL),before)
    rows[[i]] <- data.frame(case=names(fixtures)[i], mean=got$v__mean, expected_mean=means[i],
                            sd=got$v__sd, expected_sd=sds[i])
  }
  write.csv(do.call(rbind,rows),file.path(Sys.getenv("EVANXLSX_DATA_OUT"),"numeric_range.csv"),row.names=FALSE)
})

test_that("range stabilization retains zero, missing, singleton and explicit Inf contracts", {
  for(v in list(rep(0,4),c(NA_real_,NaN),numeric(),c(1e300,NA_real_),c(1e-200,2e-200,Inf))) {
    got <- as.data.frame(summarise_numeric(data.frame(v=v),v)$collect())
    expect_equal(got$v__n_total,got$v__n_valid+got$v__n_missing+got$v__n_infinite)
    if(any(is.infinite(v)) || !sum(is.finite(v))) {
      expect_true(is.na(got$v__mean)); expect_true(is.na(got$v__sd))
    } else if(sum(is.finite(v))==1) expect_true(is.na(got$v__sd)) else
      expect_identical(got$v__sd,0)
  }
  x <- data.frame(g=c("A","A","B","B"),v=c(1e-200,NA_real_,1e200,NA_real_))
  got <- as.data.frame(summarise_numeric(x,v,.by=g,na_rm=FALSE)$collect())
  expect_true(all(is.na(got$v__mean)))
  expect_equal(got$v__n_missing,c(1,1))
})
