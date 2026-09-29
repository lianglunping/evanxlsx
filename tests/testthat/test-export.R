test_that("named data frames become sheets in the requested order", {
  x <- data.frame(id = c("001", "002"), value = c(2, NA_real_))
  path <- new_export(list(variant_info = x, id83 = x))
  doc <- xml_part(path, "xl/workbook.xml")
  expect_identical(xml2::xml_attr(xml2::xml_find_all(doc, ".//sheets/sheet"), "name"),
                   c("variant_info", "id83"))
  expect_equal(openxlsx2::read_xlsx(path, sheet = "id83")$value, c(2, NA_real_))
})

test_that("NA is a value-less cell, while literal NA text remains text", {
  d <- data.frame(text = c(NA, "NA", ""), number = c(NA, NaN, 3),
                  flag = c(NA, TRUE, FALSE), date = as.Date(c(NA, "2026-01-01", NA)))
  path <- new_export(d)
  ws <- xml_part(path, "xl/worksheets/sheet1.xml")
  for (address in c("A2", "B2", "B3", "C2", "D2", "D4")) {
    cell <- xml_cell(ws, address)
    expect_length(xml2::xml_find_all(cell, "v|is|f"), 0L, info = address)
  }
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "A3"), "is/t")), "NA")
  expect_length(xml2::xml_find_all(ws, ".//c[@t='e']"), 0L)
})

test_that("one font and size apply to header and body", {
  for (font in c("Times New Roman", "Arial", "SimSun")) {
    path <- new_export(font = font, font_size = 12)
    for (cell in c("A1", "A2", "B2", "B3")) {
      f <- cell_font(path, cell)
      expect_identical(attr_at(f, "name", "val"), font)
      expect_equal(as.numeric(attr_at(f, "sz", "val")), 12)
    }
    expect_length(xml2::xml_find_all(cell_font(path, "A1"), "b"), 1L)
    expect_length(xml2::xml_find_all(cell_font(path, "A2"), "b"), 0L)
  }
})

test_that("Chinese font alias maps to SimSun", {
  path <- new_export(font = "\u5b8b\u4f53")
  expect_identical(attr_at(cell_font(path, "A2"), "name", "val"), "SimSun")
})

test_that("four horizontal alignments and three vertical alignments are stored", {
  for (alignment in c("center", "left", "right", "justify")) {
    path <- new_export(align = alignment, header_align = "right")
    expect_identical(attr_at(cell_style(path, "A2"), "alignment", "horizontal"), alignment)
    expect_identical(attr_at(cell_style(path, "A1"), "alignment", "horizontal"), "right")
  }
  for (vertical in c("top", "center", "bottom")) {
    path <- new_export(valign = vertical)
    expect_identical(attr_at(cell_style(path, "A2"), "alignment", "vertical"), vertical)
  }
})

test_that("wrapping is explicitly switchable", {
  for (flag in c(TRUE, FALSE)) {
    path <- new_export(wrap = flag)
    value <- attr_at(cell_style(path, "A2"), "alignment", "wrapText")
    expect_true(value %in% if (flag) c("1", "true") else c("0", "false"))
  }
})

test_that("three-line style has exactly the intended horizontal rules", {
  path <- new_export(data.frame(a = 1:3, b = 4:6, c = 7:9))
  for (address in c("A1", "B1", "C1")) {
    b <- cell_border(path, address)
    expect_identical(attr_at(b, "top", "style"), "medium")
    expect_identical(attr_at(b, "bottom", "style"), "thin")
  }
  for (address in c("A4", "B4", "C4")) {
    expect_identical(attr_at(cell_border(path, address), "bottom", "style"), "medium")
  }
  for (address in c("A1", "B1", "C1", "A2", "B3", "C4")) {
    b <- cell_border(path, address)
    for (side in c("left", "right")) {
      expect_true(is.na(attr_at(b, side, "style")) || attr_at(b, side, "style") %in% c("", "none"))
    }
  }
  for (address in c("A2", "B3")) {
    b <- cell_border(path, address)
    for (side in c("top", "bottom")) {
      expect_true(is.na(attr_at(b, side, "style")) || attr_at(b, side, "style") %in% c("", "none"))
    }
  }
})

test_that("borders can be disabled", {
  path <- new_export(three_line = FALSE)
  for (address in c("A1", "A2", "B3")) {
    b <- cell_border(path, address)
    expect_length(xml2::xml_find_all(b, "*[@style and @style!='none']"), 0L)
  }
})

test_that("first row and optionally first column are frozen", {
  path <- new_export()
  doc <- xml_part(path, "xl/worksheets/sheet1.xml")
  expect_equal(as.numeric(attr_at(doc, ".//pane", "ySplit")), 1)
  path <- new_export(freeze_first_col = TRUE)
  doc <- xml_part(path, "xl/worksheets/sheet1.xml")
  expect_equal(as.numeric(attr_at(doc, ".//pane", "xSplit")), 1)
  expect_equal(as.numeric(attr_at(doc, ".//pane", "ySplit")), 1)
  path <- new_export(freeze = FALSE, freeze_first_col = FALSE)
  expect_length(xml2::xml_find_all(xml_part(path, "xl/worksheets/sheet1.xml"), ".//pane"), 0L)
})

test_that("column-only freezing works", {
  path <- new_export(freeze = FALSE, freeze_first_col = TRUE)
  doc <- xml_part(path, "xl/worksheets/sheet1.xml")
  expect_equal(as.numeric(attr_at(doc, ".//pane", "xSplit")), 1)
  y <- attr_at(doc, ".//pane", "ySplit")
  expect_true(is.na(y) || as.numeric(y) == 0)
})

test_that("filter and grid visibility are independently controlled", {
  path <- new_export(filter = TRUE, grid_lines = TRUE)
  doc <- xml_part(path, "xl/worksheets/sheet1.xml")
  expect_identical(attr_at(doc, ".//autoFilter", "ref"), "A1:B3")
  grid <- attr_at(doc, ".//sheetView", "showGridLines")
  expect_true(is.na(grid) || grid %in% c("1", "true"))
  path <- new_export()
  doc <- xml_part(path, "xl/worksheets/sheet1.xml")
  expect_length(xml2::xml_find_all(doc, ".//autoFilter"), 0L)
  expect_true(attr_at(doc, ".//sheetView", "showGridLines") %in% c("0", "false"))
})

test_that("automatic widths are bounded and caller options are restored", {
  old <- options(openxlsx2.minWidth = 5, openxlsx2.maxWidth = 80)
  on.exit(options(old), add = TRUE)
  path <- new_export(data.frame(text = strrep("x", 400)), max_width = 30)
  doc <- xml_part(path, "xl/worksheets/sheet1.xml")
  widths <- as.numeric(xml2::xml_attr(xml2::xml_find_all(doc, ".//cols/col"), "width"))
  expect_true(length(widths) > 0L)
  expect_true(all(widths <= 30.1))
  expect_identical(getOption("openxlsx2.minWidth"), 5)
  expect_identical(getOption("openxlsx2.maxWidth"), 80)
})

test_that("numeric column widths can be supplied", {
  path <- new_export(widths = c(12, 24))
  doc <- xml_part(path, "xl/worksheets/sheet1.xml")
  widths <- as.numeric(xml2::xml_attr(xml2::xml_find_all(doc, ".//cols/col"), "width"))
  expect_equal(widths, c(12, 24), tolerance = 0.1)
})

test_that("single-row and zero-row inputs are supported", {
  path <- new_export(data.frame(x = 1))
  expect_identical(attr_at(cell_border(path, "A1"), "bottom", "style"), "thin")
  expect_identical(attr_at(cell_border(path, "A2"), "bottom", "style"), "medium")
  path <- new_export(data.frame(x = numeric()), sheet = "empty", filter = TRUE)
  expect_identical(attr_at(cell_border(path, "A1"), "top", "style"), "medium")
  expect_identical(attr_at(cell_border(path, "A1"), "bottom", "style"), "medium")
  expect_length(xml2::xml_find_all(xml_part(path, "xl/worksheets/sheet1.xml"), ".//autoFilter"), 0L)
})

test_that("non-syntactic headers, factors, dates and Unicode are retained", {
  d <- data.frame("Gene ID" = factor(c("G_A", "G_B")),
                  description = c("\u793a\u4f8b\u6ce8\u91ca", "A&B < C"),
                  date = as.Date(c("2026-01-01", "2026-01-02")), check.names = FALSE)
  path <- new_export(d)
  ws <- xml_part(path, "xl/worksheets/sheet1.xml")
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "A1"), "is/t")), "Gene ID")
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "A2"), "is/t")), "G_A")
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "B2"), "is/t")), d$description[1])
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "B3"), "is/t")), "A&B < C")
  expect_length(xml2::xml_find_all(xml_cell(ws, "C2"), "v"), 1L)
  expect_gt(as.integer(xml2::xml_attr(cell_style(path, "C2"), "numFmtId")), 0L)
})

test_that("literal formula-like text and leading-zero IDs stay strings", {
  d <- data.frame(id = c("001", "123456789012345678", "1-2", "1E10"),
                  text = c("=1+1", "+SUM(A1)", "-1+2", "@SUM(A1)"))
  path <- new_export(d)
  ws <- xml_part(path, "xl/worksheets/sheet1.xml")
  expect_length(xml2::xml_find_all(ws, ".//f"), 0L)
  for (j in seq_len(nrow(d))) {
    expect_identical(attr_at(xml_cell(ws, paste0("A", j + 1)), ".", "t"), "inlineStr")
    expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, paste0("A", j + 1)), "is/t")), d$id[j])
  }
})

test_that("tibbles are accepted and caller input is not changed", {
  d <- tibble::tibble(id = c("001", "002"), value = c(NA_real_, NaN))
  before <- serialize(d, NULL)
  path <- new_export(d)
  expect_true(file.exists(path))
  expect_identical(serialize(d, NULL), before)
})

test_that("font preferences can be set once and overridden per call", {
  old <- options(evanxlsx.font = "Arial", evanxlsx.font_size = 13, evanxlsx.align = "left")
  on.exit(options(old), add = TRUE)
  path <- new_export()
  expect_identical(attr_at(cell_font(path, "A2"), "name", "val"), "Arial")
  expect_equal(as.numeric(attr_at(cell_font(path, "A2"), "sz", "val")), 13)
  expect_identical(attr_at(cell_style(path, "A2"), "alignment", "horizontal"), "left")
  path <- new_export(font = "Times New Roman", font_size = 11, align = "right")
  expect_identical(attr_at(cell_font(path, "A2"), "name", "val"), "Times New Roman")
})

test_that("existing files are unchanged by default and backed up on overwrite", {
  directory <- tempfile("evanxlsx-files-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  path <- file.path(directory, "result.xlsx")
  writeLines("original-content", path)
  before <- readBin(path, "raw", n = file.info(path)$size)
  expect_error(evanxlsx::write_xlsx(data.frame(a = 1), path), "already exists")
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
  expect_message(evanxlsx::write_xlsx(data.frame(a = 1), path, overwrite = TRUE), "backed up")
  backups <- list.files(directory, pattern = "\\.bak$", full.names = TRUE)
  expect_length(backups, 1L)
  expect_identical(readBin(backups, "raw", n = file.info(backups)$size), before)
  expect_gt(nrow(utils::unzip(path, list = TRUE)), 0L)
  expect_length(list.files(directory, pattern = "^\\.evanxlsx-", all.files = TRUE), 0L)
})

test_that("export returns a normalized path invisibly", {
  path <- tempfile(fileext = ".xlsx")
  result <- withVisible(evanxlsx::write_xlsx(data.frame(a = 1), path))
  expect_false(result$visible)
  expect_identical(result$value, normalizePath(path, winslash = "/"))
})
