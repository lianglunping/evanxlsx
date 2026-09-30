test_that("custom row names trigger an actionable warning without adding columns", {
  d <- data.frame(value = c(10, 20), row.names = c("gene_1", "gene_2"))
  before <- serialize(d, NULL)
  expect_warning(f <- new_export(d), "custom row names.*explicit column")
  expect_identical(names(openxlsx2::read_xlsx(f)), "value")
  expect_identical(serialize(d, NULL), before)
  expect_no_warning(new_export(data.frame(id = c("gene_1", "gene_2"), value = c(10, 20))))
  expect_no_warning(new_export(data.frame(value = numeric())))
})

test_that("fixed widths do not evaluate max_width and preserve ambient width options", {
  old <- options(openxlsx2.minWidth = 3, openxlsx2.maxWidth = 70)
  on.exit(options(old), add = TRUE)
  expect_no_error(new_export(widths = 16, max_width = stop("MUST NOT EVALUATE")))
  expect_no_error(new_export(widths = 16, max_width = NULL))
  expect_identical(getOption("openxlsx2.minWidth"), 3)
  expect_identical(getOption("openxlsx2.maxWidth"), 70)
  expect_error(new_export(widths = "auto", max_width = NULL), "max_width")
})

test_that("ambient numeric, ID and date formats cannot silently change export conventions", {
  old <- options(openxlsx2.numFmt = "0.00%", openxlsx2.dateFormat = "dd/mm/yy",
                 openxlsx2.datetimeFormat = "hh:mm", openxlsx2.string_nums = TRUE,
                 openxlsx2.borderColor = "red")
  on.exit(options(old), add = TRUE)
  before <- options()[names(old)]
  d <- data.frame(id = "000123", value = 0.12345, day = as.Date("2026-09-30"))
  f <- new_export(d)
  ws <- xml_part(f, "xl/worksheets/sheet1.xml")
  expect_identical(attr_at(xml_cell(ws, "A2"), ".", "t"), "inlineStr")
  expect_identical(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "A2"), "is/t")), "000123")
  expect_equal(as.numeric(xml2::xml_text(xml2::xml_find_first(xml_cell(ws, "B2"), "v"))), 0.12345)
  ss <- xml_part(f, "xl/styles.xml")
  formats <- xml2::xml_attr(xml2::xml_find_all(ss, ".//numFmt"), "formatCode")
  expect_false("0.00%" %in% formats)
  expect_true("yyyy-mm-dd" %in% formats)
  expect_identical(options()[names(old)], before)
  bad <- data.frame(value = I(list(1:2)))
  expect_error(new_export(bad), "unsupported column type")
  expect_identical(options()[names(old)], before)
})

# Inject failures only into local function copies and synthetic files.
copy_fixture <- function(existing, fail_backup = FALSE, fail_restore = FALSE, throws = FALSE) {
  folder <- tempfile("commit-test-"); dir.create(folder)
  f <- file.path(folder, "result.xlsx")
  tmp <- file.path(folder, ".evanxlsx-complete.xlsx")
  writeLines("COMPLETE NEW SYNTHETIC WORKBOOK", tmp)
  if (existing) writeLines("ORIGINAL SYNTHETIC CONTENT", f)
  env <- new.env(parent = asNamespace("evanxlsx"))
  env$file.copy <- function(from, to, overwrite) {
    if (identical(from, tmp)) {
      writeLines("PARTIAL", to)
      if (throws) stop("simulated filesystem error")
      return(FALSE)
    }
    if ((fail_backup && identical(from, f)) || (fail_restore && endsWith(from, ".bak"))) return(FALSE)
    base::file.copy(from, to, overwrite = overwrite)
  }
  fun <- getFromNamespace(".commit_file", "evanxlsx")
  environment(fun) <- env
  list(fun = fun, file = f, tmp = tmp, folder = folder)
}

test_that("partial final copy restores original and retains complete new workbook", {
  for (throws in c(FALSE, TRUE)) {
    x <- copy_fixture(TRUE, throws = throws)
    expect_error(suppressMessages(x$fun(x$tmp, x$file, TRUE)), "Original restored.*Complete new workbook retained")
    expect_identical(readLines(x$file), "ORIGINAL SYNTHETIC CONTENT")
    expect_identical(readLines(x$tmp), "COMPLETE NEW SYNTHETIC WORKBOOK")
    backups <- list.files(x$folder, pattern = "\\.bak$", full.names = TRUE)
    expect_length(backups, 1L)
    expect_identical(readLines(backups), "ORIGINAL SYNTHETIC CONTENT")
  }
})

test_that("partial new output is removed but completed temporary workbook survives", {
  x <- copy_fixture(FALSE)
  expect_error(x$fun(x$tmp, x$file, FALSE), "Incomplete target removed.*Complete new workbook retained")
  expect_false(file.exists(x$file))
  expect_true(file.exists(x$tmp))
})

test_that("restoration and backup failures are reported without losing good copies", {
  x <- copy_fixture(TRUE, fail_restore = TRUE)
  expect_error(suppressMessages(x$fun(x$tmp, x$file, TRUE)), "Automatic restoration failed")
  expect_true(file.exists(x$tmp))
  b <- list.files(x$folder, pattern = "\\.bak$", full.names = TRUE)
  expect_identical(readLines(b), "ORIGINAL SYNTHETIC CONTENT")
  x <- copy_fixture(TRUE, fail_backup = TRUE)
  expect_error(x$fun(x$tmp, x$file, TRUE), "original was not replaced")
  expect_identical(readLines(x$file), "ORIGINAL SYNTHETIC CONTENT")
  expect_true(file.exists(x$tmp))
  expect_error(x$fun(x$tmp, x$file, FALSE), "Output appeared")
  expect_identical(readLines(x$file), "ORIGINAL SYNTHETIC CONTENT")
})

test_that("public writer retains valid completed ZIP when final publication fails", {
  folder <- tempfile("writer-failure-"); dir.create(folder)
  f <- file.path(folder, "out.xlsx")
  env <- new.env(parent = asNamespace("evanxlsx"))
  env$.commit_file <- function(tmp, file, overwrite) stop("SIMULATED_FINAL_FAILURE")
  fun <- evanxlsx::write_xlsx; environment(fun) <- env
  expect_error(fun(data.frame(id = "0001"), f), "SIMULATED_FINAL_FAILURE")
  retained <- list.files(folder, pattern = "^\\.evanxlsx-", all.files = TRUE, full.names = TRUE)
  expect_length(retained, 1L)
  expect_true("xl/workbook.xml" %in% utils::unzip(retained, list = TRUE)$Name)
  expect_false(file.exists(f))
})
