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
