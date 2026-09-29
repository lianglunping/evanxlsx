xml_part <- function(file, part) {
  out <- tempfile("evanxlsx-xml-")
  dir.create(out)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  utils::unzip(file, files = part, exdir = out)
  doc <- xml2::read_xml(file.path(out, part))
  xml2::xml_ns_strip(doc)
}

xml_cell <- function(doc, address) {
  xml2::xml_find_first(doc, sprintf(".//sheetData/row/c[@r='%s']", address))
}

cell_style <- function(file, address, sheet = 1L) {
  ws <- xml_part(file, sprintf("xl/worksheets/sheet%s.xml", sheet))
  ss <- xml_part(file, "xl/styles.xml")
  id <- xml2::xml_attr(xml_cell(ws, address), "s")
  if (is.na(id)) id <- "0"
  xml2::xml_find_all(ss, ".//cellXfs/xf")[[as.integer(id) + 1L]]
}

cell_font <- function(file, address, sheet = 1L) {
  xf <- cell_style(file, address, sheet)
  id <- xml2::xml_attr(xf, "fontId")
  if (is.na(id)) id <- "0"
  ss <- xml_part(file, "xl/styles.xml")
  xml2::xml_find_all(ss, ".//fonts/font")[[as.integer(id) + 1L]]
}

cell_border <- function(file, address, sheet = 1L) {
  xf <- cell_style(file, address, sheet)
  id <- xml2::xml_attr(xf, "borderId")
  if (is.na(id)) id <- "0"
  ss <- xml_part(file, "xl/styles.xml")
  xml2::xml_find_all(ss, ".//borders/border")[[as.integer(id) + 1L]]
}

attr_at <- function(doc, xpath, attribute) {
  xml2::xml_attr(xml2::xml_find_first(doc, xpath), attribute)
}

new_export <- function(x = data.frame(id = c("001", "002"), value = c(1, NA)), ...) {
  path <- tempfile(fileext = ".xlsx")
  evanxlsx::write_xlsx(x, path, ...)
  path
}
