# evanxlsx 0.4.0

Candidate, runtime acceptance pending. Main is preserved until tests are reviewed.
Two everyday entry points: import and export. Four supported extensions: XLSX, TXT, TSV, CSV.
README has exactly four main sections. Former detailed IO notes are an optional docs/advanced_io.md reference.
New wrappers reuse established readers/writers and the existing file recovery helper, not a new parsing framework.
Old data and export APIs remain; readr and tibble are required dependencies for unified IO and Polars remains optional.
