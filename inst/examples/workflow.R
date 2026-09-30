# Synthetic end-to-end example / 中英文合成示例。
# source() only defines the function; calling it writes to a new directory.
# 只填补注释，不填补测量值；IQR只标记、不删行；只去掉完全重复的合成记录。
evanxlsx_workflow <- function(output_dir = tempfile("evanxlsx-workflow-")) {
  needed <- c("evanxlsx", "polars", "tidypolars", "dplyr", "tidyr", "stringr")
  missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Install separately: ", paste(missing, collapse = ", "))
  if (file.exists(output_dir) || dir.exists(output_dir)) stop("Choose a new output directory.")
  if (!dir.create(output_dir)) stop("Cannot create output directory.")
  old <- options(tidypolars_unknown_args = "error", tidypolars_fallback_to_r = FALSE)
  on.exit(options(old), add = TRUE)

  raw <- data.frame(
    Sample_ID = sprintf("%04d", 1:12), treatment = rep(c("A", "B"), each = 6),
    locus = paste0("Chr01:", sprintf("%05d", 1:12)),
    batch = c("Batch_A", rep(NA_character_, 5), "Batch_B", rep(NA_character_, 5)),
    note = rep(c(" Seedling 幼苗 ", NA_character_, "NA"), 4),
    height = c(80, 82, 84, 86, 88, 160, 90, 92, 94, 96, 98, NA_real_),
    weight = c(2, 4, 6, 8, 10, 12, 4, 6, 8, 10, 12, NaN),
    stringsAsFactors = FALSE
  )
  raw <- rbind(raw, raw[3, ]) # One deliberately identical duplicate / 一条完全重复记录。
  saveRDS(raw, file.path(output_dir, "raw.rds")) # RDS preserves NA versus NaN.
  polars::as_polars_df(raw)$write_parquet(file.path(output_dir, "raw.parquet"))
  pl_nan_to_null <- function(x) x$fill_nan(NULL) # Explicit expression, not an R callback.
  clean <- polars::pl$scan_parquet(file.path(output_dir, "raw.parquet")) |>
    dplyr::mutate(note = stringr::str_trim(note), weight = pl_nan_to_null(weight)) |>
    tidyr::replace_na(list(note = "Unknown / 未记录")) |>
    dplyr::distinct() |>
    dplyr::arrange(treatment, Sample_ID) |>
    tidyr::fill(batch, .by = treatment, .direction = "down")
  split <- clean |>
    evanxlsx::separate_strict(locus, c("Chr", "Position"), ":", collect = TRUE)
  long <- split |>
    tidyr::pivot_longer(c(height, weight), names_to = "trait", values_to = "value") |>
    dplyr::arrange(Sample_ID, trait)
  keyed <- long |>
    evanxlsx::assert_unique_keys(c(Sample_ID, trait), collect = TRUE)
  # Dynamic pivot schemas may execute earlier than final Excel export.
  # 长转宽并不保证仍是完全延迟计算，检查实际对象类型。
  wide <- keyed |>
    tidyr::pivot_wider(id_cols = c(Sample_ID, treatment), names_from = trait, values_from = value) |>
    dplyr::arrange(Sample_ID)
  summary <- clean |> evanxlsx::summarise_numeric(c(height, weight), .by = treatment)
  flagged <- long |> evanxlsx::flag_iqr(value, .by = c(treatment, trait))
  sheets <- list(clean = split, long = long, wide = wide, summary = summary, flagged = flagged)
  path <- evanxlsx::write_xlsx(sheets, file.path(output_dir, "workflow.xlsx"), collect = TRUE)
  writeLines(summary$explain(), file.path(output_dir, "summary_plan.txt"))
  utils::write.csv(data.frame(stage = names(sheets),
    object_class = vapply(sheets, function(x) paste(class(x), collapse = "/"), character(1))),
    file.path(output_dir, "stage_classes.csv"), row.names = FALSE)
  writeLines(c(capture.output(sessionInfo()),
    vapply(needed, function(p) paste(p, utils::packageVersion(p)), character(1))),
    file.path(output_dir, "environment.txt"))
  invisible(list(path = path, raw = raw, sheets = sheets, output_dir = output_dir))
}
