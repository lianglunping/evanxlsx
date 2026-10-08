io_df <- function(x) as.data.frame(x$collect())

test_that("prefix comments preserve literal LF/CRLF inside quoted fields", {
  # Write exact bytes, rather than platform-dependent writeLines() output.
  for (eol in c("\n", "\r\n")) {
    f <- tempfile(fileext=".tsv")
    lines <- c('# metadata', 'id\tx\tnote', '001\t1.5\tgene#tag',
      '# skip this line', '002\t2.5\t"line one', '# inside quoted field"')
    writeBin(charToRaw(paste0(paste(lines, collapse=eol), eol)), f)
    for (lazy in c(FALSE,TRUE)) {
      q <- import(f, comment="#", types=c(id="character",x="double"), lazy=lazy)
      y <- if (lazy) io_df(q) else as.data.frame(q)
      expect_identical(y$id,c("001","002"))
      expect_equal(y$x,c(1.5,2.5))
      expect_identical(y$note,c("gene#tag",paste0("line one",eol,"# inside quoted field")))
    }
    expect_identical(import(f,comment="#",cols=c("x","id"),types=c(id="character"))$id,c("001","002"))
  }
})

test_that("lazy text and parquet keep selection and types in a real file query", {
  d <- data.frame(id=c("001","002","003"),x=c(1,2,3),note=c("Rice \u6c34\u7a3b",NA,"NA"))
  for (ext in c("csv","tsv","txt","parquet","PARQUET")) {
    f <- tempfile(fileext=paste0(".",ext)); export(d,f)
    q <- import(f, lazy=TRUE, cols=c("x","id"), types=c(x="double",id="character"))
    expect_s3_class(q,"polars_lazy_frame")
    expect_identical(names(q$collect_schema()),c("x","id"))
    expect_equal(io_df(q),d[c("x","id")])
    expect_match(toupper(q$explain()),if(tolower(ext)=="parquet") "PARQUET" else "CSV")
    moved <- paste0(f,".saved"); stopifnot(file.rename(f,moved))
    expect_error(q$collect())
    stopifnot(file.rename(moved,f))
    expect_equal(io_df(q),d[c("x","id")])
  }
})

test_that("Parquet retains native types and backup policy instead of using Excel conversions", {
  pl <- polars::pl
  p <- pl$DataFrame(id=c("9223372036854775807",NA_character_),x=c(1.5,2.5))$
    with_columns(pl$col("id")$cast(pl$Int64))
  f <- tempfile(fileext=".parquet"); export(p,f)
  q <- import(f,lazy=TRUE)
  expect_identical(format(q$collect_schema()$id,abbreviated=FALSE),"Int64")
  expect_identical(as.data.frame(q$collect(),int64="character")$id,c("9223372036854775807",NA_character_))
  expect_identical(import(f)$id,c("9223372036854775807",NA_character_))
  hash <- tools::md5sum(f)
  expect_error(export(stop("INPUT_FORCED"),f),"already exists")
  expect_error(import(f,types=c(x="integer")),"round/check")
  target <- tempfile(fileext=".parquet")
  expect_error(export(q,target),"collect")
  expect_no_error(export(q,target,collect=TRUE))
  expect_identical(format(import(target,lazy=TRUE)$collect_schema()$id,abbreviated=FALSE),"Int64")
  suppressMessages(export(data.frame(v=2),f,overwrite=TRUE))
  b <- Sys.glob(paste0(f,".*.bak")); expect_length(b,1L)
  expect_identical(unname(tools::md5sum(b)),unname(hash))
  expect_error(import(f,sep=";"),"text-only")
  expect_error(export(data.frame(v=1),tempfile(fileext=".parquet"),na="NA"),"text-only")
})

test_that("lazy parse errors remain errors at execution, not fabricated missing values", {
  f <- tempfile(fileext=".csv"); writeLines(c('id,x','001,1','002,no_number'),f)
  q <- import(f,lazy=TRUE,types=c(id="character",x="double"))
  expect_error(q$collect())
  expect_error(import(f,lazy=TRUE,cols="not_found"),"not found")
  g <- tempfile(fileext=".csv")
  writeLines(c('id,date,flag','001,2026-01-01,true','002,2026-01-02,false'),g)
  y <- io_df(import(g,lazy=TRUE,types=c(id="character",date="date",flag="logical")))
  expect_identical(y$id,c("001","002")); expect_s3_class(y$date,"Date")
  expect_identical(y$flag,c(TRUE,FALSE))
})
