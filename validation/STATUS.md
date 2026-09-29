# Source candidate status — 2026-09-29

Version: 0.1.0. Source publication is not a claim of runtime validation.

## Repository

- Repository: https://github.com/lianglunping/evanxlsx
- Visibility verified before upload: PRIVATE.
- Default branch: main; connected account has push permission.
- The initial README commit is retained as the parent of the source upload.
- Only package code, documentation and synthetic tests are included.
- No research data, screenshots, credentials or font files are included.
- No stable Release or version tag is created by this upload.

## Validation scope

The original archives were checked against their delivery SHA-256 values:

- evanxlsx_source_0.1.0.zip: 9e6ea1bac4f21a3275d12500ef786dc1988845884a79c98d41600bfdce622864
- evanxlsx_0.1.0.tar.gz: cd30db6f4ebacb4e8ce4203a55b58c03806fac17831fbe0aaa6e66d18755a41b

R and Rscript are not available in the upload environment. No local native R
parse, R CMD INSTALL, R CMD build/check, testthat or Excel visual check is claimed.
The environment_probe.txt file records the earlier source-delivery environment.
static_audit.json and source_sha256.tsv describe the pre-commit source snapshot;
static checks are not R execution and do not query live publication/CI state.

The R functions and tests in this upload are unchanged from the supplied archive.
README, HTML documentation, NEWS and this status note were updated to reflect
repository creation and provide private-repository installation instructions.

## Runtime acceptance

Inspect the workflow run for the exact code commit:
https://github.com/lianglunping/evanxlsx/actions

The workflow requests checks on Linux, macOS and Windows. Its existence alone
is not evidence of a passing run. Logs and built archives are retained as
workflow artifacts when the workflow reaches that step. Any queued, blocked,
failed or unobserved run must not be represented as PASS.

To check locally, install development dependencies explicitly in R:

```r
install.packages(c("openxlsx2", "testthat", "xml2", "tibble"))
```

Then run from the package root:

```sh
Rscript tools/check.R
```

The script records dependency versions, source MD5, commands and logs in a fresh
validation/local-* directory. Only a clean R CMD check result writes PASS.
No random data are used. After installation, run Rscript tools/example.R and
inspect the generated synthetic workbook in the target Excel application.
The PDF manual is not built by the --no-manual check.
