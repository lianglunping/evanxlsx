# evanxlsx

[中文](README.md) · [Bilingual guide](docs/usage.html) · [Validation status](validation/STATUS.md)

A small R package for consistent Excel exports. Version **0.1.1**; one exported function;
only `openxlsx2` is a direct runtime dependency. The repository remains private.
All fixtures are synthetic. An upload is not proof of a passing runtime check.

## Install on another computer

Requires **R ≥ 4.1.3**, **openxlsx2 ≥ 1.29**, and a writable R library.
The package itself is pure R, but building dependencies from source may require compilers.
Portability does not mean installation on devices without R, missing dependencies,
or networks that block the required downloads.

### Local source archive: no GitHub login required

Select the delivered `evanxlsx_0.1.1.tar.gz`, not the ZIP:

```r
install.packages("openxlsx2")
install.packages(file.choose(), repos = NULL, type = "source")
packageVersion("evanxlsx")
```

The same source archive can be copied between supported Windows, macOS and Linux systems.
R and dependencies must already be installed for offline installation of this package.
This is not an offline bundle of all dependencies. Do not keep using the old, unvalidated 0.1.0 archive.

### GitHub CLI

After logging into an account with repository read permission:

```sh
gh repo clone lianglunping/evanxlsx
cd evanxlsx
Rscript -e 'install.packages("openxlsx2", repos = "https://cloud.r-project.org")'
R CMD INSTALL .
```

To update, run `git pull --ff-only` in that checkout, followed by `R CMD INSTALL .`.

### Install directly from R

First configure a repository-readable `GITHUB_PAT` securely on your own computer:

```r
install.packages(c("openxlsx2", "remotes"))
remotes::install_github("lianglunping/evanxlsx", upgrade = "never")
```

Use `ref = "full commit SHA from the validation report"` to pin a code revision.
Never put credentials in scripts, logs, commits or chat. Private access is not changed by this package.

For a non-system library:

```r
lib <- path.expand("~/R/library")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
install.packages("openxlsx2", lib = lib)
install.packages(file.choose(), repos = NULL, type = "source", lib = lib)
```

Add that path to `.libPaths()` in subsequent sessions too; the package does not modify `.Rprofile`.

## Use

```r
evanxlsx::write_xlsx(list(variant_info = df, id83 = df1), "WES.xlsx")

evanxlsx::write_xlsx(
  list(variant_info = df, id83 = df1),
  "WES_Arial.xlsx",
  font = "Arial", font_size = 12, align = "left"
)
```

Defaults: Times New Roman, 11 pt, centered body and bold centered headers, blank NA cells,
frozen first row, three horizontal rules, no grid lines, wrapping, automatic widths capped at 40,
and no overwrite. `align` accepts `center`, `left`, `right`, or `justify`.
`header_align` separately controls headers. `font` also accepts `SimSun` or its Chinese alias.
`valign` accepts `center`, `top`, or `bottom`; `font_size` accepts 1–409 pt.

Set `widths` to `"auto"`, one numeric width or one width per column. `max_width` limits automatic
widths. `freeze`, `freeze_first_col`, `filter`, `three_line`, `grid_lines`, and `wrap` toggle
those individual features. Set `overwrite = TRUE` only to replace the whole workbook;
a unique `.bak` copy of the previous file is retained first. This is not sheet append/merge.

Session preferences:

```r
options(evanxlsx.font = "Arial", evanxlsx.font_size = 12, evanxlsx.align = "left")
```

The selected font name is recorded, not installed or embedded. Missing fonts/glyphs may be
substituted by Excel or the operating system. Short text may not visibly change under justification.

## Data handling

NA/NaN become value-less cells. Literal `"NA"`, `"001"`, long character IDs and `"=1+1"` remain
text, not numbers or formulas. Factors use their labels. Dates/times retain formatting;
Excel date-time cells do not store a timezone. Inputs are not modified in place.
Invalid sheet names, nested columns, infinite values and unsupported classes are rejected.

## Reproduce the tests

```sh
Rscript tools/check.R
Rscript tools/install_check.R
```

Install `openxlsx2`, `testthat`, `xml2`, `tibble` and `remotes` first. A local GitHub install
check additionally needs secure authorization and `EVANXLSX_REF`; absent credentials/ref
produce NOT_RUN for that route, never PASS. CI uses a short-lived read-only repository token.

The matrix requests Linux/current R, Windows/current R, Apple Silicon macOS/current R,
Intel macOS/current R, Linux/previous R, and Linux/R 4.1.3. Only completed successful jobs
count as validated environments. Each job builds/checks the package, installs from a source
folder, a local tarball and the exact private GitHub commit into isolated libraries,
then tests each installed copy in a fresh R process.

`tools/fixtures.R` constructs 240 rows × 11 columns deterministically: Chinese and English,
missing values, literal NA, empty strings, newlines, XML punctuation, 18-digit character IDs,
factors, logicals, dates and timestamps. There is no random sampling and no research data.
The 83 TEST_ID categories are synthetic, not mutation-signature channels. A separate
10,000-row × 6-column export checks larger input. Full mode creates 12 workbooks covering
three fonts and four alignments. XML assertions inspect font names, sizes, alignment and panes.
Every source cell is checked by type. Timing is a single runner observation, not a benchmark ranking.

Fresh `validation/local-*` and `validation/portable-*` directories retain CSV/RDS inputs,
workbooks, installation logs, assertions and actual dependency versions. CSV uses `<MISSING>`;
RDS is the type-preserving source. Automated structure checks are not manual visual acceptance
in every Excel version. See the workflow associated with the exact code commit.

## Sources

[openxlsx2 data writing](https://janmarvin.github.io/openxlsx2/reference/wb_add_data.html) ·
[Fonts](https://janmarvin.github.io/openxlsx2/reference/base_font-wb.html) ·
[Alignment](https://janmarvin.github.io/openxlsx2/reference/wb_add_cell_style.html) ·
[Private GitHub installation](https://remotes.r-lib.org/reference/install_github.html) ·
[R installation manual](https://cran.r-project.org/doc/manuals/r-release/R-admin.html)
