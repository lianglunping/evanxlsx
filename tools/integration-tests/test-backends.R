# Dedicated suite: backend absence is a failure, never an automatic skip.
pl <- polars::pl
out <- Sys.getenv("EVANXLSX_INTEGRATION_OUT")
stopifnot(nzchar(out))
fixture <- data.frame(
  Sample_ID = sprintf("%04d", 1:24),
  Note = rep(c("\u6c34\u7a3b Rice", NA_character_, "NA", "", "a < b & c", "line1\n\u4e2d\u6587"), 4),
  Score = rep(c(0.25, NA_real_, -2.5, 0, 1.5, 8), 4),
  Flag = rep(c(TRUE, FALSE, NA), 8),
  Day = as.Date("2026-09-01") + 0:23,
  stringsAsFactors = FALSE
)
pdf <- polars::as_polars_df(fixture)
make_duck <- function(prudence = "stingy") duckplyr::as_duckdb_tibble(fixture, prudence = prudence)
backend_export <- function(x, name, ...) {
  path <- file.path(out, paste0(name, ".xlsx"))
  evanxlsx::write_xlsx(x, path, ...)
  path
}
values_xml <- function(path, s = 1L) {
  ws <- xml_part(path, sprintf("xl/worksheets/sheet%d.xml", s))
  cells <- xml2::xml_find_all(ws, ".//sheetData/row/c")
  data.frame(address = xml2::xml_attr(cells, "r"),
             type = xml2::xml_attr(cells, "t"),
             value = vapply(cells, function(c) xml2::xml_text(c), character(1)),
             stringsAsFactors = FALSE)
}
text_at <- function(path, address) {
  ws <- xml_part(path, "xl/worksheets/sheet1.xml")
  xml2::xml_text(xml2::xml_find_first(xml_cell(ws, address), "is/t"))
}
number_at <- function(path, address) {
  ws <- xml_part(path, "xl/worksheets/sheet1.xml")
  as.numeric(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, address), "v")))
}

test_that("real backends and mixed sheets retain all fixture values and styles", {
  q <- make_duck()
  before <- serialize(fixture, NULL)
  f <- backend_export(list(ordinary = fixture, duck = q, polars = pdf, lazy = pdf$lazy()),
                       "mixed", collect = TRUE, max_rows = nrow(fixture), font = "Arial", font_size = 12)
  expected <- values_xml(f, 1L)
  for (s in 2:4) {
    expect_identical(values_xml(f, s), expected)
    expect_identical(attr_at(cell_font(f, "A2", s), "name", "val"), "Arial")
    expect_identical(attr_at(cell_font(f, "A2", s), "sz", "val"), "12")
    expect_identical(attr_at(cell_style(f, "A2", s), "alignment", "horizontal"), "center")
    expect_identical(attr_at(cell_border(f, "A25", s), "bottom", "style"), "medium")
  }
  expect_identical(serialize(fixture, NULL), before)
  expect_error(nrow(q), "materializ|pruden|stingy|prohibit|large")
  expect_identical(as.data.frame(pdf), fixture)
})

test_that("all duckplyr prudence levels and Polars lazy require permission", {
  for (p in c("stingy", "thrifty", "lavish")) {
    q <- make_duck(p)
    path <- file.path(out, paste0("permission_", p, ".xlsx"))
    expect_error(write_xlsx(q, path), "collect = TRUE")
    expect_false(file.exists(path))
    expect_no_error(write_xlsx(q, path, collect = TRUE, widths = 16))
  }
  expect_error(new_export(pdf$lazy()), "collect = TRUE")
  expect_no_error(new_export(pdf))
})

test_that("row limits are inclusive, checked on final output, and never truncate", {
  objects <- list(make_duck(), pdf, pdf$lazy())
  for (x in objects) {
    expect_no_error(new_export(x, collect = TRUE, max_rows = 24L))
    f <- tempfile(fileext = ".xlsx")
    expect_error(write_xlsx(x, f, collect = TRUE, max_rows = 23L), "no truncated file")
    expect_false(file.exists(f))
    expect_error(new_export(x, collect = TRUE, max_rows = 0L), "row limits")
  }
  q <- utils::head(make_duck(), 3L)
  expect_no_error(new_export(q, collect = TRUE, max_rows = 3L))
  expect_no_error(new_export(pdf$lazy()$head(3L), collect = TRUE, max_rows = 3L))
  expect_no_error(new_export(utils::head(make_duck(), 0L), collect = TRUE, max_rows = 0L))
  expect_no_error(new_export(pdf$lazy()$head(0L), collect = TRUE, max_rows = 0L))
})

test_that("collection uses one bounded execution without mutating input queries", {
  # An explicit oracle checks the adapter call graph as well as real output tests above.
  materialize <- getFromNamespace(".materialize_sheet", "evanxlsx")
  calls <- list()
  fake <- list(head = function(n) {
    calls[[length(calls) + 1L]] <<- n
    list(collect = function(engine) { calls[[length(calls) + 1L]] <<- engine; pdf })
  })
  meta <- getFromNamespace(".inspect_sheet", "evanxlsx")(pdf, "polars", "s", 24L)
  meta$kind <- "polars_lazy"
  expect_identical(materialize(fake, meta, "s", 24L), fixture)
  expect_identical(calls, list(25L, "in-memory"))
})

test_that("Int64 and UInt64 are checked before any double conversion", {
  x <- pl$DataFrame(small = c("999999999999999", "-999999999999999", NA_character_),
                    id = c("1000000000000001", "9223372036854775807", NA_character_),
                    unsigned = c("18446744073709551615", "0", NA_character_))$with_columns(
    pl$col(c("small", "id"))$cast(pl$Int64), pl$col("unsigned")$cast(pl$UInt64))
  before <- as.data.frame(x, int64 = "character")
  f <- backend_export(x$lazy(), "wide_integers", collect = TRUE)
  expect_equal(number_at(f, "A2"), 999999999999999)
  expect_equal(number_at(f, "A3"), -999999999999999)
  expect_identical(text_at(f, "B2"), "1000000000000001")
  expect_identical(text_at(f, "B3"), "9223372036854775807")
  expect_identical(text_at(f, "C2"), "18446744073709551615")
  expect_identical(text_at(f, "C3"), "0")
  expect_identical(as.data.frame(x, int64 = "character"), before)
  ws <- xml_part(f, "xl/worksheets/sheet1.xml")
  for (a in c("A4", "B4", "C4")) expect_length(xml2::xml_find_all(xml_cell(ws, a), "v|is|f"), 0L)
})

test_that("Decimal retains exact strings including fractional digits", {
  v <- c("12345678901234567890.12345678", "0.00000001", NA_character_)
  x <- pl$DataFrame(value = v)$with_columns(pl$col("value")$cast(pl$Decimal(30, 8)))
  f <- backend_export(x, "decimal")
  expect_identical(text_at(f, "A2"), v[1])
  expect_identical(text_at(f, "A3"), v[2])
})

test_that("nanosecond datetime is exported as text before POSIXct conversion", {
  v <- c("2026-09-29 01:02:03.123456789", NA_character_)
  x <- pl$DataFrame(value = v)$with_columns(pl$col("value")$str$to_datetime(time_unit = "ns"))
  f <- backend_export(x$lazy(), "nanoseconds", collect = TRUE)
  expect_identical(text_at(f, "A2"), v[1])
})

test_that("unsupported Polars schemas fail before collection and before replacing files", {
  base <- pl$DataFrame(a = 1:2)
  bad <- base$with_columns(pl$struct("a")$alias("nested"))
  f <- file.path(out, "unchanged.xlsx"); writeLines("original", f)
  before <- tools::md5sum(f)
  expect_error(write_xlsx(list(duck = make_duck(), bad = bad$lazy()), f,
                         collect = TRUE, overwrite = TRUE), "bad\\$nested.*unsupported Polars")
  expect_identical(tools::md5sum(f), before)
  list_df <- pl$DataFrame(a = list(1:2, 3:4))
  expect_error(new_export(list_df$lazy(), collect = TRUE), "unsupported Polars type List")
})

test_that("preflight refuses invalid output before querying real backends", {
  f <- tempfile(fileext = ".xlsx"); writeLines("original", f)
  for (x in list(make_duck(), pdf$lazy())) {
    expect_error(write_xlsx(x, f, collect = TRUE), "already exists")
    expect_error(new_export(x, collect = TRUE, widths = c(1, 2)), "column count")
    expect_error(new_export(x, collect = TRUE, font_size = 0), "font_size")
    expect_identical(readLines(f), "original")
  }
})

test_that("backend fixture has a reproducible larger 72-column export", {
  n <- 10000L
  d <- data.frame(Sample_ID = sprintf("%08d", seq_len(n)),
                   Description = rep(c("Synthetic \u5408\u6210", NA_character_), n / 2),
                   stringsAsFactors = FALSE)
  for (j in 3:72) d[[paste0("value_", j)]] <- (seq_len(n) %% (j + 1L)) / (j + 1L)
  before <- tools::md5sum(file.path(out, "mixed.xlsx"))
  times <- data.frame(backend = character(), elapsed_seconds = numeric(), bytes = numeric())
  for (kind in c("r", "duckplyr", "polars_lazy")) {
    x <- switch(kind, r = d, duckplyr = duckplyr::as_duckdb_tibble(d, prudence = "stingy"),
                polars_lazy = polars::as_polars_df(d)$lazy())
    f <- file.path(out, paste0("large_", kind, ".xlsx"))
    elapsed <- system.time(write_xlsx(x, f, collect = TRUE, max_rows = n, widths = 16))["elapsed"]
    back <- openxlsx2::read_xlsx(f, cols = 1L, skip_empty_rows = FALSE)
    expect_identical(back[[1]], d$Sample_ID)
    expect_equal(nrow(back), n)
    expect_identical(attr_at(cell_border(f, "BT10001"), "bottom", "style"), "medium")
    times <- rbind(times, data.frame(backend = kind, elapsed_seconds = unname(elapsed), bytes = file.info(f)$size))
    rm(x)
  }
  utils::write.csv(times, file.path(out, "export_times.csv"), row.names = FALSE)
  expect_identical(tools::md5sum(file.path(out, "mixed.xlsx")), before)
})
