#!/usr/bin/env Rscript
# Optional workflow qualification, not an evanxlsx runtime dependency or new public API.
out <- file.path("validation", "tidy-qualification")
stopifnot(!dir.exists(out)); dir.create(out, recursive = TRUE)
library(dplyr, warn.conflicts = FALSE)
library(tidyr, warn.conflicts = FALSE)
library(tidypolars)
options(tidypolars_unknown_args = "error", tidypolars_fallback_to_r = FALSE,
        tidypolars_record_query = TRUE)
writeLines(c(paste("Commit:", Sys.getenv("GITHUB_SHA")), capture.output(sessionInfo()),
  vapply(c("polars", "tidypolars", "dplyr", "tidyr", "stringr", "evanxlsx"),
    function(p) paste(p, packageVersion(p)), character(1))), file.path(out, "versions.txt"))
checks <- data.frame(case = character(), status = character(), detail = character())
check <- function(id, expr) {
  err <- tryCatch({force(expr); NULL}, error = conditionMessage)
  checks <<- rbind(checks, data.frame(case = id, status = if (is.null(err)) "PASS" else "FAIL",
                                     detail = if (is.null(err)) "checked" else err))
  write.csv(checks, file.path(out, "checks.csv"), row.names = FALSE)
}
get_df <- function(x) if (inherits(x, "polars_lazy_frame")) as.data.frame(x$collect()) else as.data.frame(x)
same <- function(x, y) stopifnot(isTRUE(all.equal(as.data.frame(x), as.data.frame(y),
                                                  tolerance = 1e-12, check.attributes = FALSE)))
# Small extension only: a Polars expression, never an R row-wise callback.
# Fixed policy: ignore null/NaN, linear interpolation (R type=7), no outlier deletion.
pl_iqr <- function(x) {
  z <- x$fill_nan(NULL)
  z$quantile(0.75, interpolation = "linear") - z$quantile(0.25, interpolation = "linear")
}
raw <- data.frame(group = rep(c("A", "B"), each = 4L), value = c(1, 2, 3, NA, 10, 10, 10, NA))
x <- polars::as_polars_lf(raw)
check("01_mean_sd", {
  q <- x |> summarise(mean_value = mean(value, na.rm = TRUE), sd_value = sd(value, na.rm = TRUE), .by = group) |>
    arrange(group)
  stopifnot(inherits(q, "polars_lazy_frame"))
  ref <- raw |> summarise(mean_value = mean(value, na.rm = TRUE), sd_value = sd(value, na.rm = TRUE), .by = group) |>
    arrange(group)
  same(get_df(q), ref)
  writeLines(capture.output(show_query(q)), file.path(out, "mean_sd_polars_query.txt"))
  write.csv(get_df(q), file.path(out, "mean_sd.csv"), row.names = FALSE)
})
check("02_iqr_expression", {
  samples <- list(regular = c(1, 2, 3, 4, 100, NA), ties = c(2, 2, 2, NA),
                  singleton = c(5, NA), all_missing = c(NA_real_, NaN))
  for (v in samples) {
    z <- polars::as_polars_lf(data.frame(group = "G", value = v))
    got <- get_df(z |> summarise(iqr = pl_iqr(value), .by = group))$iqr
    target <- IQR(v, na.rm = TRUE, type = 7)
    if (is.na(target)) stopifnot(is.na(got)) else same(data.frame(got), data.frame(target))
  }
  q <- x |> summarise(iqr = pl_iqr(value), .by = group) |> arrange(group)
  same(get_df(q)$iqr, c(1, 0))
  writeLines(capture.output(show_query(q)), file.path(out, "iqr_polars_query.txt"))
})
check("03_split_column", {
  d <- data.frame(locus = c("Chr01:00123", "Chr02:00456", NA_character_))
  q <- polars::as_polars_lf(d) |> separate(locus, into = c("Chr", "Position"), sep = ":", remove = FALSE)
  same(get_df(q), separate(d, locus, into = c("Chr", "Position"), sep = ":", remove = FALSE))
  write.csv(get_df(q), file.path(out, "split.csv"), row.names = FALSE)
})
check("04_long_wide", {
  d <- data.frame(id = c("001", "002"), height = c(10, NA), weight = c(2.5, 3.5))
  q <- polars::as_polars_lf(d) |> pivot_longer(c(height, weight), names_to = "trait", values_to = "value")
  ref <- pivot_longer(d, c(height, weight), names_to = "trait", values_to = "value") |> arrange(id, trait)
  same(get_df(arrange(q, id, trait)), ref)
  wide <- pivot_wider(q, id_cols = id, names_from = trait, values_from = value) |> arrange(id)
  back <- get_df(wide)
  same(back[names(d)], d)
  write.csv(back, file.path(out, "wide.csv"), row.names = FALSE)
})
check("05_replace_na", {
  d <- data.frame(id = c("001", "002"), count = c(NA_real_, 2), note = c("Test", NA_character_))
  q <- polars::as_polars_lf(d) |> replace_na(list(count = 0, note = "Unknown"))
  same(get_df(q), replace_na(d, list(count = 0, note = "Unknown")))
})
check("06_fill_within_group", {
  d <- data.frame(group = c("A", "A", "B", "B"), row = 1:4, label = c("Rice", NA, NA, "Test"))
  q <- polars::as_polars_lf(d) |> arrange(group, row) |> fill(label, .by = group, .direction = "down") |> arrange(row)
  same(get_df(q), fill(d, label, .by = group, .direction = "down"))
})
check("07_clean_and_distinct", {
  d <- data.frame(id = c("001", "001", "002"), note = c(" Rice ", "Rice", " Test "))
  q <- polars::as_polars_lf(d) |> mutate(note = stringr::str_trim(note)) |> distinct() |> arrange(id)
  ref <- d |> mutate(note = stringr::str_trim(note)) |> distinct() |> arrange(id)
  same(get_df(q), ref)
})
check("08_direct_excel", {
  q <- x |> summarise(mean_value = mean(value, na.rm = TRUE), sd_value = sd(value, na.rm = TRUE),
                     iqr = pl_iqr(value), .by = group) |> arrange(group)
  stopifnot(inherits(q, "polars_lazy_frame"))
  f <- file.path(out, "tidy_summary.xlsx")
  evanxlsx::write_xlsx(q, f, collect = TRUE, max_rows = 100L)
  same(openxlsx2::read_xlsx(f), get_df(q))
})
# These calls explore availability rather than granting blanket Tidy compatibility.
limits <- list(
  native_IQR = quote(x |> summarise(iqr = IQR(value, na.rm = TRUE), .by = group)),
  separate_wider_delim = quote(polars::as_polars_lf(data.frame(key = "a:b")) |>
                                separate_wider_delim(key, delim = ":", names = c("a", "b"))),
  mean_trim = quote(x |> summarise(m = mean(value, trim = 0.1, na.rm = TRUE), .by = group)),
  wider_values_fn = quote(polars::as_polars_lf(data.frame(id = c("a", "a"), key = c("x", "x"), value = 1:2)) |>
                           pivot_wider(id_cols = id, names_from = key, values_from = value, values_fn = mean))
)
res <- lapply(names(limits), function(nm) {
  err <- tryCatch({get_df(eval(limits[[nm]])); NULL}, error = conditionMessage)
  data.frame(case = nm, status = if (is.null(err)) "SUPPORTED_IN_THIS_PROBE" else "LIMIT_REPRODUCED",
             detail = if (is.null(err)) "executed" else err)
})
write.csv(do.call(rbind, res), file.path(out, "compatibility_limits.csv"), row.names = FALSE)
print(checks)
writeLines(if (all(checks$status == "PASS")) "PASS_TESTED_RECIPES_ONLY" else "FAIL", file.path(out, "STATUS.txt"))
stopifnot(all(checks$status == "PASS"))
