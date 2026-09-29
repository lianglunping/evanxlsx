test_that("invalid worksheet names fail without creating an output", {
  invalid <- c("", "   ", "a/b", "a\\b", "a:b", "a?b", "a*b", "[a]",
               "'start", "end'", "History", strrep("a", 32), strrep("\U0001f33e", 16))
  for (name in invalid) {
    path <- tempfile(fileext = ".xlsx")
    x <- list(data.frame(a = 1)); names(x) <- name
    expect_error(evanxlsx::write_xlsx(x, path))
    expect_false(file.exists(path))
  }
})

test_that("duplicate sheet names are rejected ignoring case", {
  d <- data.frame(a = 1)
  expect_error(new_export(list(var = d, VAR = d)), "unique")
})

test_that("empty lists, unnamed lists and non-tabular objects are rejected", {
  expect_error(new_export(list()), "named list")
  expect_error(new_export(list(data.frame(a = 1))), "named list")
  expect_error(new_export(1:4), "data.frame")
  expect_error(new_export(list(a = 1)), "data.frame")
  expect_error(new_export(data.frame()), "at least one column")
})

test_that("invalid or duplicate column names are rejected", {
  d <- data.frame(a = 1, b = 2)
  names(d) <- c("x", "x")
  expect_error(new_export(d), "column names")
  names(d) <- c("x", "")
  expect_error(new_export(d), "column names")
})

test_that("nested and special column classes cannot silently change meaning", {
  d <- data.frame(id = 1:2)
  d$nested <- list(1:2, 3:4)
  expect_error(new_export(d), "unsupported column type")
  d <- data.frame(id = 1:2)
  d$z <- c(1 + 1i, 2 + 2i)
  expect_error(new_export(d), "unsupported column type")
  d <- data.frame(id = 1:2)
  d$id <- structure(c(1, 2), class = "integer64")
  expect_error(new_export(d), "integer64")
  d <- data.frame(id = 1:2)
  d$id <- structure(c("=1+1", "=2+2"), class = "formula")
  expect_error(new_export(d), "unsupported column type")
})

test_that("infinity must be handled explicitly", {
  expect_error(new_export(data.frame(x = Inf)), "Inf/-Inf")
  expect_error(new_export(data.frame(x = -Inf)), "Inf/-Inf")
})

test_that("large numeric IDs warn but character IDs do not", {
  expect_warning(new_export(data.frame(id = 1e16)), "precision")
  expect_no_warning(new_export(data.frame(id = "10000000000000000")))
})

test_that("reserved text and invalid control characters are rejected", {
  for (value in c("_openxlsx_NA", "_openxlsx_NULL", "_openxlsx_NaN",
                  "_openxlsx_Inf", "_openxlsx_nInf", "<r>abc", "<r/>abc", "a\001b")) {
    expect_error(new_export(data.frame(text = value)))
  }
  expect_no_error(new_export(data.frame(text = "ordinary\nline\twith tab")))
})

test_that("text length is checked in UTF-16 units", {
  expect_error(new_export(data.frame(text = strrep("x", 32768))), "32767")
  expect_error(new_export(data.frame(text = strrep("\U0001f33e", 16384))), "32767")
  expect_no_error(new_export(data.frame(text = strrep("x", 32767)), widths = 20))
})

test_that("font size and alignment values are validated", {
  for (size in list(0, 410, NA, Inf, numeric(), c(10, 12), "12")) {
    expect_error(new_export(font_size = size), "font_size")
  }
  expect_error(new_export(font = ""), "font")
  expect_error(new_export(align = "middle"), "align")
  expect_error(new_export(header_align = "centre"), "header_align")
  expect_error(new_export(valign = "left"), "valign")
  expect_error(new_export(max_width = 251), "max_width")
  expect_error(new_export(max_width = 0), "max_width")
})

test_that("logical parameters do not accept NA or accidental numeric values", {
  for (name in c("wrap", "freeze", "freeze_first_col", "filter", "three_line",
                  "grid_lines", "overwrite")) {
    args <- list(x = data.frame(a = 1), file = tempfile(fileext = ".xlsx"))
    args[[name]] <- NA
    expect_error(do.call(evanxlsx::write_xlsx, args), name)
    args[[name]] <- 1
    expect_error(do.call(evanxlsx::write_xlsx, args), name)
  }
})

test_that("column widths must match data and remain in bounds", {
  expect_error(new_export(widths = c(10, 12, 15)), "column count")
  expect_error(new_export(widths = "automatic"), "widths")
  expect_error(new_export(widths = NA_real_), "widths")
  expect_error(new_export(widths = 0), "widths")
  expect_error(new_export(widths = 251), "widths")
})

test_that("wrong extension and missing directories are rejected", {
  expect_error(evanxlsx::write_xlsx(data.frame(a = 1), tempfile(fileext = ".csv")), ".xlsx")
  absent <- file.path(tempfile(), "output.xlsx")
  expect_error(evanxlsx::write_xlsx(data.frame(a = 1), absent), "existing directory")
  expect_false(dir.exists(dirname(absent)))
})

test_that("row and column limits account for the header", {
  # Only metadata is enlarged; no million-row data matrix is allocated.
  d <- structure(list(a = numeric()), class = "data.frame", row.names = c(NA_integer_, -1048576L))
  expect_error(new_export(d), "limits")
  d <- as.data.frame(rep(list(integer()), 16385L))
  expect_error(new_export(d), "limits")
})


test_that("XML checks accept ASCII and reject Unicode noncharacters", {
  for (value in c("plain ASCII", "001", "caf\u00e9", "\u6ce8\u91ca")) {
    expect_no_error(new_export(data.frame(text = value)))
  }
  for (code in c(0xFFFE, 0xFFFF)) {
    expect_error(new_export(data.frame(text = intToUtf8(code))), "XML-invalid")
  }
})

test_that("wide tables and Unicode sheet/header names work", {
  d <- as.data.frame(setNames(rep(list(1:2), 100), paste0("col_", 1:100)))
  path <- new_export(d)
  expect_identical(attr_at(cell_border(path, "CV3"), "bottom", "style"), "medium")
  d <- data.frame(value = c("\u4e2d\u6587 English", NA))
  names(d) <- "\u6ce8\u91ca_Annotation"
  path <- new_export(d, sheet = "\u793a\u4f8b_Demo")
  expect_identical(attr_at(xml_part(path, "xl/workbook.xml"), ".//sheet", "name"),
                   "\u793a\u4f8b_Demo")
})
