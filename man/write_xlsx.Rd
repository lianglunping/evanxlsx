\name{write_xlsx}
\alias{write_xlsx}
\title{Export Data Frames with Consistent Excel Formatting}
\usage{
write_xlsx(
  x, file, sheet = "Sheet1",
  font = getOption("evanxlsx.font", "Times New Roman"),
  font_size = getOption("evanxlsx.font_size", 11),
  align = getOption("evanxlsx.align", "center"),
  header_align = "center", valign = "center", wrap = TRUE,
  widths = "auto", max_width = 40,
  freeze = TRUE, freeze_first_col = FALSE,
  filter = FALSE, three_line = TRUE, grid_lines = FALSE,
  overwrite = FALSE, collect = FALSE, max_rows = 1048575L
)
}
\arguments{
\item{x}{A data.frame, tibble, duckplyr data frame, R Polars DataFrame/LazyFrame, or a non-empty named list mixing these objects. List names and order determine worksheets.}
\item{file}{Output .xlsx path in an existing directory.}
\item{sheet}{Sheet name for a single frame; ignored for lists.}
\item{font}{One font for all cells. Default Times New Roman; the Chinese name for SimSun is accepted. Fonts are not installed or embedded.}
\item{font_size}{Font size in points, from 1 to 409. Default 11.}
\item{align}{Body horizontal alignment: center, left, right, or justify.}
\item{header_align}{Header alignment, with the same choices. Default center.}
\item{valign}{Vertical alignment: center, top, or bottom.}
\item{wrap}{Enable text wrapping. Default TRUE; actual row autofit depends on the viewer.}
\item{widths}{\code{"auto"}, one numeric width, or one width per column. Numeric values must be from 1 to 250; a vector must match every sheet.}
\item{max_width}{Maximum automatic column width. Default 40. Completely ignored and not evaluated when widths is numeric.}
\item{freeze}{Freeze the first row. Default TRUE.}
\item{freeze_first_col}{Freeze the first column independently of freeze. Default FALSE.}
\item{filter}{Add a header filter. Default FALSE; omitted for header-only tables.}
\item{three_line}{Top and bottom rules with a thinner header-bottom rule. Default TRUE. Header-only tables have two rules.}
\item{grid_lines}{Show worksheet grid lines. Default FALSE.}
\item{overwrite}{Replace an existing whole workbook, first retaining a unique .bak copy. Default FALSE. This does not append sheets.}
\item{collect}{Allow duckplyr or Polars lazy query execution. Default FALSE. All duckplyr frames require TRUE even if cached.}
\item{max_rows}{Per-sheet data-row cap, an integer from 0 to 1048575. Default is Excel capacity minus header, not a safe memory budget. Lazy queries retrieve at most the cap plus one row; excess causes an error, never truncation.}
}
\value{The normalized output file path, invisibly.}
\description{A small wrapper around \pkg{openxlsx2} for consistent new-workbook exports.}
\details{
NA and NaN become value-less cells; literal NA strings are retained. Factors are
exported as labels. Ordinary numeric, logical, character, Date and POSIXct/POSIXlt
vectors are accepted. List/matrix columns, integer64 and other unsupported classes
are rejected; convert explicitly first. Inf and -Inf must be handled upstream.
Reserved openxlsx2 strings and XML-invalid text are rejected. Numeric integers
with more than 15 digits trigger a precision warning; use character IDs before
precision is lost. Ordinary formula-like strings remain text.

Custom row names are not exported. A warning asks you to move important IDs into
an explicit column; no column name is guessed. Caller data are not modified.

The writer temporarily isolates openxlsx2.numFmt, dateFormat, datetimeFormat,
string_nums and borderColor. Defaults are general numeric formatting,
yyyy-mm-dd dates, yyyy-mm-dd hh:mm:ss datetimes, text-preserving character columns
and black borders. Those options, and temporary automatic-width options, are
restored on exit including errors. Other settings such as compression and page
options are not reset. Session defaults for font, font_size and align may be
set with the corresponding evanxlsx options. Header alignment is independent.

Optional backends must be installed separately. Metadata and output conditions
are checked before query execution. Duckplyr prudence is not changed. Polars
collection uses the in-memory engine; the cap limits returned rows, not joins,
sorts, engine memory, total text size or time. Each worksheet is converted
separately, but this is not a streaming XLSX writer.

Polars temporal columns are selected by position, not by interpreting column
names. Int64/UInt64 columns are converted to exact strings before range checks;
columns containing values over 15 decimal digits stay text. Decimal remains
exact text. Datetime and Time remain text before R temporal conversion, with
Time retaining nine fractional digits. This does not imply native Excel
nanosecond storage or a full timezone-semantic round trip. Nested, binary and
Duration columns require explicit conversion. Already-lost precision is unrecoverable.

A complete workbook is built before attempting the final file copy. On a final
copy failure, restoring the original from its backup is attempted; a newly created
partial target is removed when possible. The complete new workbook and valid
backups are retained at paths reported by the error. Recovery itself may fail.
This is a single-writer best-effort policy, not a transaction, crash-safety or
concurrent-writer locking guarantee. Never write to one path concurrently.

The installed bilingual guide is available at
\code{system.file("guide", "usage.html", package = "evanxlsx")}.
}
\seealso{\code{\link[openxlsx2:wb_add_data]{openxlsx2::wb_add_data}}}
\examples{
x <- data.frame(id = c("001", "002"), value = c(1, NA_real_))
out <- tempfile(fileext = ".xlsx")
write_xlsx(list(var = x, id83 = x), out)
unlink(out)
}
