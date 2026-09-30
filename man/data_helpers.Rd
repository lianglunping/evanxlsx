\name{data_helpers}
\alias{summarise_numeric}
\alias{flag_iqr}
\alias{separate_strict}
\alias{assert_unique_keys}
\title{Optional Tidy-Selection Helpers Executed by R Polars}
\usage{
summarise_numeric(.data, .cols, .by = NULL, na_rm = TRUE)
flag_iqr(.data, .col, .by = NULL, k = 1.5, min_n = 4L, prefix = "iqr")
separate_strict(.data, col, into, sep, remove = FALSE, collect = FALSE)
assert_unique_keys(.data, .cols, allow_missing = FALSE, collect = FALSE)
}
\arguments{
\item{.data}{An ungrouped ordinary data.frame or R Polars DataFrame/LazyFrame. Data frames become Polars queries. Collect duckplyr explicitly first. Existing grouped_df/rowwise_df objects are rejected: use explicit .by.}
\item{.cols}{Tidy selection of existing columns, such as c(height, weight), starts_with("trait_"), or all_of(a_character_vector). Renaming and predicate selection such as where() are not supported.}
\item{.col, col}{Tidy selection of exactly one existing column.}
\item{.by}{Tidy selection of grouping columns, NULL for the whole input. Group order follows first appearance; grouping metadata are not attached to results.}
\item{na_rm}{Whether summary statistics ignore null and NaN, both treated as missing. Default TRUE. FALSE makes all descriptive statistics missing in any group containing missing observations. Counts are always returned.}
\item{k}{Nonnegative finite IQR fence multiplier. Default 1.5; a screening rule, not a statistical significance test.}
\item{min_n}{Minimum finite observations for IQR screening; integer at least 2, default 4. This working convention is configurable and is not a universal sample-size recommendation.}
\item{prefix}{Prefix for the seven IQR annotation columns. Existing columns are never overwritten.}
\item{into}{Unique output field names that do not already exist in the input.}
\item{sep}{One non-empty literal delimiter, not a regular expression. No quote/escape parsing is performed.}
\item{remove}{Remove the original split column? Default FALSE. New character fields are appended; empty strings and leading zeros are retained.}
\item{collect}{Permit immediate validation execution for LazyFrame input. FALSE by default. This is validation permission, not a request to return an R data.frame. In-memory inputs are validated without this extra permission.}
\item{allow_missing}{Allow missing key values? Default FALSE. Allowed missing keys still participate in uniqueness checks. Floating NaN is considered missing.}
}
\value{An ordinary Polars LazyFrame, composable with supported tidypolars verbs or write_xlsx(collect=TRUE). No R row-wise callback or automatic computation fallback is used.}
\description{Adds a small set of explicit data-quality rules without reimplementing dplyr/tidyr or requiring optional processing dependencies for Excel-only use.}
\details{
These functions require separately installed polars (>=1.16.0 and <2.0.0), rlang
and tidyselect. Tidypolars is only needed when combining with Tidy verbs.
Nothing is automatically installed. No global options or original input objects
are intentionally modified. Important row names must be explicit columns.

\strong{Summary semantics.} Each selected column produces suffixes
\code{__n_total}, \code{__n_valid}, \code{__n_missing}, \code{__n_infinite},
\code{__mean}, \code{__median}, \code{__sd}, \code{__q1}, \code{__q3}, \code{__iqr}.
Valid means finite: the three counts sum to total. NaN and null count as missing.
Any infinity makes all descriptive statistics missing for that group/column,
with the infinity count exposing the condition; infinity is never silently
excluded as if it were an ordinary missing observation. SD is sample SD (ddof=1).
Quantiles use linear interpolation corresponding to R quantile type=7 on finite
data. An all-missing or empty ungrouped input has missing descriptive statistics;
SD is missing below two valid observations. Empty grouped input has zero rows.
No NA-versus-NaN round-trip distinction is claimed for summary outputs.
Ordinary 8/16/32-bit integers, UInt32 and Float32/Float64 measurements are supported.
Int64/UInt64, Decimal and nonnumeric measurements require explicit upstream
conversion; character IDs and grouping keys are not implicitly converted to numbers.

\strong{IQR flags.} Original columns and rows are preserved. Added fields are
prefix_n_valid, prefix_q1, prefix_q3, prefix_lower, prefix_upper, prefix_outlier,
prefix_reason. Quartiles use the same finite-data convention. Bounds are Q1-k*IQR
and Q3+k*IQR. Strictly outside is TRUE; equality is not an outlier. A missing row,
any infinity in its group, too few valid observations, or zero IQR yields a
missing flag, not FALSE. Reasons, in precedence order, are missing,
infinite_in_group, insufficient_n, zero_iqr and tested. In zero-IQR groups bounds
are shown but no outlier classification is made. No rows are deleted and no
post-exclusion mean is calculated automatically.

\strong{Strict validation.} separate_strict executes a scalar malformed-row
count in Polars and errors unless every nonmissing string has exactly the required
number of fields. Missing strings produce missing fields; adjacent delimiters
produce empty fields, not missing values. assert_unique_keys executes grouped
counts and returns the original query only when key rules pass. It never guesses
a pivot aggregation. Guards scan their inputs; collecting later can execute the
source again. Only small validation aggregates are returned to R, but engine work
is not bounded by their output size. These are checks at validation time, not
snapshot isolation against changing files or databases. Use stable sources.
Summary and flag helpers only build expressions (schema lookup may read metadata).
}
\examples{
\dontrun{
x <- data.frame(group = c("A", "A", "B", "B"), value = c(1, 2, 3, NA))
q <- summarise_numeric(x, value, .by = group)
as.data.frame(q$collect())
write_xlsx(q, tempfile(fileext = ".xlsx"), collect = TRUE)
}
}
