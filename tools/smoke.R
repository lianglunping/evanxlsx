#!/usr/bin/env Rscript
# Fresh-process test of an installed package. Arguments: library output_dir [full].
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
lib <- normalizePath(args[1], winslash = "/", mustWork = TRUE)
.libPaths(c(lib, .libPaths()))
library(evanxlsx)
stopifnot(normalizePath(find.package("evanxlsx"), winslash = "/") == paste0(lib, "/evanxlsx"))
options(warn = 2)
out <- args[2]
if (dir.exists(out)) stop("Use a new output directory.")
dir.create(out, recursive = TRUE)
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
root <- dirname(dirname(normalizePath(script, winslash = "/")))
source(file.path(root, "tools", "fixtures.R"))
source(file.path(root, "tests", "testthat", "helper-xml.R"))
checks <- character()
check <- function(ok, label) {
  if (!isTRUE(ok)) stop("FAILED: ", label)
  checks <<- c(checks, label)
}
fixture <- make_fixture()
before <- serialize(fixture, NULL)
saveRDS(fixture, file.path(out, "synthetic_input.rds"), version = 2)
utils::write.csv(fixture$variant_info, file.path(out, "synthetic_variant_info.csv"),
                 row.names = FALSE, fileEncoding = "UTF-8", na = "<MISSING>")
file <- file.path(out, "demo.xlsx")
write_xlsx(fixture, file)
check(identical(serialize(fixture, NULL), before), "input_not_modified")
wb <- xml_part(file, "xl/workbook.xml")
check(identical(xml2::xml_attr(xml2::xml_find_all(wb, ".//sheets/sheet"), "name"),
                 names(fixture)), "sheet_names_and_order")
# Compare every cell, not merely file existence or a few selected values.
for (s in seq_along(fixture)) {
  d <- fixture[[s]]
  ws <- xml_part(file, sprintf("xl/worksheets/sheet%d.xml", s))
  check(length(xml2::xml_find_all(ws, ".//sheetData/row")) == nrow(d) + 1L,
        paste0("rows_sheet_", s))
  check(length(xml2::xml_find_all(ws, ".//c[@t='e']|.//f")) == 0L,
        paste0("no_error_cells_or_formulas_sheet_", s))
  for (j in seq_along(d)) {
    col <- openxlsx2::int2col(j)
    head <- xml_cell(ws, paste0(col, "1"))
    check(identical(xml2::xml_text(xml2::xml_find_first(head, "is/t")), names(d)[j]),
          paste0("header_", s, "_", j))
    v <- d[[j]]
    if (is.factor(v)) v <- as.character(v)
    for (i in seq_along(v)) {
      cell <- xml_cell(ws, paste0(col, i + 1L))
      if (is.na(v[i])) {
        stopifnot(length(xml2::xml_find_all(cell, "v|is|f")) == 0L)
      } else if (is.character(v)) {
        stopifnot(identical(xml2::xml_text(xml2::xml_find_first(cell, "is/t")), v[i]))
      } else {
        expected <- if (inherits(v, "Date")) as.numeric(v[i]) + 25569 else
          if (inherits(v, "POSIXct")) as.numeric(v[i]) / 86400 + 25569 else as.numeric(v[i])
        actual <- as.numeric(xml2::xml_text(xml2::xml_find_first(cell, "v")))
        stopifnot(length(actual) == 1L, is.finite(actual), abs(actual - expected) < 1e-8)
      }
    }
    check(TRUE, paste0("all_values_sheet_", s, "_column_", j))
  }
}
check(identical(attr_at(cell_font(file, "A2"), "name", "val"), "Times New Roman"),
      "default_font")
check(identical(attr_at(cell_style(file, "A2"), "alignment", "horizontal"), "center"),
      "default_alignment")
check(identical(attr_at(cell_border(file, "A1"), "top", "style"), "medium"), "top_rule")
check(identical(attr_at(cell_border(file, "A1"), "bottom", "style"), "thin"), "header_rule")
check(identical(attr_at(cell_border(file, "A241"), "bottom", "style"), "medium"), "bottom_rule")
# A path with spaces and Chinese characters, without changing user directories.
unicode_file <- file.path(out, "\u4e2d\u6587 output.xlsx")
write_xlsx(fixture$id83, unicode_file)
check(file.exists(unicode_file), "unicode_and_space_output_path")
if (length(args) >= 3L && args[3] == "full") {
  styles <- expand.grid(font = c("Times New Roman", "Arial", "SimSun"),
                         align = c("center", "left", "right", "justify"),
                         stringsAsFactors = FALSE)
  for (i in seq_len(nrow(styles))) {
    path <- file.path(out, sprintf("style_%02d.xlsx", i))
    size <- c(10, 12, 14)[match(styles$font[i], c("Times New Roman", "Arial", "SimSun"))]
    write_xlsx(fixture, path, font = styles$font[i], font_size = size,
                align = styles$align[i], widths = 24, filter = TRUE,
                freeze_first_col = TRUE)
    check(identical(attr_at(cell_font(path, "A2"), "name", "val"), styles$font[i]),
          paste0("font_case_", i))
    check(as.numeric(attr_at(cell_font(path, "A2"), "sz", "val")) == size,
          paste0("size_case_", i))
    check(identical(attr_at(cell_style(path, "A2"), "alignment", "horizontal"), styles$align[i]),
          paste0("alignment_case_", i))
    ws <- xml_part(path, "xl/worksheets/sheet1.xml")
    check(as.numeric(attr_at(ws, ".//pane", "xSplit")) == 1 &&
            as.numeric(attr_at(ws, ".//pane", "ySplit")) == 1, paste0("freeze_case_", i))
  }
  utils::write.csv(styles, file.path(out, "style_cases.csv"), row.names = FALSE)
  big <- make_fixture(10000L)$variant_info[, c("Sample_ID", "Long_ID", "Gene_ID", "Value", "Count", "Flag")]
  path <- file.path(out, "medium_10000.xlsx")
  elapsed <- system.time(write_xlsx(big, path, widths = 20))[["elapsed"]]
  back <- openxlsx2::read_xlsx(path)
  check(nrow(back) == nrow(big) && identical(back$Sample_ID, big$Sample_ID) &&
          identical(back$Long_ID, big$Long_ID), "10000_row_ID_roundtrip")
  value <- big$Value; value[is.nan(value)] <- NA
  check(isTRUE(all.equal(back$Value, value, check.attributes = FALSE)), "10000_row_numeric_roundtrip")
  utils::write.csv(data.frame(rows = nrow(big), columns = ncol(big), elapsed_seconds = elapsed,
                              output_bytes = file.info(path)$size),
                   file.path(out, "medium_observation.csv"), row.names = FALSE)
}
utils::write.csv(data.frame(check = checks, status = "PASS"),
                 file.path(out, "assertions.csv"), row.names = FALSE)
writeLines(c(paste("Package:", packageVersion("evanxlsx")),
             paste("Library:", find.package("evanxlsx")), capture.output(sessionInfo())),
           file.path(out, "sessionInfo.txt"))
writeLines("PASS", file.path(out, "STATUS.txt"))
cat("PASS: installed package smoke test; assertions =", length(checks), "\n")
