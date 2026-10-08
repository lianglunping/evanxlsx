# Execute the actual four-section README in a new directory.
local({
  root <- normalizePath(".")
  text <- readLines("README.md", encoding="UTF-8",warn=FALSE)
  stopifnot(identical(grep("^## ",text,value=TRUE),c(
    "## 1、包的安装","## 2、数据读取","## 3、数据输出","## 4、数据处理")))
  work <- tempfile("quickstart-",tmpdir=file.path(root,"validation")); dir.create(work,recursive=TRUE)
  old <- setwd(work); on.exit(setwd(old),add=TRUE)
  d <- data.frame(Sample_ID=sprintf("%03d",1:8), treatment=rep(c("A","B"),each=4),
    rep1=c(1,2,3,4,5,6,7,8),rep2=c(2,3,NA,5,6,7,8,9),rep3=c(3,4,5,6,7,8,9,10),
    note=c(" Rice ","",NA,"NA","Test","Test","Test","Test"))
  d1 <- data.frame(category=c("DEL","INS"),count=c(3,2))
  evanxlsx::export(list(var=d,id83=d1),"data.xlsx")
  for(ext in c("csv","tsv","txt","parquet")) evanxlsx::export(d,paste0("data.",ext))
  writeLines(c("# metadata",readLines("data.tsv")),"annotated.tsv",useBytes=TRUE)
  env <- new.env(parent=asNamespace("evanxlsx"))
  marks <- grep("^<!-- example:",text)
  results <- data.frame(example=character(),status=character())
  for(i in marks) {
    stopifnot(text[i+1L]=="```r")
    end <- i+1L+which(text[seq.int(i+2L,length(text))]=="```")[1]
    eval(parse(text=text[seq.int(i+2L,end-1L)]),envir=env)
    results <- rbind(results,data.frame(example=text[i],status="PASS"))
    write.csv(results,"examples.csv",row.names=FALSE)
  }
  stopifnot(nrow(results)==11L,
    identical(env$picked$Sample_ID,d$Sample_ID),
    identical(env$annotated$Sample_ID,d$Sample_ID),
    inherits(env$q,"polars_lazy_frame"),
    nrow(env$report)==nrow(d)+2L)
  means <- tail(env$report,2)$rep1
  stopifnot(isTRUE(all.equal(means,c(mean(d$rep1),sd(d$rep1)))),
    identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load("WES.xlsx"))),c("var","id83")))
  y <- evanxlsx::import("row_stats.xlsx")
  target <- rowMeans(d[c("rep1","rep2","rep3")],na.rm=TRUE)
  stopifnot(isTRUE(all.equal(y$row_mean,target,tolerance=1e-12)))
  writeLines(env$lazy_summary$explain(),"query_plan.txt")
  writeLines("PASS","STATUS.txt")
})
