# evanxlsx 0.1.0

Initial source implementation uploaded to the private repository. Runtime acceptance is tracked per commit in GitHub Actions; no stable release is declared.

- One exported function, `write_xlsx()`.
- A single font, adjustable size and horizontal/vertical alignment.
- Blank NA/NaN, bold headers, three-line borders and freeze panes.
- Automatic column widths with a cap, wrapping and optional filters.
- New-workbook export with overwrite protection and mandatory backups on replacement.
- Input validation, XML-level tests, Chinese usage documentation and CI configuration.
