test_that("invalid output or scalar options do not force the input promise", {
  f <- tempfile(fileext = ".xlsx")
  writeLines("original", f)
  expect_error(write_xlsx(stop("INPUT WAS FORCED"), f), "already exists")
  expect_error(write_xlsx(stop("INPUT WAS FORCED"), paste0(f, ".csv")), "end in .xlsx")
  expect_error(write_xlsx(stop("INPUT WAS FORCED"), tempfile(fileext = ".xlsx"), font_size = 0), "font_size")
  expect_error(write_xlsx(stop("INPUT WAS FORCED"), file.path(tempfile(), "x.xlsx")), "existing directory")
  expect_identical(readLines(f), "original")
})

test_that("query permission precedes schema access, including mixed lists", {
  # This sentinel has no schema or methods: refusal must happen from its class alone.
  lazy <- structure(list(), class = "polars_lazy_frame")
  expect_error(new_export(lazy), "collect = TRUE")
  expect_error(new_export(list(ordinary = data.frame(a = 1), query = lazy)), "query")
  duck <- structure(list(a = 1), class = c("duckplyr_df", "data.frame"))
  expect_error(new_export(duck), "collect = TRUE")
})

test_that("invalid worksheet names are checked before backend metadata", {
  lazy <- structure(list(), class = "polars_lazy_frame")
  expect_error(new_export(list('bad/name' = lazy), collect = TRUE), "Invalid sheet name")
})

test_that("row budgets are whole, bounded, per sheet and inclusive", {
  d <- data.frame(id = 1:3)
  for (n in list(-1, 1048576, 1.5, Inf, NA_real_, TRUE, "3", c(1, 2))) {
    expect_error(new_export(d, max_rows = n), "max_rows")
  }
  expect_no_error(new_export(d, max_rows = 3))
  expect_error(new_export(d, max_rows = 2), "no truncated file")
  expect_error(new_export(d, max_rows = 0), "row limits")
  expect_no_error(new_export(d[FALSE, , drop = FALSE], max_rows = 0))
  expect_no_error(new_export(list(a = d, b = d), max_rows = 3))
})

test_that("collect is a strict logical flag", {
  for (v in list(1, NA, "TRUE", c(TRUE, FALSE))) {
    expect_error(new_export(collect = v), "collect")
  }
  expect_no_error(new_export(collect = TRUE))
})

test_that("failure in a later sheet preserves an existing output without backup", {
  folder <- tempfile(); dir.create(folder)
  f <- file.path(folder, "result.xlsx")
  writeLines("original", f)
  before <- tools::md5sum(f)
  bad <- data.frame(a = 1); bad$x <- list(1:2)
  expect_error(write_xlsx(list(good = data.frame(a = 1), bad = bad), f, overwrite = TRUE),
               "unsupported column type")
  expect_identical(tools::md5sum(f), before)
  expect_identical(list.files(folder, all.files = TRUE, no.. = TRUE), "result.xlsx")
})

test_that("safe parameter additions do not change the old positional arguments", {
  n <- names(formals(write_xlsx))
  expect_identical(tail(n, 3L), c("overwrite", "collect", "max_rows"))
  expect_identical(formals(write_xlsx)$collect, FALSE)
  expect_identical(formals(write_xlsx)$max_rows, 1048575L)
})

test_that("installed examples and bilingual guide are available outside the source tree", {
  expect_true(file.exists(system.file("examples", "basic.R", package = "evanxlsx")))
  expect_true(file.exists(system.file("examples", "backends.R", package = "evanxlsx")))
  expect_true(file.exists(system.file("guide", "usage.html", package = "evanxlsx")))
})
