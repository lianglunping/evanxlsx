# evanxlsx 0.3.1

- Stabilize numeric-summary mean and sample SD with internal power-of-two scaling.
  Reproduced 0.3.0 underflow/overflow cases are retained as regression tests.
  Input values, counts, missing/infinite policies, quartiles and public API are unchanged.
- Add an installed, bilingual end-to-end example: Parquet, explicit annotation
  cleaning/fill, exact-duplicate removal, strict splitting, long/wide conversion,
  summaries, IQR flags and a five-sheet workbook. No automatic trait imputation.
- Record actual stage classes rather than implying every pivot stays lazy.
- Add scaled numeric and practical workflow checks; no new mandatory dependency.

# evanxlsx 0.3.0

- Add four opt-in data helpers: summarise_numeric(), flag_iqr(), separate_strict(), assert_unique_keys().
- Tidy column selection uses optional rlang/tidyselect; calculations run as native Polars expressions.
- Results are Polars LazyFrames. Strict guards execute validation explicitly for lazy inputs.
- Finite-data counts, NaN/null policy, infinity invalidation, sample SD and type-7 quartiles are documented.
- Outlier flags never delete rows. Missing, insufficient, infinite and zero-IQR cases are explicit.
- Splitting is literal and strict; uniqueness checks do not select a pivot aggregation.
- No mandatory dependency or existing exporter implementation changes. No arbitrary Tidy compiler.
- Numeric 64-bit/Decimal measurements require explicit conversion; grouping/ID values are preserved.

# evanxlsx 0.2.1

- Fix literal temporal selection, custom-rowname warnings, scoped display defaults and ignored max_width.
- Preserve complete workbooks and attempt restoration after final-copy failure.
- Remove obsolete Python package/static tools; use R CMD build and one maintained exporter guide.
- Public exporter arguments and mandatory dependencies retained.

# evanxlsx 0.2.0

- Add optional duckplyr/Polars adapters, bounded collection and installed bilingual examples.
- Validate outputs before evaluating inputs, preserve exact types and Time precision.

# evanxlsx 0.1.1

- Validate cross-platform core exports and installation routes.

# evanxlsx 0.1.0

- Initial consistent Excel export candidate.
