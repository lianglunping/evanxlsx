# Regression tests: synthetic values only; no default-conversion oracle for expected output.
# Preserve all older integration tests, including the previously failing Time case.
.timefix_ns <- c("0", "1", "999", "1000", "1000000", "123456789",
                 "3723123456789", "86399999999999", NA_character_)
.timefix_expected <- c("00:00:00.000000000", "00:00:00.000000001", "00:00:00.000000999",
                       "00:00:00.000001000", "00:00:00.001000000", "00:00:00.123456789",
                       "01:02:03.123456789", "23:59:59.999999999", NA_character_)
.timefix_make <- function() {
  polars::pl$DataFrame(clock = .timefix_ns)$select(
    polars::pl$col("clock")$cast(polars::pl$Int64)$cast(polars::pl$Time))
}
.timefix_raw <- function(x) {
  as.data.frame(x$select(polars::pl$col("clock")$cast(polars::pl$Int64)),
                int64 = "character")$clock
}
.timefix_xml_text <- function(file, address, sheet = 1L) {
  ws <- xml_part(file, sprintf("xl/worksheets/sheet%d.xml", sheet))
  xml2::xml_text(xml2::xml_find_first(xml_cell(ws, address), "is/t"))
}

test_that("Time inputs retain their exact physical nanoseconds before conversion", {
  x <- .timefix_make()
  expect_identical(.timefix_raw(x), .timefix_ns)
  expect_identical(format(x$schema$clock, abbreviated = FALSE), "Time")
  default_text <- as.data.frame(x$select(polars::pl$col("clock")$cast(polars::pl$String)))$clock
  explicit_text <- as.data.frame(x$select(
    polars::pl$col("clock")$dt$to_string("%H:%M:%S%.9f")))$clock
  utils::write.csv(data.frame(input_ns = .timefix_ns, expected_text = .timefix_expected,
    actual_ns = .timefix_raw(x), default_cast = default_text, explicit_format = explicit_text),
    file.path(Sys.getenv("EVANXLSX_INTEGRATION_OUT"), "time_construction_diagnostics.csv"),
    row.names = FALSE, na = "")
  expect_identical(explicit_text, .timefix_expected)
  expect_identical(.timefix_raw(x), .timefix_ns)
})

test_that("Time boundary values survive eager and lazy Excel export as exact text", {
  x <- .timefix_make()
  before <- .timefix_raw(x)
  f <- file.path(Sys.getenv("EVANXLSX_INTEGRATION_OUT"), "time_precision_boundaries.xlsx")
  write_xlsx(list(eager = x, lazy = x$lazy()), f, collect = TRUE,
              max_rows = length(.timefix_ns), widths = 28)
  for (s in 1:2) {
    values <- vapply(2:10, function(i) .timefix_xml_text(f, paste0("A", i), s), character(1))
    expect_identical(values, .timefix_expected)
    ws <- xml_part(f, sprintf("xl/worksheets/sheet%d.xml", s))
    for (i in 2:9) {
      cell <- xml_cell(ws, paste0("A", i))
      expect_identical(xml2::xml_attr(cell, "t"), "inlineStr")
      expect_length(xml2::xml_find_all(cell, "v|f"), 0L)
    }
    expect_length(xml2::xml_find_all(xml_cell(ws, "A10"), "v|is|f"), 0L)
    expect_identical(attr_at(cell_border(f, "A10", s), "bottom", "style"), "medium")
  }
  expect_identical(.timefix_raw(x), before)
})

test_that("original UTC Datetime to Time fixture is checked before export", {
  p <- polars::pl
  dt <- p$DataFrame(value = c("2026-09-29 01:02:03.123456789", NA_character_))$with_columns(
    p$col("value")$str$to_datetime(time_unit = "ns", time_zone = "UTC"))
  clock <- dt$select(p$col("value")$cast(p$Time)$alias("clock"))
  expect_identical(.timefix_raw(clock), c("3723123456789", NA_character_))
  before <- .timefix_raw(clock)
  f <- file.path(Sys.getenv("EVANXLSX_INTEGRATION_OUT"), "time_from_datetime.xlsx")
  write_xlsx(clock, f, widths = 28)
  expect_identical(.timefix_xml_text(f, "A2"), "01:02:03.123456789")
  expect_true(is.na(.timefix_xml_text(f, "A3")))
  expect_identical(.timefix_raw(clock), before)
})

test_that("multiple Time columns, all-null Time and zero rows retain their schemas", {
  p <- polars::pl
  x <- .timefix_make()
  both <- x$select(p$col("clock"), p$col("clock")$alias("clock_copy"))
  f <- new_export(both$lazy(), collect = TRUE)
  expect_identical(.timefix_xml_text(f, "A8"), "01:02:03.123456789")
  expect_identical(.timefix_xml_text(f, "B8"), "01:02:03.123456789")
  null_time <- p$DataFrame(clock = c(NA_character_, NA_character_))$select(
    p$col("clock")$cast(p$Int64)$cast(p$Time))
  g <- new_export(null_time)
  ws <- xml_part(g, "xl/worksheets/sheet1.xml")
  for (a in c("A2", "A3")) expect_length(xml2::xml_find_all(xml_cell(ws, a), "v|is|f"), 0L)
  h <- new_export(x$head(0L)$lazy(), collect = TRUE, max_rows = 0L)
  ws <- xml_part(h, "xl/worksheets/sheet1.xml")
  expect_length(xml2::xml_find_all(ws, ".//sheetData/row"), 1L)
  expect_identical(.timefix_xml_text(h, "A1"), "clock")
})
