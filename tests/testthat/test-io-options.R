test_that("selection and named column types work without an optional engine", {
  x <- data.frame(id=c("001","002"), score=c(1.5,2.5), count=c(1L,2L),
                  flag=c(TRUE,FALSE), day=as.Date(c("2026-01-01","2026-01-02")))
  for (ext in c("csv","tsv","txt","xlsx")) {
    f <- tempfile(fileext=paste0(".",ext)); export(x,f)
    y <- import(f, cols=c("score","id"), types=c(id="character",score="double"))
    expect_identical(names(y),c("score","id"))
    expect_identical(y$id,x$id); expect_equal(y$score,x$score)
    z <- import(f, types=c(id="character",count="integer",flag="logical",day="date"))
    expect_type(z$count,"integer"); expect_identical(z$flag,x$flag)
    expect_s3_class(z$day,"Date"); expect_equal(as.numeric(z$day),as.numeric(x$day))
    expect_equal(ncol(import(f,cols=c(2L,1L))),2L)
    expect_error(import(f,types=c(id="character"),text_cols="score",cols="id"))
  }
})

test_that("schema mistakes and impossible conversions are not silently accepted", {
  f <- tempfile(fileext=".csv"); export(data.frame(x="abc",id="001"),f)
  expect_error(import(f,types="double"),"named")
  expect_error(import(f,types=c(x="currency")),"Column types")
  expect_error(import(f,types=c(id="double"),text_cols="id"),"Conflicting")
  expect_error(suppressWarnings(import(f,types=c(x="double"))))
  expect_error(import(f,lazy=NA),"lazy")
  expect_error(import(f,comment=NA),"comment")
  g <- tempfile(fileext=".xlsx"); export(data.frame(x=1.5),g)
  expect_error(import(g,types=c(x="integer")),"lose a value")
  expect_error(import(g,lazy=TRUE),"no scan backend")
  expect_error(import(g,comment="#"),"text files")
  expect_error(import(g,cols="absent"),"not found")
  # Preserve old numeric openxlsx2 type codes when explicitly requested.
  expect_type(import(g,types=c(x=0))$x,"character")
})
