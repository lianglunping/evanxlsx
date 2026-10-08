#!/usr/bin/env Rscript
# Execute the actual marked README snippets, then inspect their outputs.
# Installation and user-path illustrative snippets are parsed but not executed.
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
needed <- c("evanxlsx", "openxlsx2", "tibble", "readr", "readxl", "data.table", "vroom",
            "polars", "duckplyr", "dplyr", "tidyr", "tidypolars", "stringr", "xml2", "testthat")
stopifnot(all(vapply(needed, requireNamespace, logical(1), quietly = TRUE)))
stopifnot(utils::packageVersion("evanxlsx") == read.dcf("DESCRIPTION")[1, "Version"])
dir.create("validation", showWarnings = FALSE)
out <- tempfile("readme-", tmpdir = normalizePath("validation", winslash = "/"))
stopifnot(dir.create(out))
writeLines("RUNNING", file.path(out, "STATUS.txt"))
writeLines(c(paste("Commit:", Sys.getenv("GITHUB_SHA")), capture.output(sessionInfo()),
             vapply(needed, function(p) paste(p, utils::packageVersion(p)), character(1))),
           file.path(out, "environment.txt"))
write.csv(tools::md5sum(list.files("R", full.names = TRUE)), file.path(out, "runtime-md5.csv"))

extract <- function(file, marker = "example") {
  lines <- readLines(file, encoding = "UTF-8", warn = FALSE)
  blocks <- list(); id <- NULL; inside <- FALSE; body <- character()
  for (line in lines) {
    if (grepl(paste0("^<!-- ", marker, ": "), line)) {
      id <- sub(paste0("^<!-- ", marker, ": (.*) -->$"), "\\1", line)
    } else if (identical(line, "```r")) {
      inside <- TRUE; body <- character()
    } else if (inside && identical(line, "```")) {
      parse(text = body) # Also parse unmarked installation/illustrative code, never execute it.
      if (!is.null(id)) {
        if (id %in% names(blocks)) stop("Duplicate example ID: ", id)
        blocks[[id]] <- paste(body, collapse = "\n")
      }
      id <- NULL; inside <- FALSE
    } else if (inside) body <- c(body, line)
  }
  if (inside) stop("Unclosed R code fence in ", file)
  blocks
}
blocks <- extract("README.md")
expected_ids <- c("setup", "xlsx_single", "xlsx_multi", "xlsx_read", "xlsx_all", "xlsx_range",
                  "readxl", "append_sheet", "replace_sheet_data", "text_write", "text_read",
                  "convert", "formatting", "dplyr", "data_table", "vroom", "polars_io",
                  "tidy_polars", "duckplyr")
stopifnot(identical(names(blocks), expected_ids))
mirrors <- extract("README.en.md", marker = "mirror")
for (id in names(mirrors)) stopifnot(identical(mirrors[[id]], blocks[[id]]))

# No spreadsheet edits in these checks: parse the files created by the README's R calls.
part_xml <- function(file, path) {
  dir <- tempfile("xml-"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  utils::unzip(file, files = path, exdir = dir)
  doc <- xml2::read_xml(file.path(dir, path)); xml2::xml_ns_strip(doc); doc
}
plain <- function(x) {
  x <- as.data.frame(x); rownames(x) <- NULL; x
}
same_table <- function(actual, expected) {
  actual <- plain(actual); expected <- plain(expected)
  stopifnot(identical(names(actual), names(expected)), nrow(actual) == nrow(expected))
  for (nm in names(expected)) {
    a <- actual[[nm]]; b <- expected[[nm]]
    if (is.character(b)) stopifnot(is.character(a), identical(enc2utf8(a), enc2utf8(b)))
    else if (is.numeric(b)) stopifnot(is.numeric(a), isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = 1e-12)))
    else stopifnot(identical(a, b))
  }
}
read_sheet <- function(file, sheet = 1) openxlsx2::read_xlsx(file, sheet = sheet)
checks <- data.frame(example = names(blocks), state = "NOT_RUN", detail = "")
extras <- data.frame(check = character(), state = character())
save_state <- function() write.csv(checks, file.path(out, "examples.csv"), row.names = FALSE)
save_state()
env <- new.env(parent = globalenv())
old_options <- options()
on.exit <- NULL # This script is a process entry point; restore explicitly in its finalizer below.

verify <- function(id) {
  e <- env
  switch(id,
    setup = stopifnot(nrow(e$df) == 8L, !anyDuplicated(e$df$Sample_ID)),
    xlsx_single = {
      f <- file.path(e$demo_dir, "single.xlsx")
      stopifnot(identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(f))), "var"))
      same_table(read_sheet(f, "var"), e$df)
    },
    xlsx_multi = {
      stopifnot(identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(e$xlsx_file))), c("variant_info", "id83")))
      same_table(read_sheet(e$xlsx_file, "variant_info"), e$df)
      same_table(read_sheet(e$xlsx_file, "id83"), e$df1)
      e$baseline_md5 <- tools::md5sum(e$xlsx_file)
      ws <- part_xml(e$xlsx_file, "xl/worksheets/sheet1.xml")
      stopifnot(length(xml2::xml_find_all(ws, ".//f")) == 0L,
                xml2::xml_text(xml2::xml_find_first(ws, ".//c[@r='E9']/is/t")) == "=1+1")
    },
    xlsx_read = {same_table(e$from_xlsx, e$df); same_table(e$from_second, e$df1)},
    xlsx_all = {
      stopifnot(identical(names(e$all_sheets), c("variant_info", "id83")))
      same_table(e$all_sheets[[1]], e$df); same_table(e$all_sheets[[2]], e$df1)
    },
    xlsx_range = same_table(e$part, e$df[1:3, 1:3]),
    readxl = {
      ref <- e$df; ref$note[!is.na(ref$note) & ref$note == ""] <- NA_character_
      same_table(e$from_readxl, ref)
    },
    append_sheet = {
      f <- file.path(e$demo_dir, "WES_added.xlsx")
      stopifnot(identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(f))),
                          c("variant_info", "id83", "extra_summary")))
      same_table(read_sheet(f, "variant_info"), e$df); same_table(read_sheet(f, "id83"), e$df1)
      stopifnot(read_sheet(f, "extra_summary")$n_records == 8,
                identical(tools::md5sum(e$xlsx_file), e$baseline_md5))
    },
    replace_sheet_data = {
      f <- file.path(e$demo_dir, "WES_rebuilt.xlsx")
      same_table(read_sheet(f, "variant_info"), e$df)
      same_table(read_sheet(f, "id83"), data.frame(category = "SYN_REVISED", count = 9))
      stopifnot(identical(tools::md5sum(e$xlsx_file), e$baseline_md5))
    },
    text_write = stopifnot(file.exists(e$csv_file), file.exists(e$tsv_file)),
    text_read = {same_table(e$from_csv, e$df); same_table(e$from_tsv, e$df)},
    convert = {
      same_table(readr::read_tsv(file.path(e$demo_dir, "csv_to_tsv.tsv"), col_types = e$col_spec, na = "<MISSING>", trim_ws = FALSE), e$df)
      same_table(readr::read_csv(file.path(e$demo_dir, "xlsx_to_csv.csv"), col_types = e$col_spec, na = "<MISSING>", trim_ws = FALSE), e$df)
      same_table(read_sheet(file.path(e$demo_dir, "tsv_to_xlsx.xlsx"), "var"), e$df)
      f <- file.path(e$demo_dir, "utf8_for_excel.csv")
      stopifnot(identical(readBin(f, "raw", n = 3), as.raw(c(239,187,191))))
      same_table(readr::read_csv(f, col_types = e$col_spec, na = "<MISSING>", trim_ws = FALSE), e$df)
    },
    formatting = {
      f <- file.path(e$demo_dir, "formatted.xlsx")
      same_table(read_sheet(f, "中文 表"), e$df)
      ws <- part_xml(f, "xl/worksheets/sheet1.xml"); ss <- part_xml(f, "xl/styles.xml")
      pane <- xml2::xml_find_first(ws, ".//pane")
      stopifnot(xml2::xml_attr(pane, "xSplit") == "1", xml2::xml_attr(pane, "ySplit") == "1",
                length(xml2::xml_find_all(ws, ".//autoFilter")) == 1L)
      cell <- xml2::xml_find_first(ws, ".//c[@r='A2']")
      xf <- xml2::xml_find_all(ss, ".//cellXfs/xf")[[as.integer(xml2::xml_attr(cell, "s")) + 1L]]
      stopifnot(xml2::xml_attr(xml2::xml_find_first(xf, "alignment"), "horizontal") == "left")
      font <- xml2::xml_find_all(ss, ".//fonts/font")[[as.integer(xml2::xml_attr(xf, "fontId")) + 1L]]
      stopifnot(xml2::xml_attr(xml2::xml_find_first(font, "name"), "val") == "Arial",
                xml2::xml_attr(xml2::xml_find_first(font, "sz"), "val") == "12")
    },
    dplyr = {
      ref <- data.frame(treatment = c("A","B"), n_valid = c(3,4), mean_height = c(82,109),
                        sd_height = c(stats::sd(c(80,82,84)),stats::sd(c(90,92,94,160))))
      same_table(e$r_summary, ref)
      same_table(read_sheet(file.path(e$demo_dir, "dplyr_summary.xlsx"), "summary"), ref)
    },
    data_table = {
      same_table(e$dt, e$df)
      same_table(read_sheet(file.path(e$demo_dir, "fread.xlsx"), "var"), e$df)
      same_table(readr::read_csv(file.path(e$demo_dir,"fwrite.csv"), col_types=e$col_spec,na="<MISSING>",trim_ws=FALSE),e$df)
      same_table(readr::read_tsv(file.path(e$demo_dir,"fwrite.tsv"), col_types=e$col_spec,na="<MISSING>",trim_ws=FALSE),e$df)
    },
    vroom = {same_table(e$from_vroom, e$df); same_table(read_sheet(file.path(e$demo_dir, "vroom.xlsx")), e$df)},
    polars_io = {
      for (q in list(e$q_csv, e$q_tsv, e$q_parquet)) {
        stopifnot(inherits(q,"polars_lazy_frame")); same_table(as.data.frame(q$collect()), e$df)
      }
      same_table(readr::read_csv(file.path(e$demo_dir,"polars.csv"),col_types=e$col_spec,na="<MISSING>",trim_ws=FALSE),e$df)
      same_table(readr::read_tsv(file.path(e$demo_dir,"polars.tsv"),col_types=e$col_spec,na="<MISSING>",trim_ws=FALSE),e$df)
      for(s in c("csv","tsv","parquet")) same_table(read_sheet(file.path(e$demo_dir,"polars_sources.xlsx"),s),e$df)
      writeLines(e$q_tsv$explain(),file.path(out,"csv_scan_plan.txt"))
    },
    tidy_polars = {
      stopifnot(inherits(e$metrics,"polars_lazy_frame"))
      m <- as.data.frame(e$metrics$collect())
      stopifnot(identical(m$treatment,c("A","B")), isTRUE(all.equal(m$height__mean,c(82,109))))
      w <- if(inherits(e$wide,"polars_lazy_frame")) as.data.frame(e$wide$collect()) else as.data.frame(e$wide)
      same_table(w[c("Sample_ID","treatment","height","weight")],e$df[c("Sample_ID","treatment","height","weight")])
      stopifnot(nrow(as.data.frame(e$long$collect())) == 16L)
      ref <- e$df; ref$note <- trimws(ref$note); ref$note[is.na(ref$note)] <- "Unknown / 未记录"
      same_table(as.data.frame(e$clean$collect()),ref)
      stopifnot(identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(file.path(e$demo_dir,"tidy_polars.xlsx")))),
                          c("summary","long","wide","clean")))
      writeLines(e$metrics$explain(),file.path(out,"tidy_summary_plan.txt"))
    },
    duckplyr = {
      same_table(dplyr::collect(e$duck),e$df)
      ref <- data.frame(treatment=c("A","B"),mean_height=c(82,109))
      same_table(e$duck_small,ref)
      same_table(read_sheet(file.path(e$demo_dir,"duckplyr.xlsx"),"summary"),ref)
      same_table(readr::read_csv(file.path(e$demo_dir,"duckplyr_summary.csv"),show_col_types=FALSE),ref)
      same_table(readr::read_tsv(file.path(e$demo_dir,"duckplyr_summary.tsv"),show_col_types=FALSE),ref)
    }
  )
  invisible(TRUE)
}

finish <- function() {
  options(old_options)
  if (exists("demo_dir", envir = env, inherits = FALSE) && dir.exists(env$demo_dir)) {
    target <- file.path(out,"files"); dir.create(target, showWarnings=FALSE)
    fs <- list.files(env$demo_dir,full.names=TRUE,all.files=TRUE,no..=TRUE)
    if(length(fs)) stopifnot(all(file.copy(fs,target,recursive=TRUE,overwrite=FALSE)))
  }
}
result <- tryCatch({
  for (i in seq_along(blocks)) {
    id <- names(blocks)[i]; warnings <- character()
    cat("README EXAMPLE:", id, "\n")
    err <- tryCatch({
      withCallingHandlers(eval(parse(text=blocks[[i]]),envir=env),warning=function(w) {
        warnings <<- c(warnings,conditionMessage(w)); invokeRestart("muffleWarning")
      })
      if(length(warnings)) stop(paste(warnings,collapse=" | "))
      verify(id); NULL
    },error=conditionMessage)
    checks$state[i] <- if(is.null(err)) "PASS" else "FAIL"
    checks$detail[i] <- if(is.null(err)) "Executed README code and checked outputs" else err
    save_state()
    if(!is.null(err)) stop(id, ": ", err)
  }
  extra <- function(id, expression) {
    force(expression)
    extras <<- rbind(extras,data.frame(check=id,state="PASS"))
    write.csv(extras,file.path(out,"additional_checks.csv"),row.names=FALSE)
  }
  extra("xlsx_missing_sheet", testthat::expect_error(openxlsx2::read_xlsx(env$xlsx_file,sheet="not_a_sheet")))
  extra("xlsx_noncontiguous_rows_columns", {
    d <- openxlsx2::wb_to_df(env$wb,sheet="variant_info",rows=c(1,3,5),cols=c(1,3))
    same_table(d,env$df[c(2,4),c(1,3)])
  })
  extra("xlsx_offset_header", {
    w <- openxlsx2::wb_workbook(); w$add_worksheet("offset")
    w$add_data("offset",env$df,start_row=3,start_col=2,na=NULL)
    same_table(openxlsx2::wb_to_df(w,sheet="offset",start_row=3,start_col=2),env$df)
  })
  extra("readxl_range_and_sheet_index", {
    a <- readxl::read_excel(env$xlsx_file,sheet=1,range="A1:C4",col_types=c("text","text","numeric"))
    same_table(a,env$df[1:3,1:3])
  })
  extra("readr_column_selection", {
    a <- readr::read_csv(env$csv_file,col_types=env$col_spec,col_select=c(Sample_ID,height),na="<MISSING>",trim_ws=FALSE)
    same_table(a,env$df[c("Sample_ID","height")])
  })
  extra("overwrite_refusal_keeps_source", {
    testthat::expect_error(evanxlsx::write_xlsx(env$df,env$xlsx_file),"already exists")
    stopifnot(identical(tools::md5sum(env$xlsx_file),env$baseline_md5))
  })
  extra("overwrite_replaces_whole_workbook_with_backup", {
    f <- file.path(env$demo_dir,"explicit_overwrite.xlsx")
    stopifnot(file.copy(env$xlsx_file,f,overwrite=FALSE))
    evanxlsx::write_xlsx(env$df,f,sheet="only_var",overwrite=TRUE)
    stopifnot(identical(unname(openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(f))),"only_var"))
    b <- list.files(env$demo_dir,pattern="^explicit_overwrite\\.xlsx.*\\.bak$",full.names=TRUE)
    stopifnot(length(b)==1L,unname(tools::md5sum(b))==unname(env$baseline_md5))
  })
  extra("local_markdown_links_exist", {
    for(f in c("README.md","README.en.md")) {
      txt <- paste(readLines(f,encoding="UTF-8",warn=FALSE),collapse="\n")
      links <- regmatches(txt,gregexpr("\\]\\(([^ )]+)\\)",txt,perl=TRUE))[[1]]
      links <- sub("^\\]\\(","",sub("\\)$","",links))
      local <- links[!grepl("^(https?://|#)",links)]
      paths <- sub("#.*$","",local)
      stopifnot(all(file.exists(paths)))
    }
  })
  writeLines(c("# Executed README snippets / 已执行的README代码块",
    "# Install optional dependencies separately. All outputs use a fresh temporary directory.",
    unlist(Map(function(id,code)c(paste0("\n# ---- ",id," ----"),code),names(blocks),blocks))),
    file.path(out,"readme_io_examples.R"))
  writeLines("PASS_README_EXAMPLES",file.path(out,"STATUS.txt"))
  TRUE
},error=function(e) {
  writeLines(c("FAIL",conditionMessage(e)),file.path(out,"STATUS.txt"))
  message(conditionMessage(e)); FALSE
})
finish()
if(!result) quit(status=1L)
cat("Evidence:",out,"\n")
