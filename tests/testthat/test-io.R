io_fixture <- function() data.frame(
  Sample_ID = c("0001", "123456789012345678", "0003", "0004"),
  value = c(1.25, NA_real_, 0, -2),
  note = c("\u6c34\u7a3b Rice", NA, "NA", "quote\" comma, tab\t line\nend"),
  stringsAsFactors = FALSE
)

test_that("one reader and writer handle all four extensions", {
  x <- io_fixture()
  before <- serialize(x, NULL)
  for (ext in c("xlsx", "txt", "tsv", "csv", "CSV")) {
    f <- tempfile(fileext = paste0(".", ext))
    expect_no_warning(export(x, f))
    got <- import(f, text_cols = "Sample_ID")
    expect_s3_class(got, "tbl_df")
    expect_identical(names(got), names(x))
    expect_identical(got$Sample_ID, x$Sample_ID)
    expect_equal(got$value, x$value)
    expect_identical(got$note, x$note)
    expect_identical(serialize(x, NULL), before)
  }
})

test_that("named sheets and formatting use the existing writer", {
  x <- io_fixture()
  y <- data.frame(category = c("DEL", "INS"), count = c(3, 2))
  f <- tempfile(fileext = ".xlsx")
  export(list(var = x, id83 = y), f, font = "Arial", font_size = 12, align = "left")
  expect_identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(f))), c("var", "id83"))
  expect_equal(as.data.frame(import(f, sheet = 2)), y)
  expect_equal(as.data.frame(import(f, sheet = "id83")), y)
  expect_identical(attr_at(cell_font(f, "A2"), "name", "val"), "Arial")
  expect_identical(attr_at(cell_font(f, "A2"), "sz", "val"), "12")
  expect_identical(attr_at(cell_style(f, "A2"), "alignment", "horizontal"), "left")
  g <- tempfile(fileext = ".xlsx")
  export(x, g, sheet = "var")
  expect_identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(g))), "var")
  expect_error(import(f, sheet = "missing"))
  expect_equal(nrow(import(f, sheet = "var", dims = "A1:B3")), 2L)
})

test_that("delimiters, missing tokens and non-destructive defaults are explicit", {
  x <- io_fixture()
  for (sep in c(";", "|", " ")) {
    f <- tempfile(fileext = ".txt")
    export(x, f, sep = sep, na = "__MISSING__")
    y <- import(f, sep = sep, na = "__MISSING__", text_cols = "Sample_ID")
    expect_identical(y$note, x$note)
    expect_equal(y$value, x$value)
  }
  f <- tempfile(fileext = ".csv")
  export(data.frame(note = c("", NA_character_, "NA"), v = c(1, 2, 3)), f)
  expect_identical(import(f)$note, c(NA_character_, NA_character_, "NA"))
  expect_identical(import(f, na = c("", "NA"))$note, rep(NA_character_, 3))
  for (ext in c("txt", "csv", "xlsx")) {
    g <- tempfile(fileext = paste0(".", ext))
    export(x, g)
    hash <- tools::md5sum(g)
    expect_error(export(stop("INPUT_FORCED"), g), "already exists")
    expect_identical(tools::md5sum(g), hash)
    suppressMessages(export(tibble::as_tibble(x[1:2, ]), g, overwrite = TRUE))
    backups <- Sys.glob(paste0(g, ".*.bak"))
    expect_length(backups, 1L)
    expect_identical(unname(tools::md5sum(backups)), unname(hash))
    expect_equal(nrow(import(g)), 2L)
  }
})

test_that("bad formats, bad arguments and invalid input are rejected", {
  x <- io_fixture()
  expect_error(export(x, tempfile(fileext = ".pdf")), "xlsx.*txt.*tsv.*csv")
  expect_error(import(tempfile(fileext = ".csv")), "does not exist")
  f <- tempfile(fileext = ".csv"); export(x, f)
  expect_error(import(f, sheet = "var"), "only for XLSX")
  expect_error(import(f, text_cols = "not_found"))
  expect_error(import(f, text_cols = NA), "text_cols")
  expect_error(import(f, sep = "::"), "delimiter")
  expect_error(export(x, tempfile(fileext = ".csv"), sheet = "var"), "only for XLSX")
  expect_error(export(x, tempfile(fileext = ".csv"), font = "Arial"), "Unsupported text")
  expect_error(export(x, tempfile(fileext = ".csv"), append = TRUE), "Unsupported text")
  expect_error(export(list(var = x), tempfile(fileext = ".csv")), "one table")
  expect_error(export(x, tempfile(fileext = ".xlsx"), sep = ";"), "only for text")
  expect_error(export(x, tempfile(fileext = ".csv"), collect = NA), "collect")
  bad <- data.frame(v = I(list(1:2)))
  expect_error(export(bad, tempfile(fileext = ".tsv")), "ordinary vectors")
  invalid <- tempfile(fileext = ".csv"); writeLines(c("v", "not_numeric"), invalid)
  expect_error(suppressWarnings(import(invalid, col_types = "d")))
})

test_that("text handles long fields without Excel limits and retains input", {
  x <- data.frame(text = strrep("a", 40000), stringsAsFactors = FALSE)
  f <- tempfile(fileext = ".tsv")
  export(x, f)
  expect_identical(import(f)$text, x$text)
  empty <- data.frame(id = character(), v = numeric())
  g <- tempfile(fileext = ".txt"); export(empty, g)
  expect_identical(names(import(g)), c("id", "v"))
  expect_equal(nrow(import(g)), 0L)
})
