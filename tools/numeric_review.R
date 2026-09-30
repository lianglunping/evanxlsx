#!/usr/bin/env Rscript
# Read-only observations on 0.3.0, not acceptance of a proposed fix.
out <- 'validation/numeric-review'; stopifnot(!dir.exists(out)); dir.create(out,recursive=TRUE)
writeLines(c(paste('Commit',Sys.getenv('GITHUB_SHA')),capture.output(sessionInfo())),file.path(out,'environment.txt'))
rows <- list()
cases <- list(ordinary=c(1,2,3,4), small=c(1,2,3,4)*1e-200,
              large=c(1,2,3,4)*1e200, large_mean=rep(1e308,4),
              wide=c(-1e308,0,0,1e308), constant=rep(0,4),
              singleton=c(1e200,NA_real_), missing=c(NA_real_,NaN))
for(nm in names(cases)) {
  v <- cases[[nm]]
  res <- tryCatch(as.data.frame(evanxlsx::summarise_numeric(data.frame(v=v),v)$collect()),error=identity)
  if(inherits(res,'error')) {
    rows[[nm]] <- data.frame(case=nm,metric='ERROR',actual=conditionMessage(res),reference=NA_character_,matches=FALSE)
    next
  }
  f <- v[is.finite(v)]
  s <- if(length(f)) max(abs(f)) else 1
  if(s==0) s<-1
  z <- f/s
  # Independent scaled reference uses R operations only on O(1) values.
  expected <- c(mean=if(length(z)) mean(z)*s else NA_real_,
                median=if(length(z)) median(z)*s else NA_real_,
                sd=if(length(z)>1) stats::sd(z)*s else NA_real_,
                q1=if(length(z)) unname(stats::quantile(z,.25,type=7))*s else NA_real_,
                q3=if(length(z)) unname(stats::quantile(z,.75,type=7))*s else NA_real_,
                iqr=if(length(z)) stats::IQR(z,type=7)*s else NA_real_)
  actual <- as.numeric(res[1,paste0('v__',names(expected))])
  match <- vapply(seq_along(actual),function(i) {
    if(is.na(expected[i])) return(is.na(actual[i]))
    if(is.infinite(expected[i])) return(identical(actual[i],expected[i]))
    is.finite(actual[i]) && (actual[i]==expected[i] || abs((actual[i]-expected[i])/if(expected[i]==0) 1 else expected[i])<1e-12)
  },logical(1))
  rows[[nm]] <- data.frame(case=nm,metric=names(expected),actual=format(actual,digits=17),
                          reference=format(expected,digits=17),matches=match)
}
write.csv(do.call(rbind,rows),file.path(out,'numeric_observations.csv'),row.names=FALSE)
# Record a full-query plan to identify backend execution without promising no hidden materialization.
x <- polars::as_polars_lf(data.frame(g=c('A','A','B','B'),v=c(1,2,NA,4)))
writeLines(evanxlsx::summarise_numeric(x,v,.by=g)$explain(),file.path(out,'plan.txt'))
writeLines('OBSERVATIONS_COMPLETE_NOT_RELEASE_ACCEPTANCE',file.path(out,'STATUS.txt'))
print(do.call(rbind,rows))
