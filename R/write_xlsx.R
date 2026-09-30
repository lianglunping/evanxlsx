#' Export data frames with consistent Excel formatting
#'
#' @param x A data.frame, duckplyr data frame, R Polars DataFrame/LazyFrame,
#'   or a non-empty named list mixing these objects. List names are sheet names.
#' @param file Output .xlsx path. The parent directory must already exist.
#' @param sheet Worksheet name for a single data.frame; ignored for a list.
#' @param font One font name for all cells. Chinese name "SimSun" may also be
#'   supplied as its Chinese alias. Font files are not embedded or installed.
#' @param font_size Font size in points, between 1 and 409.
#' @param align Body alignment: "center", "left", "right", or "justify".
#' @param header_align Header alignment, with the same choices as align.
#' @param valign Vertical alignment: "center", "top", or "bottom".
#' @param wrap Whether to enable text wrapping. Row autofit depends on Excel.
#' @param widths "auto", one numeric width, or one width per column. A numeric
#'   vector must match the number of columns in every worksheet.
#' @param max_width Upper bound for automatic widths; ignored for numeric widths.
#' @param freeze Whether to freeze the first row.
#' @param freeze_first_col Whether to also freeze the first column.
#' @param filter Whether to add a header filter. Default FALSE.
#' @param three_line Whether to add top, header-bottom and table-bottom rules.
#' @param grid_lines Whether to show Excel's on-screen grid lines.
#' @param overwrite Whether to replace an existing file. Default FALSE.
#'   When TRUE, an existing file is first copied to a unique .bak file.
#' @param collect Allow execution of duckplyr or Polars lazy queries. Default
#'   FALSE. All duckplyr objects require TRUE, even if already materialized.
#' @param max_rows Maximum data rows per sheet, from 0 to 1048575. Lazy queries
#'   retrieve at most max_rows + 1 rows and fail if the limit is exceeded.
#'   This is a result-size limit, not an engine memory or execution-time limit.
#' @return The normalized output path, invisibly.
#' @export
write_xlsx <- function(
    x, file, sheet = "Sheet1",
    font = getOption("evanxlsx.font", "Times New Roman"),
    font_size = getOption("evanxlsx.font_size", 11),
    align = getOption("evanxlsx.align", "center"),
    header_align = "center", valign = "center", wrap = TRUE,
    widths = "auto", max_width = 40,
    freeze = TRUE, freeze_first_col = FALSE,
    filter = FALSE, three_line = TRUE, grid_lines = FALSE,
    overwrite = FALSE, collect = FALSE, max_rows = 1048575L) {
  # Validate output and scalar options before forcing or inspecting x.
  .check_string(file, "file")
  .check_string(font, "font")
  .check_number(font_size, "font_size", 1, 409)
  align <- .check_choice(align, c("center", "left", "right", "justify"), "align")
  header_align <- .check_choice(
    header_align, c("center", "left", "right", "justify"), "header_align"
  )
  valign <- .check_choice(valign, c("center", "top", "bottom"), "valign")
  flags <- list(wrap = wrap, freeze = freeze, freeze_first_col = freeze_first_col,
                filter = filter, three_line = three_line,
                grid_lines = grid_lines, overwrite = overwrite, collect = collect)
  for (nm in names(flags)) .check_flag(flags[[nm]], nm)
  .check_number(max_rows, "max_rows", 0, 1048575L)
  if (max_rows != trunc(max_rows)) stop("`max_rows` must be a whole number.", call. = FALSE)
  max_rows <- as.integer(max_rows)
  auto_width <- identical(widths, "auto")
  if (auto_width) .check_number(max_width, "max_width", 1, 250)
  if (!auto_width) {
    if (!is.numeric(widths) || !length(widths) || any(!is.finite(widths)) ||
        any(widths < 1 | widths > 250)) {
      stop("`widths` must be 'auto' or numeric widths between 1 and 250.", call. = FALSE)
    }

  }
  file <- path.expand(file)
  if (!grepl("\\.xlsx$", file, ignore.case = TRUE)) {
    stop("`file` must end in .xlsx.", call. = FALSE)
  }
  if (!dir.exists(dirname(file)) || dir.exists(file)) {
    stop("Use a file path in an existing directory.", call. = FALSE)
  }
  if (file.exists(file) && !overwrite) {
    stop("File already exists; choose a new name or set `overwrite = TRUE`.", call. = FALSE)
  }
  if (file.access(dirname(file), 2L) != 0L ||
      (file.exists(file) && file.access(file, 2L) != 0L)) {
    stop("Output location is not writable.", call. = FALSE)
  }
  if (identical(font, "\u5b8b\u4f53")) font <- "SimSun"
  sheets <- .normalise_sheets(x, sheet)
  kinds <- vapply(sheets, .input_kind, character(1))
  needs_collect <- kinds %in% c("duckplyr", "polars_lazy")
  if (!collect && any(needs_collect)) {
    stop(paste0("Sheets requiring query execution: ",
                paste(names(sheets)[needs_collect], collapse = ", "),
                ". Set `collect = TRUE` or collect explicitly first."), call. = FALSE)
  }
  # Inspect all schemas before executing any query. Never ask duckplyr for nrow().
  meta <- lapply(seq_along(sheets), function(i) {
    .inspect_sheet(sheets[[i]], kinds[i], names(sheets)[i], max_rows)
  })
  if (!auto_width && length(widths) != 1L &&
      any(vapply(meta, function(m) length(m$names), integer(1)) != length(widths))) {
    stop("`widths` must have length 1 or match every sheet's column count.", call. = FALSE)
  }

  # Restore the caller's settings even when workbook creation fails.
  old <- options(openxlsx2.numFmt = NULL,
                 openxlsx2.dateFormat = "yyyy-mm-dd",
                 openxlsx2.datetimeFormat = "yyyy-mm-dd hh:mm:ss",
                 openxlsx2.string_nums = FALSE,
                 openxlsx2.borderColor = "black")
  if (auto_width) {
    old <- c(old, options(openxlsx2.minWidth = min(10, max_width),
                          openxlsx2.maxWidth = max_width))
  }
  on.exit(options(old), add = TRUE)
  wb <- openxlsx2::wb_workbook(creator = "evanxlsx")
  wb$set_base_font(font_name = font, font_size = font_size,
                   font_color = openxlsx2::wb_color(hex = "FF000000"))

  for (i in seq_along(sheets)) {
    d <- .materialize_sheet(sheets[[i]], meta[[i]], names(sheets)[i], max_rows)
    last_col <- openxlsx2::int2col(ncol(d))
    last_row <- nrow(d) + 1L
    all_dims <- paste0("A1:", last_col, last_row)
    header_dims <- paste0("A1:", last_col, "1")
    wb$add_worksheet(names(sheets)[i], grid_lines = grid_lines)
    # NA is a value-less cell, not an error and not an empty string.
    wb$add_data(i, x = d, na = NULL, row_names = FALSE,
                col_names = TRUE, with_filter = filter && nrow(d) > 0L)
    wb$add_cell_style(i, dims = all_dims, horizontal = align,
                      vertical = valign, wrap_text = wrap)
    wb$add_font(i, dims = header_dims, name = font, size = font_size,
                bold = TRUE, color = openxlsx2::wb_color(hex = "FF000000"))
    wb$add_cell_style(i, dims = header_dims, horizontal = header_align,
                      vertical = valign, wrap_text = wrap)
    if (three_line) {
      # A zero-row table has only a header; its two outer rules are retained.
      wb$add_border(i, dims = header_dims, top_border = "medium",
                    bottom_border = if (nrow(d)) "thin" else "medium",
                    left_border = NULL, right_border = NULL,
                    inner_hgrid = NULL, inner_vgrid = NULL)
      if (nrow(d) > 0L) {
        wb$add_border(i, dims = paste0("A", last_row, ":", last_col, last_row),
                      top_border = NULL, bottom_border = "medium",
                      left_border = NULL, right_border = NULL,
                      inner_hgrid = NULL, inner_vgrid = NULL)
      }
    }
    if (freeze || freeze_first_col) {
      wb$freeze_pane(i, first_row = freeze, first_col = freeze_first_col)
    }
    wb$set_col_widths(i, cols = seq_len(ncol(d)), widths = widths)
    rm(d)  # Do not retain every converted data frame alongside the workbook.
  }

  # Finish the new workbook before touching an existing output file.
  tmp <- tempfile(pattern = ".evanxlsx-", tmpdir = dirname(file), fileext = ".xlsx")
  remove_tmp <- TRUE
  on.exit(if (remove_tmp) unlink(tmp), add = TRUE)
  wb$save(tmp, overwrite = FALSE)
  if (!file.exists(tmp) || is.na(file.info(tmp)$size) || file.info(tmp)$size == 0) {
    stop("Workbook creation did not produce a non-empty file.", call. = FALSE)
  }
  # Once complete, retain the new workbook when publication fails.
  remove_tmp <- FALSE
  .commit_file(tmp, file, overwrite)
  remove_tmp <- TRUE
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}
