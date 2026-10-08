\name{import_export}
\alias{import}
\alias{export}
\title{Read and Write XLSX, TXT, TSV and CSV}
\usage{
import(file, sheet = 1, sep = NULL, text_cols = NULL, na = "", ...)
export(x, file, sheet = "Sheet1", sep = NULL, overwrite = FALSE,
       collect = FALSE, na = "", ...)
}
\arguments{
\item{file}{One local filename ending in .xlsx, .txt, .tsv or .csv, case-insensitively. Its extension selects the reader/writer. No compressed, remote or arbitrary-text-file formats are inferred.}
\item{x}{One data.frame/tibble or supported Polars/duckplyr table. For XLSX, a named list writes multiple worksheets.}
\item{sheet}{XLSX sheet name or 1-based index for reading; one new sheet name for a single output table. A named output list determines its own sheet names. Not used for text files.}
\item{sep}{Text delimiter. Default comma for CSV, tab for TXT/TSV. Supply a single-byte delimiter for other delimited TXT files. Not a general whitespace or quoted-document parser.}
\item{text_cols}{Names of columns to read as text before type inference, useful for leading zeros and long identifiers. Other columns are inferred. This cannot recover precision lost before the file was written. Do not combine with text col_types.}
\item{na}{Missing-value marker(s) for reading, one marker for text writing. Default blank; literal NA is not a missing marker. Exported XLSX missing values are always empty cells. To read literal NA as missing too, use \code{na = c("", "NA")}.}
\item{overwrite}{Default FALSE. TRUE keeps a backup and replaces the whole file; not append or sheet-only replacement.}
\item{collect}{Allow execution of a Polars LazyFrame or duckplyr query before export. Default FALSE. Text export materializes the full result, not a streaming sink or a memory-bounded writer.}
\item{...}{Named advanced arguments. XLSX import delegates to openxlsx2::wb_to_df (for example dims, types); XLSX export delegates to write_xlsx (font, font_size, align and other existing parameters). Text import delegates to readr::read_delim (col_types, locale, skip); text output delegates to readr::write_delim (quote, eol). Use sep, not delim, to select the delimiter. Appending and changing the output file through these arguments are not supported.}
}
\value{import returns a tibble. export invisibly returns the output path.}
\description{Two everyday entry points selected by file extension. Readers and writers are internal implementation choices, not packages users need to choose for each file.}
\details{
XLSX uses openxlsx2 and the existing formatted writer. Text uses readr with UTF-8
output, normal quoting for embedded delimiters/quotes/newlines, no automatic whitespace
trimming and no automatic column-name repair. Parsing problems are errors rather
than silently accepted missing measurements. Additional readr or openxlsx2 options
retain their documented meanings; they are not all shared across formats.

Blank strings and empty spreadsheet cells may both read as missing. Delimited files
do not retain all column types; explicitly protect important identifiers with
text_cols. A chosen missing token occurring in real data is ambiguous: choose a
different token and use it consistently. Import is eager and returns in-memory R
data; advanced out-of-core scans remain available in Polars. No formula evaluation
or preservation of workbook styling is claimed during import. For spreadsheet
viewing of formula-like text or identifiers, XLSX is preferable to double-clicking
CSV in Excel, which may independently reinterpret text.

Text output rejects nested/matrix, raw, complex and R integer64 columns unless
converted explicitly. It does not apply Excel's cell-text or row limits. Polars
wide integers and temporal values reuse the package's text-preserving conversion.
The old write_xlsx API and formatting remain available. All outputs reuse the
single-writer backup/recovery policy; it is not a filesystem transaction.
}
\seealso{\code{\link{write_xlsx}}, \code{\link[readr:read_delim]{readr::read_delim}},
\code{\link[openxlsx2:wb_to_df]{openxlsx2::wb_to_df}}}
\examples{
x <- data.frame(id = c("001", "002"), value = c(1, NA_real_))
f <- tempfile(fileext = ".csv")
export(x, f)
import(f, text_cols = "id")
unlink(f)
f <- tempfile(fileext = ".xlsx")
export(list(var = x, id83 = x), f)
import(f, sheet = "var")
unlink(f)
}
