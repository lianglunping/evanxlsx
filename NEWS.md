# evanxlsx 0.2.1

- Select Polars temporal columns by position, preserving literal wildcard/regex-like names.
- Warn when custom row names will not be written; never guess an ID column name.
- Isolate numeric/date/datetime/string-number/border formatting defaults and restore options.
- Ignore max_width entirely when widths is numeric, as documented.
- On a final-copy failure, try to restore the original or remove a new partial target;
  retain the complete new workbook and any valid backup, reporting their locations.
  This remains a single-writer, best-effort recovery policy, not a transaction.
- Remove obsolete Python packaging/static-audit tools. R CMD build is the package builder.
- Read the CI installation archive version from DESCRIPTION; keep one maintained HTML guide.
- Public arguments and mandatory dependencies are unchanged. Formatting/rowname warnings
  above are deliberate behavior changes. Old validation reports describe old versions only.

# evanxlsx 0.2.0

- Validate file/options before forcing input. Convert one worksheet at a time.
- Optional duckplyr and R Polars 1.16 adapters, explicit collect permission and per-sheet row cap.
- Check integer precision before R double conversion; preserve Decimal/temporal text.
- Reject unsupported backend schemas rather than silently flattening.
- Add installed bilingual examples/guide, missing-dependency resolution tests and real backend CI.
- Existing positional arguments and formatting defaults are retained.
- Migration: all duckplyr inputs require collect=TRUE or explicit upstream collection.
- Core R>=4.1.3 is separate from optional backend compatibility; no Polars 2.x support claim.

# evanxlsx 0.1.1

- Validated cross-platform core exports and three installation routes.
- Added deterministic bilingual fixtures and independent value/style checks.

# evanxlsx 0.1.0

- Initial candidate for consistent Excel exports using openxlsx2.
