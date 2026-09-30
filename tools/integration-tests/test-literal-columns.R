test_that("literal temporal names preserve unrelated types across eager and lazy exports", {
  pl <- polars::pl
  for (nm in c("*", "^value$", "^no_match$", "a b", "[clock]", "\u65f6\u95f4")) {
    for (kind in c("Datetime", "Time")) for (lazy in c(FALSE, TRUE)) {
      x <- pl$DataFrame(ts = c("2026-09-30 01:02:03.123456789", NA_character_), value = 1:2,
                        id = c("0001", "0002"))$with_columns(pl$col("ts")$str$to_datetime(time_unit = "ns"))
      if (kind == "Time") x <- x$with_columns(pl$col("ts")$cast(pl$Time))
      x <- x$select(pl$col("id"), pl$col("ts")$alias(nm), pl$col("value"))
      f <- new_export(if (lazy) x$lazy() else x, collect = TRUE)
      ws <- xml_part(f, "xl/worksheets/sheet1.xml")
      expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "B1"), "is/t")), nm)
      expected <- if (kind == "Time") "01:02:03.123456789" else "2026-09-30 01:02:03.123456789"
      expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "B2"), "is/t")), expected)
      expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "A2"), "is/t")), "0001")
      expect_length(xml2::xml_find_all(xml_cell(ws, "B3"), "v|is|f"), 0L)
      expect_length(xml2::xml_find_all(xml_cell(ws, "C2"), "is|f"), 0L)
      expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "C2"), "v")), "1")
    }
  }
})

test_that("mixed multiple temporal columns survive reordering and actual Parquet scanning", {
  pl <- polars::pl
  x <- pl$DataFrame(ts = c("2026-09-30 01:02:03.123456789", NA_character_), value = c(2.5, NA_real_))$
    with_columns(pl$col("ts")$str$to_datetime(time_unit = "ns"))$
    select(pl$col("ts")$cast(pl$Time)$alias("*"), pl$col("value"), pl$col("ts")$alias("^value$"))
  parquet <- tempfile(fileext = ".parquet")
  x$write_parquet(parquet)
  before <- tools::md5sum(parquet)
  f <- new_export(pl$scan_parquet(parquet), collect = TRUE, max_rows = 2L)
  ws <- xml_part(f, "xl/worksheets/sheet1.xml")
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "A2"), "is/t")), "01:02:03.123456789")
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "C2"), "is/t")), "2026-09-30 01:02:03.123456789")
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "B2"), "v")), "2.5")
  expect_error(new_export(pl$scan_parquet(parquet), collect = TRUE, max_rows = 1L), "no truncated file")
  expect_identical(tools::md5sum(parquet), before)
})
