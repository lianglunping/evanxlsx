\name{import_export}
\alias{import}
\alias{export}
\title{Import and Export Common Table Files}
\usage{
import(file, sheet = 1, sep = NULL, text_cols = NULL, na = "",
       cols = NULL, types = NULL, comment = "", lazy = FALSE, ...)
export(x, file, sheet = "Sheet1", sep = NULL, overwrite = FALSE,
       collect = FALSE, na = "", ...)
}
\arguments{
\item{file}{One local XLSX, TXT, TSV, CSV or Parquet path; extension selects the format.}
\item{x}{One table, or a named list for XLSX. Supported backend queries require collect=TRUE on export.}
\item{sheet}{XLSX sheet name/index on import; name for a single exported table. A named list supplies sheet names.}
\item{sep}{Text delimiter, default comma for CSV and tab for TXT/TSV.}
\item{text_cols}{Character vector of columns to keep as text, before inference; shorthand for types.}
\item{na}{Text values treated as missing on import, or a single missing marker on text export. Default empty string. Parquet uses native nulls and rejects this text setting.}
\item{cols}{Character vector of column names or positive positions, in desired output order; default all. XLSX reads before subsetting, not a sparse scanner.}
\item{types}{Named character vector: character, double (alias numeric), integer, logical or date. ISO dates for text input. Applies to retained columns. Legacy numeric openxlsx2 type codes still work for XLSX. Inference is not lossless for arbitrary IDs: declare those character. Parquet floating-to-integer casts are refused until explicitly handled upstream.}
\item{comment}{Literal prefix of text comment records, e.g. \code{"#"}. Empty disables comments. Uses the optional Polars scanner for prefix-only semantics, not readr's inline-comment truncation. Quoted content is parsed by the backend, not filtered by an R line loop.}
\item{lazy}{TRUE returns a native Polars LazyFrame for text/Parquet. Schema lookup can read headers or sample records. XLSX rejects TRUE. FALSE returns a tibble.}
\item{overwrite}{FALSE by default; TRUE backs up and replaces a whole file, not a single worksheet.}
\item{collect}{Explicit permission to execute a backend query during export. Parquet uses sink_parquet rather than converting the full query result to R. Text/Excel output still materializes.}
\item{...}{Named backend options: wb_to_df for XLSX import, read_delim for ordinary text, scan_csv for lazy/comment-prefixed text, scan_parquet for Parquet; write_xlsx, write_delim or sink_parquet on export. Unsupported options error. Prefer common arguments above; do not mix types with backend schema options.}
}
\value{import returns a tibble or (lazy=TRUE) a native Polars LazyFrame. export invisibly returns the output path.}
\description{Two entry points for everyday file I/O with explicit advanced options and no runtime software installation.}
\details{
Ordinary text uses readr. Lazy text, prefix comments and Parquet require optional
polars >=1.16.0,<2.0.0. Important types should be explicit because inference differs
by backend. Parse errors are errors, possibly deferred until lazy execution.
Parquet has stored schemas and nulls: sep/comment/na do not apply. Lazy native types
are preserved. Eager Parquet conversion uses the existing exact-text policy for
wide integers, Decimal and high-precision temporal columns. Empty strings and empty
Excel cells can collapse together on readback; do not infer lossless R-type round trips.

New import options are appended after the old positional arguments. Existing
readr col_types and XLSX numeric types remain available; contradictory declarations
are errors. Names are selected literally, without interpreting wildcard-like names.
The single-file API does not promise all historical file schemas/encodings or
arbitrary reader-option combinations behave identically across backends.

Excel formatting and file backup/recovery remain unchanged. The Parquet writer
uses a temporary file and the same best-effort single-writer final-copy protection.
Native sinks do not bound memory for all query operators and do not provide a
concurrent-writer lock. Files used by lazy queries must remain available/stable
until execution. No compressed-extension routing or remote URL support is implied.
}
\examples{
x <- data.frame(id = c("001", "002"), value = c(1, NA))
f <- tempfile(fileext = ".csv")
export(x, f)
import(f, cols = c("id", "value"), types = c(id = "character"))
unlink(f)
}
