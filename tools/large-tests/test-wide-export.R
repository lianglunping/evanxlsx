out <- Sys.getenv("EVANXLSX_INTEGRATION_OUT")
stopifnot(nzchar(out))
read_part_ns <- function(file, part) {
  folder <- tempfile(); dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE), add = TRUE)
  utils::unzip(file, files = part, exdir = folder)
  xml2::read_xml(file.path(folder, part))
}

test_that("larger 72-column data retain IDs, values and borders across three backends", {
  n <- 10000L
  d <- data.frame(Sample_ID = sprintf("%08d", seq_len(n)),
                   Description = rep(c("Synthetic \u5408\u6210", NA_character_), n / 2),
                   stringsAsFactors = FALSE)
  for (j in 3:72) d[[paste0("value_", j)]] <- (seq_len(n) %% (j + 1L)) / (j + 1L)
  before <- serialize(d, NULL)
  times <- data.frame(backend = character(), elapsed_seconds = numeric(), bytes = numeric())
  ns <- c(x = "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
  for (kind in c("r", "duckplyr", "polars_lazy")) {
    x <- switch(kind, r = d, duckplyr = duckplyr::as_duckdb_tibble(d, prudence = "stingy"),
                polars_lazy = polars::as_polars_df(d)$lazy())
    f <- file.path(out, paste0("large_", kind, ".xlsx"))
    elapsed <- system.time(write_xlsx(x, f, collect = TRUE, max_rows = n, widths = 16))["elapsed"]
    times <- rbind(times, data.frame(backend = kind, elapsed_seconds = unname(elapsed), bytes = file.info(f)$size))
    utils::write.csv(times, file.path(out, "export_times.csv"), row.names = FALSE)
    cat("\nExport finished: ", kind, "; read-only XML checks follow.\n", sep = "")
    # Read the XML with its namespace intact; do not use the slow large-sheet readback path.
    ws <- read_part_ns(f, "xl/worksheets/sheet1.xml")
    cells <- xml2::xml_find_all(ws, "x:sheetData/x:row/x:c", ns)
    refs <- xml2::xml_attr(cells, "r")
    expect_false(anyDuplicated(refs) > 0L)
    expect_equal(length(xml2::xml_find_all(ws, "x:sheetData/x:row", ns)), n + 1L)
    for (j in c(1L, 2L, 3L, 72L)) {
      col <- openxlsx2::int2col(j)
      at <- match(paste0(col, seq_len(n) + 1L), refs)
      expect_false(anyNA(at))
      selected <- cells[at]
      v <- xml2::xml_text(xml2::xml_find_first(selected, "x:is/x:t|x:v", ns))
      if (j <= 2L) {
        expect_identical(v, d[[j]])
      } else {
        expect_equal(as.numeric(v), d[[j]], tolerance = 1e-14)
      }
      missing <- is.na(d[[j]])
      if (any(missing)) expect_length(xml2::xml_find_all(selected[missing], "x:v|x:is|x:f", ns), 0L)
    }
    ss <- read_part_ns(f, "xl/styles.xml")
    last <- cells[[match("BT10001", refs)]]
    sid <- as.integer(xml2::xml_attr(last, "s"))
    xf <- xml2::xml_find_all(ss, "x:cellXfs/x:xf", ns)[[sid + 1L]]
    bid <- as.integer(xml2::xml_attr(xf, "borderId"))
    border <- xml2::xml_find_all(ss, "x:borders/x:border", ns)[[bid + 1L]]
    expect_identical(xml2::xml_attr(xml2::xml_find_first(border, "x:bottom", ns), "style"), "medium")
    rm(x, ws, cells, refs, selected, ss)
  }
  expect_identical(serialize(d, NULL), before)
})
