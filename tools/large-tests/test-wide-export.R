out <- Sys.getenv("EVANXLSX_INTEGRATION_OUT")
stopifnot(nzchar(out))
test_that("larger 72-column data retain IDs, values and borders across three backends", {
  n <- 10000L
  d <- data.frame(Sample_ID = sprintf("%08d", seq_len(n)),
                   Description = rep(c("Synthetic \u5408\u6210", NA_character_), n / 2),
                   stringsAsFactors = FALSE)
  for (j in 3:72) d[[paste0("value_", j)]] <- (seq_len(n) %% (j + 1L)) / (j + 1L)
  before <- serialize(d, NULL)
  times <- data.frame(backend = character(), elapsed_seconds = numeric(), bytes = numeric())
  for (kind in c("r", "duckplyr", "polars_lazy")) {
    x <- switch(kind, r = d, duckplyr = duckplyr::as_duckdb_tibble(d, prudence = "stingy"),
                polars_lazy = polars::as_polars_df(d)$lazy())
    f <- file.path(out, paste0("large_", kind, ".xlsx"))
    elapsed <- system.time(write_xlsx(x, f, collect = TRUE, max_rows = n, widths = 16))["elapsed"]
    # Read representative typed columns in full, not only the final row.
    back <- openxlsx2::read_xlsx(f, cols = c(1L, 2L, 3L, 72L), skip_empty_rows = FALSE)
    expect_identical(back[[1]], d$Sample_ID)
    expect_identical(back[[2]], d$Description)
    expect_equal(back[[3]], d[[3]], tolerance = 1e-14)
    expect_equal(back[[4]], d[[72]], tolerance = 1e-14)
    expect_equal(nrow(back), n)
    expect_identical(attr_at(cell_border(f, "BT10001"), "bottom", "style"), "medium")
    times <- rbind(times, data.frame(backend = kind, elapsed_seconds = unname(elapsed), bytes = file.info(f)$size))
    utils::write.csv(times, file.path(out, "export_times.csv"), row.names = FALSE)
    rm(x, back)
  }
  expect_identical(serialize(d, NULL), before)
})
