test_that("processed and lazy inputs use export for every supported format", {
  raw <- data.frame(g = c("A", "A", "B", "B"), v = c(1, 3, 5, 7))
  q <- summarise_numeric(raw, v, .by = g)
  for (ext in c("csv", "tsv", "txt", "xlsx")) {
    f <- tempfile(fileext = paste0(".", ext))
    expect_error(export(q, f), "collect = TRUE")
    export(q, f, collect = TRUE)
    back <- import(f)
    expect_equal(back$v__mean, c(2, 6))
    expect_identical(back$g, c("A", "B"))
  }
  for (x in list(polars::as_polars_df(raw),
                 duckplyr::as_duckdb_tibble(raw, prudence = "stingy"))) {
    f <- tempfile(fileext = ".csv")
    export(x, f, collect = TRUE)
    expect_equal(as.data.frame(import(f)), raw)
  }
})
