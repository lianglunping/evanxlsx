#!/usr/bin/env Rscript
# Independent synthetic probes. Workflow success is NOT release acceptance.
out <- file.path('validation', 'independent-review')
stopifnot(!dir.exists(out))
dir.create(out, recursive = TRUE)
out <- normalizePath(out, winslash = '/')
stopifnot(utils::packageVersion('evanxlsx') == '0.2.0')
writeLines(c(paste('Probe commit:', Sys.getenv('GITHUB_SHA')),
             'Audited implementation: fcd2325aa7e685f19fa116dc4ef452d2d6078709',
             capture.output(sessionInfo()),
             vapply(c('evanxlsx','openxlsx2','xml2','polars'), function(p)
               paste(p, utils::packageVersion(p)), character(1))), file.path(out, 'environment.txt'))
utils::write.csv(tools::md5sum(list.files('R', full.names = TRUE)), file.path(out,'source-md5.csv'))
observations <- data.frame(id=character(), verdict=character(), expected=character(), observed=character())
record <- function(id, verdict, expected, observed) {
  observations <<- rbind(observations, data.frame(id=id, verdict=verdict, expected=expected,
    observed=paste(observed, collapse=' | ')))
  utils::write.csv(observations, file.path(out, 'observations.csv'), row.names = FALSE)
  cat(id, ': ', verdict, '\n', paste(observed, collapse=' | '), '\n', sep='')
}
probe <- function(id, expected, f) {
  tryCatch({r <- f(); record(id, r$verdict, expected, r$observed)},
    error=function(e) record(id, 'PROBE_ERROR', expected, conditionMessage(e)))
}
export <- function(x, id, ...) {
  f <- file.path(out, paste0(id, '.xlsx'))
  warnings <- character()
  error <- tryCatch({withCallingHandlers(evanxlsx::write_xlsx(x, f, ...),
    warning=function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart('muffleWarning')}); NULL},
    error=conditionMessage)
  list(file=f, error=error, warnings=warnings)
}
part <- function(f, name) {
  folder <- tempfile(); dir.create(folder)
  on.exit(unlink(folder, recursive=TRUE), add=TRUE)
  utils::unzip(f, files=name, exdir=folder)
  doc <- xml2::read_xml(file.path(folder,name)); xml2::xml_ns_strip(doc); doc
}
cells <- function(f) {
  doc <- part(f, 'xl/worksheets/sheet1.xml')
  nodes <- xml2::xml_find_all(doc, './/sheetData/row/c')
  data.frame(address=xml2::xml_attr(nodes,'r'), type=xml2::xml_attr(nodes,'t'),
    value=xml2::xml_text(xml2::xml_find_first(nodes,'is/t|v')), stringsAsFactors=FALSE)
}
pl <- polars::pl
probe('C01_basic_control', 'ordinary strings, numeric and missing values retained', function() {
  x <- data.frame(id=c('0001','0002'), score=c(0.25,NA_real_))
  e <- export(x,'C01'); stopifnot(is.null(e$error))
  d <- cells(e$file); utils::write.csv(d,file.path(out,'C01_cells.csv'),row.names=FALSE)
  ok <- d$value[d$address=='A2']=='0001' && d$value[d$address=='B2']=='0.25' && is.na(d$value[d$address=='B3'])
  list(verdict=if(ok) 'PASS' else 'FAIL', observed=capture.output(print(d)))
})
probe('F01_regex_datetime_name', 'literal header ^value$ must not select numeric column value; time must remain exact text', function() {
  x <- pl$DataFrame(ts=c('2026-09-30 01:02:03.123456789',NA_character_), value=1:2)$with_columns(
    pl$col('ts')$str$to_datetime(time_unit='ns'))$select(pl$col('ts')$alias('^value$'), pl$col('value'))
  stopifnot(identical(names(x$schema), c('^value$', 'value')))
  e <- export(x,'F01')
  if(!is.null(e$error)) return(list(verdict='PRODUCT_ERROR', observed=e$error))
  d <- cells(e$file); utils::write.csv(d,file.path(out,'F01_cells.csv'),row.names=FALSE)
  a <- d[d$address=='A2',]; b <- d[d$address=='B2',]
  ok <- identical(a$type,'inlineStr') && identical(a$value,'2026-09-30 01:02:03.123456789') &&
    (is.na(b$type) || b$type=='n')
  list(verdict=if(ok) 'PASS' else 'FAIL', observed=capture.output(print(d)))
})
probe('F02_wildcard_datetime_name', 'literal header * must not convert ordinary numeric columns to text', function() {
  x <- pl$DataFrame(ts=c('2026-09-30 01:02:03.123456789',NA_character_), value=1:2)$with_columns(
    pl$col('ts')$str$to_datetime(time_unit='ns'))$select(pl$col('ts')$alias('*'), pl$col('value'))
  stopifnot(identical(names(x$schema), c('*', 'value')))
  e <- export(x,'F02')
  if(!is.null(e$error)) return(list(verdict='PRODUCT_ERROR', observed=e$error))
  d <- cells(e$file); utils::write.csv(d,file.path(out,'F02_cells.csv'),row.names=FALSE)
  b <- d[d$address=='B2',]
  list(verdict=if(is.na(b$type) || b$type=='n') 'PASS' else 'FAIL', observed=capture.output(print(d)))
})
probe('F03_literal_time_name', 'literal regex-like Time header exports without selecting a different column', function() {
  x <- pl$DataFrame(ns=c('3723123456789',NA_character_), value=1:2)$with_columns(
    pl$col('ns')$cast(pl$Int64)$cast(pl$Time))$select(pl$col('ns')$alias('^value$'), pl$col('value'))
  stopifnot(identical(names(x$schema), c('^value$', 'value')))
  e <- export(x,'F03')
  if(!is.null(e$error)) return(list(verdict='PRODUCT_ERROR', observed=e$error))
  d <- cells(e$file); utils::write.csv(d,file.path(out,'F03_cells.csv'),row.names=FALSE)
  list(verdict=if(identical(d$value[d$address=='A2'],'01:02:03.123456789')) 'PASS' else 'FAIL',
    observed=capture.output(print(d)))
})
probe('F04_rownames', 'identify whether nondefault gene row names are retained or explicitly warned about', function() {
  x <- data.frame(value=c(10,20), row.names=c('LOC_Os01g00010','LOC_Os01g00020'))
  e <- export(x,'F04'); stopifnot(is.null(e$error))
  d <- cells(e$file)
  kept <- all(rownames(x) %in% d$value)
  list(verdict=if(kept || length(e$warnings)) 'NOTICE_OR_RETAINED' else 'SILENT_OMISSION',
    observed=c(paste('warnings:',paste(e$warnings,collapse=';')),capture.output(print(d))))
})
probe('F05_inherited_numfmt', 'compare display formats with and without unrelated global openxlsx2.numFmt', function() {
  old <- options(openxlsx2.numFmt=NULL); on.exit(options(old),add=TRUE)
  a <- export(data.frame(value=0.12345),'F05_clean')
  options(openxlsx2.numFmt='0.00%')
  b <- export(data.frame(value=0.12345),'F05_global')
  stopifnot(is.null(a$error),is.null(b$error))
  sa <- xml2::xml_find_all(part(a$file,'xl/styles.xml'),'.//numFmt')
  sb <- xml2::xml_find_all(part(b$file,'xl/styles.xml'),'.//numFmt')
  va <- xml2::xml_attr(sa,'formatCode'); vb <- xml2::xml_attr(sb,'formatCode')
  list(verdict=if(identical(va,vb)) 'UNCHANGED' else 'GLOBAL_DISPLAY_DEPENDENCY',
    observed=c(paste('clean:',paste(va,collapse=';')),paste('global:',paste(vb,collapse=';'))))
})
probe('F06_ignored_max_width', 'documented ignored max_width should not block fixed-width export', function() {
  e <- export(data.frame(value=1),'F06',widths=16,max_width=NULL)
  list(verdict=if(is.null(e$error)) 'PASS' else 'PRODUCT_ERROR',observed=if(is.null(e$error)) 'written' else e$error)
})
# Fault injection is limited to a copied function and new synthetic output paths.
for(existing in c(FALSE,TRUE)) {
  id <- if(existing) 'F07_partial_existing' else 'F08_partial_new'
  probe(id,'observe recovery after simulated partial final copy; never use a real user file',local({
    keep_existing <- existing; keep_id <- id
    function() {
      f <- file.path(out,paste0(keep_id,'.xlsx'))
      if(keep_existing) writeLines('ORIGINAL SYNTHETIC CONTENT',f)
      original <- if(keep_existing) readBin(f,'raw',n=file.info(f)$size) else raw()
      fun <- evanxlsx::write_xlsx
      local_env <- new.env(parent=environment(fun))
      local_env$file.copy <- function(from,to,...) {
        if(startsWith(basename(from),'.evanxlsx-')) {
          writeBin(charToRaw('PARTIAL!'),to); return(FALSE)
        }
        base::file.copy(from,to,...)
      }
      environment(fun) <- local_env
      err <- tryCatch({fun(data.frame(x=1),f,overwrite=keep_existing);NULL},error=conditionMessage)
      contents <- if(file.exists(f)) rawToChar(readBin(f,'raw',n=file.info(f)$size)) else 'ABSENT'
      bak <- list.files(out,pattern=paste0('^',basename(f),'.*\\.bak$'),full.names=TRUE)
      recovered <- if(length(bak)==1L) identical(readBin(bak,'raw',n=file.info(bak)$size),original) else FALSE
      list(verdict=if(identical(contents,'PARTIAL!')) 'PARTIAL_TARGET_REMAINS' else 'RECOVERED',
        observed=c(paste('error:',err),paste('target:',contents),paste('backup contains original:',recovered)))
    }
  }))
}
probe('C02_plain_text_safety', 'formula-like strings, leading/trailing spaces and literal escapes stay strings', function() {
  v <- c('=1+1',' LOC_Os01g00010 ','_x0041_','NA','',NA_character_)
  e <- export(data.frame(value=v),'C02');stopifnot(is.null(e$error))
  d <- cells(e$file); b <- d$value[d$address!='A1']
  ws <- part(e$file,'xl/worksheets/sheet1.xml')
  formulas <- length(xml2::xml_find_all(ws,'.//f'))
  list(verdict=if(identical(b,v) && formulas==0L) 'PASS' else 'FAIL',
    observed=c(paste('formula nodes:',formulas),capture.output(print(d))))
})
probe('P01_positional_prototype', 'two-expression isolated prototype retains all tested literal names and types', function() {
  # Prototype only: no write to R/, no modification of the installed namespace.
  src <- readLines('R/backends.R')
  stopifnot(sum(grepl('polars::pl$col(datetime)',src,fixed=TRUE))==1L,
            sum(grepl('polars::pl$col(clock)',src,fixed=TRUE))==1L)
  src <- gsub('polars::pl$col(datetime)', 'polars::pl$nth(which(meta$types == "Datetime") - 1L)',src,fixed=TRUE)
  src <- gsub('polars::pl$col(clock)', 'polars::pl$nth(which(meta$types == "Time") - 1L)',src,fixed=TRUE)
  writeLines(src,file.path(out,'prototype_backends_NOT_RELEASE.R'))
  env <- new.env(parent=asNamespace('evanxlsx'))
  eval(parse(text=src),envir=env)
  fun <- evanxlsx::write_xlsx; environment(fun) <- env
  count <- 0L
  for(nm in c('^value$','*','ordinary')) for(kind in c('Datetime','Time')) for(lazy in c(FALSE,TRUE)) {
    dt <- pl$DataFrame(ts=c('2026-09-30 01:02:03.123456789',NA_character_),value=1:2)$with_columns(
      pl$col('ts')$str$to_datetime(time_unit='ns'))
    tm <- pl$DataFrame(ts=c('3723123456789',NA_character_),value=1:2)$with_columns(
      pl$col('ts')$cast(pl$Int64)$cast(pl$Time))
    x <- if(kind=='Datetime') dt else tm
    x <- x$select(pl$col('ts')$alias(nm), pl$col('value'))
    expected <- if(kind=='Datetime') '2026-09-30 01:02:03.123456789' else '01:02:03.123456789'
    count <- count+1L; f <- file.path(out,sprintf('P01_%02d.xlsx',count))
    fun(if(lazy) x$lazy() else x, f, collect=TRUE)
    d <- cells(f)
    stopifnot(identical(d$value[d$address=='A1'],nm),
              identical(d$type[d$address=='A2'],'inlineStr'),
              identical(d$value[d$address=='A2'],expected),
              is.na(d$value[d$address=='A3']),
              is.na(d$type[d$address=='B2']) || d$type[d$address=='B2']=='n',
              identical(d$value[d$address=='B2'],'1'))
  }
  list(verdict='PROTOTYPE_PASS_NOT_RELEASE',observed=paste(count,'eager/lazy exports; two selection expressions changed'))
})
writeLines('PROBES_COMPLETE_NOT_RELEASE_ACCEPTANCE',file.path(out,'STATUS.txt'))
print(observations)
stopifnot(!any(observations$verdict=='PROBE_ERROR'))
