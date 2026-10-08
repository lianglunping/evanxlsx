\name{mutate_row_stats}
\alias{mutate_row_stats}
\title{Append Row-Wise Mean and Sample Standard Deviation}
\usage{mutate_row_stats(.data, .cols, na_rm = TRUE, prefix = "row")}
\arguments{
\item{.data}{Ungrouped data.frame or R Polars DataFrame/LazyFrame.}
\item{.cols}{Tidy selection of comparable numeric replicate columns, e.g. c(rep1, rep2, rep3). Same supported measurement types as summarise_numeric.}
\item{na_rm}{Ignore null/NA and NaN, default TRUE. FALSE propagates missingness to row statistics.}
\item{prefix}{Prefix of appended _n, _mean and _sd columns, default row. Existing names are not overwritten.}
}
\value{Polars LazyFrame with original rows/columns plus finite count, mean and sample SD.}
\description{A single native-Polars operation for repeated measurements within rows.}
\details{
Finite values count toward _n. Any Inf makes row mean/SD missing. All-missing means
and SD are missing; singleton SD is missing. SD uses n-1. Binary rescaling reduces
intermediate overflow/underflow but does not create arbitrary precision or make
unrepresentable true results finite. Inputs, including NA/NaN and Inf, are retained
unchanged. No imputation, outlier removal or row deletion occurs. This helper builds
a query, not R row-wise callbacks. It requires the same optional dependencies and
ungrouped-input rules as summarise_numeric. Do not average measurements of incompatible units.
}
\examples{
\dontrun{
x <- data.frame(rep1 = c(1, NA), rep2 = c(3, 5))
q <- mutate_row_stats(x, c(rep1, rep2))
as.data.frame(q$collect())
}
}
