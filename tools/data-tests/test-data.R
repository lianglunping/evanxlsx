out <- Sys.getenv("EVANXLSX_DATA_OUT")
pl <- polars::pl
get <- function(x) as.data.frame(x$collect())
summary_ref <- function(v, na_rm = TRUE) {
  finite <- v[is.finite(v)]
  bad <- any(is.infinite(v)) || (!na_rm && anyNA(v))
  stats <- if (!length(finite) || bad) rep(NA_real_, 6) else
    c(mean(finite), median(finite), sd(finite), quantile(finite, c(.25,.75), type = 7), IQR(finite, type = 7))
  c(n_total = length(v), n_valid = length(finite), n_missing = sum(is.na(v)),
    n_infinite = sum(is.infinite(v)), stats)
}

test_that("numeric semantics match explicit R references including missing and infinity", {
  samples <- list(c(1,2,3,4,100,NA), c(7,NA), c(NA_real_,NaN), c(0,0,0), c(-5,2,9,NaN),
                  c(1,2,Inf,NA), c(-Inf,Inf), numeric())
  for (v in samples) for (remove in c(TRUE, FALSE)) {
    q <- summarise_numeric(data.frame(value = v), value, na_rm = remove)
    expect_s3_class(q, "polars_lazy_frame")
    d <- get(q)
    expect_equal(as.numeric(d[1, ]), unname(summary_ref(v, remove)), tolerance = 1e-12)
    expect_equal(nrow(d), 1L)
  }
})

test_that("multiple groups, null keys, columns and literal names retain explicit order", {
  d <- data.frame(group = c("B","A","B",NA,"A",NA), x = c(1,2,4,NA,6,NaN), y = c(0,1,2,3,4,5))
  names(d)[2] <- "*"
  before <- serialize(d, NULL)
  q <- summarise_numeric(d, tidyselect::all_of(c("*", "y")), .by = group)
  got <- get(q)
  expect_identical(got$group, c("B", "A", NA_character_))
  for (j in seq_len(nrow(got))) {
    idx <- if (is.na(got$group[j])) is.na(d$group) else !is.na(d$group) & d$group == got$group[j]
    expect_equal(as.numeric(got[j,2:11]), unname(summary_ref(d[[2]][idx])), tolerance = 1e-12)
    expect_equal(as.numeric(got[j,12:21]), unname(summary_ref(d$y[idx])), tolerance = 1e-12)
  }
  expect_identical(serialize(d, NULL), before)
  empty <- get(summarise_numeric(d[FALSE,], y, .by = group))
  expect_equal(nrow(empty), 0L)
  expect_error(summarise_numeric(d, group), "ordinary numeric")
  expect_error(summarise_numeric(d, y, .by = y), "overlap")
  expect_error(summarise_numeric(d, tidyselect::where(is.numeric)), "predicate|supported")
  expect_error(summarise_numeric(d, missing_column), "exist")
  expect_error(summarise_numeric(d, y, na_rm = NA), "na_rm")
})

test_that("random finite grouped references agree without mutating or silently selecting IDs", {
  set.seed(20260930)
  d <- data.frame(id = sprintf("%05d",1:120), group = rep(LETTERS[1:6],20),
                   v1 = rnorm(120), v2 = sample(c(NA_real_, -3:10),120,TRUE))
  got <- get(summarise_numeric(d, tidyselect::starts_with("v"), .by = group))
  for (j in 1:6) {
    expect_equal(as.numeric(got[j,2:11]), unname(summary_ref(d$v1[d$group == got$group[j]])), tolerance = 1e-12)
    expect_equal(as.numeric(got[j,12:21]), unname(summary_ref(d$v2[d$group == got$group[j]])), tolerance = 1e-12)
  }
  p <- pl$DataFrame(v = c("9223372036854775807", "1"))$with_columns(pl$col("v")$cast(pl$Int64))
  expect_error(summarise_numeric(p, v), "Int64")
  expect_error(summarise_numeric(dplyr::group_by(d, group), v1), "ungroup")
})

test_that("IQR flagging preserves rows and uses sample-dependent explicit reasons", {
  d <- data.frame(id = sprintf("%03d",1:21), group = rep(c("A","Z","S","I"), c(7,6,3,5)),
                   value = c(1,2,3,4,5,100,NA, 0,0,0,0,0,100, 1,2,NA, 1,2,3,4,Inf))
  before <- serialize(d,NULL)
  got <- get(flag_iqr(d, value, .by = group))
  expect_identical(got[names(d)], d)
  expect_identical(got$iqr_outlier[1:7], c(FALSE,FALSE,FALSE,FALSE,FALSE,TRUE,NA))
  expect_identical(got$iqr_reason[1:7], c(rep("tested",6),"missing"))
  expect_true(all(is.na(got$iqr_outlier[8:21])))
  expect_true(all(got$iqr_reason[8:13] == "zero_iqr"))
  expect_identical(got$iqr_reason[14:16], c("insufficient_n","insufficient_n","missing"))
  expect_true(all(got$iqr_reason[17:21] == "infinite_in_group"))
  expect_identical(serialize(d,NULL), before)
  expect_equal(got$iqr_q1[1],2.25)
  expect_equal(got$iqr_upper[1],8.5)
  expect_error(flag_iqr(got,value), "overwrite")
  expect_error(flag_iqr(d,c(value,id)), "exactly one")
  expect_error(flag_iqr(d,value,k=-1), "k")
  expect_error(flag_iqr(d,value,min_n=2.5), "whole")
  boundary <- get(flag_iqr(data.frame(v=c(-1.5,0,0,0,1,1,1,2.5)),v))
  expect_true(all(boundary$iqr_outlier == FALSE))
  expect_equal(nrow(get(flag_iqr(d[FALSE,],value,.by=group))),0L)
  write.csv(got,file.path(out,"iqr_reference.csv"),row.names=FALSE)
})

test_that("strict literal splitting retains leading zeros, empty fields, and missingness", {
  d <- data.frame(key = c("Chr01::00123","Chr02::00456",NA,"::"), score=1:4)
  got <- get(separate_strict(d,key,c("Chr","Position"),sep="::"))
  expect_identical(got$Chr,c("Chr01","Chr02",NA,""))
  expect_identical(got$Position,c("00123","00456",NA,""))
  expect_identical(got[names(d)],d)
  expect_false("key" %in% names(get(separate_strict(d,key,c("a","b"),"::",remove=TRUE))))
  expect_error(separate_strict(data.frame(key=c("a:b:c","x")),key,c("a","b"),":"),"2 rows")
  expect_error(separate_strict(d,key,c("score","b"),"::"),"overwrite")
  expect_error(separate_strict(d,key,c("a","b"),""),"delimiter")
  expect_error(separate_strict(polars::as_polars_lf(d),key,c("a","b"),"::"),"collect")
  got2 <- get(separate_strict(polars::as_polars_lf(d),key,c("Chr","Position"),"::",collect=TRUE))
  expect_identical(got2,got)
  dots <- get(separate_strict(data.frame(key="a.b"),key,c("a","b"),"."))
  expect_identical(dots$b,"b")
  expect_equal(nrow(get(separate_strict(d[FALSE,],key,c("a","b"),"::"))),0L)
  spaces <- get(separate_strict(data.frame(key="a b"),key,c("a","b")," "))
  expect_identical(spaces$b,"b")
})

test_that("key guards refuse duplicates and missing keys without choosing aggregation", {
  d <- data.frame(id=c("001","001","002"),trait=c("x","y","x"),value=1:3)
  expect_identical(get(assert_unique_keys(d,c(id,trait))),d)
  expect_error(assert_unique_keys(rbind(d,d[1,]),c(id,trait)),"Duplicate")
  x <- d; x$id[1] <- NA
  expect_error(assert_unique_keys(x,c(id,trait)),"Missing")
  expect_identical(get(assert_unique_keys(x,c(id,trait),allow_missing=TRUE)),x)
  expect_error(assert_unique_keys(rbind(x,x[1,]),c(id,trait),allow_missing=TRUE),"Duplicate")
  expect_error(assert_unique_keys(polars::as_polars_lf(d),c(id,trait)),"collect")
  expect_identical(get(assert_unique_keys(polars::as_polars_lf(d),c(id,trait),collect=TRUE)),d)
  expect_equal(nrow(get(assert_unique_keys(d[FALSE,],c(id,trait)))),0L)
  nan <- data.frame(id=c(1,NaN),value=1:2)
  expect_error(assert_unique_keys(nan,id),"Missing")
})

test_that("queries compose with Tidy verbs and real Parquet sources before Excel export", {
  library(dplyr, warn.conflicts=FALSE)
  library(tidyr, warn.conflicts=FALSE)
  library(tidypolars)
  old <- options(tidypolars_unknown_args="error", tidypolars_fallback_to_r=FALSE)
  on.exit(options(old),add=TRUE)
  d <- data.frame(group=rep(c("A","B"),each=6),value=c(1,2,3,4,5,100,2,3,4,5,6,7),
                  key=paste0("Chr01:",sprintf("%05d",1:12)))
  p <- file.path(out,"synthetic.parquet"); polars::as_polars_df(d)$write_parquet(p)
  before <- tools::md5sum(p)
  q <- pl$scan_parquet(p) |> flag_iqr(value,.by=group) |>
    filter(iqr_outlier == FALSE) |> summarise_numeric(value,.by=group)
  got <- get(q)
  expect_equal(got$value__mean,c(3,4.5))
  expect_equal(got$value__n_total,c(5,6))
  expect_identical(tools::md5sum(p),before)
  plan <- q$explain()
  expect_match(toupper(plan),"PARQUET")
  writeLines(plan,file.path(out,"summary_plan.txt"))
  f <- file.path(out,"data_tools.xlsx")
  write_xlsx(list(summary=q,flagged=flag_iqr(d,value,.by=group),
                  split=separate_strict(d,key,c("Chr","Position"),":")), f, collect=TRUE)
  expect_true(file.exists(f))
  expect_equal(as.numeric(openxlsx2::read_xlsx(f,sheet=1)$value__mean),c(3,4.5))
  source(system.file("examples","data_tools.R",package="evanxlsx"),local=TRUE,encoding="UTF-8")
  expect_s3_class(data_tools_example(),"polars_lazy_frame")
})
