# evanxlsx 0.5.0

- Keep two IO entry points; add cols, named types, prefix-only comment and lazy import options.
- Support Parquet import/export using the optional Polars backend; native lazy scans are not fake in-memory frames.
- Prefix comments intentionally use Polars semantics, not readr inline truncation. XLSX refuses lazy reads.
- Add only mutate_row_stats() for row-wise replicate means/SD; reuse existing cleaning and column-summary verbs.
- Reorganize the four-section README: missing/outlier handling first, then row/column summaries and presentation rows.
- Existing styled Excel export and statistical helpers remain unchanged; new tests cover real file scans.

# evanxlsx 0.4.0

- Introduce import()/export() for XLSX, TXT, TSV and CSV by extension.
- Reuse readr/openxlsx2, preserve sheet formatting and file backup/recovery.
- Readme has four entry sections: installation, input, output, processing.

# evanxlsx 0.3.1

- Binary rescaling for existing mean and SD calculations reduces demonstrated intermediate overflow/underflow.
- Add an installed complete workflow example, without a new public workflow API.

# evanxlsx 0.3.0

- Add optional summarise_numeric(), flag_iqr(), separate_strict(), assert_unique_keys().

# evanxlsx 0.2.1

- Fix literal temporal selection and improve rowname warnings, formatting isolation and file recovery.

# Earlier versions

Full historical release notes and validation records remain in Git history.
