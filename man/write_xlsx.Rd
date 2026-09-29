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
  overwrite = FALSE
)
}
\arguments{
\item{x}{A data.frame, including a tibble or data.table, or a non-empty named list of data.frames. List order is sheet order.}
\item{file}{Output .xlsx path. Its parent directory must already exist.}
\item{sheet}{Sheet name for a single data.frame; ignored for lists. Default \code{"Sheet1"}.}
\item{font}{One font for all cells. Default \code{"Times New Roman"}. The Chinese name for SimSun is accepted as an alias. No fonts are installed or embedded.}
\item{font_size}{Font size in points, between 1 and 409. Default 11.}
\item{align}{Body horizontal alignment: \code{"center"}, \code{"left"}, \code{"right"}, or \code{"justify"}.}
\item{header_align}{Header horizontal alignment; same choices as \code{align}. Default \code{"center"}.}
\item{valign}{Vertical alignment: \code{"center"}, \code{"top"}, or \code{"bottom"}.}
\item{wrap}{Enable text wrapping. Default TRUE. No explicit row heights are imposed.}
\item{widths}{\code{"auto"}, a single numeric width, or one numeric width per column. A vector must match every sheet's number of columns. Numeric values must be between 1 and 250.}
\item{max_width}{Upper bound for automatic widths. Default 40. Ignored when \code{widths} is numeric.}
\item{freeze}{Freeze the first row. Default TRUE.}
\item{freeze_first_col}{Also freeze the first column. Default FALSE. Works independently of \code{freeze}.}
\item{filter}{Add column filters. Default FALSE. No filter is added to a header-only sheet.}
\item{three_line}{Draw top and bottom rules and a thin rule below the header. Default TRUE. Header-only tables have two outer rules.}
\item{grid_lines}{Show on-screen worksheet grid lines. Default FALSE.}
\item{overwrite}{Default FALSE. When TRUE and the destination exists, keep a unique .bak copy before replacement.}
}
\value{The normalized output file path, invisibly.}
\description{A small wrapper around \pkg{openxlsx2} for consistent exports. It writes a new workbook, rather than appending to or editing an existing workbook.}
\details{
A single selected font and size are applied throughout; headers are bold.
Actual glyph rendering depends on installed fonts and the spreadsheet application.
\code{NA} and numeric \code{NaN} are exported as cells without values, not as
\code{#N/A} errors or empty strings. Literal strings such as \code{"NA"}
are retained. The original R objects are not modified.

Ordinary character, numeric, integer and logical columns, factors, Date and
POSIXct/POSIXlt columns are supported. Factors are exported as labels, and
POSIXlt is converted to POSIXct. List columns, matrix columns, integer64,
complex vectors, formula classes and other unsupported classes are rejected.
Infinite values must be handled explicitly. Character values reserved by
openxlsx2 are rejected rather than silently altered. Dates use openxlsx2's
normal date formatting. Excel date-time cells do not store a timezone;
use an explicit character representation to preserve timezone information.

Ordinary formula-like strings are written as text, not formulas. Large numeric
integers may lose precision in Excel; a warning is issued. Store identifiers as
character before any precision has been lost. The function does not round the
input numeric data.

Automatic widths are openxlsx2 heuristics, not pixel-exact font measurements.
Temporary width options are restored on exit, including on errors. Justification
is most apparent in wrapped, multi-line text. Row-height autofitting depends on
the spreadsheet application; adjust row heights in Excel when needed.

The new workbook is fully generated in a temporary file first. Explicit
replacement preserves the previous destination in a unique .bak file. This is
not a cross-platform transactional or concurrent-writer locking mechanism.
Do not write to the same output path from multiple processes at once.

Session defaults can be set using \code{options(evanxlsx.font = "Arial",
evanxlsx.font_size = 12, evanxlsx.align = "left")}. Explicit function arguments
take precedence. These options do not change the header alignment default.
}
\seealso{\code{\link[openxlsx2:wb_add_data]{openxlsx2::wb_add_data}},
\code{\link[openxlsx2:wb_add_cell_style]{openxlsx2::wb_add_cell_style}}}
\examples{
x <- data.frame(id = c("001", "002"), value = c(1, NA_real_))
out <- tempfile(fileext = ".xlsx")
write_xlsx(list(var = x, id83 = x), out)
unlink(out)

out <- tempfile(fileext = ".xlsx")
write_xlsx(x, out, font = "Arial", font_size = 12, align = "left")
unlink(out)
}
