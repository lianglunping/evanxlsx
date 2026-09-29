# Deterministic synthetic data; no research observations and no random draws.
# Chinese: he cheng ce shi shu ju; English: synthetic test data only.
make_fixture <- function(n = 240L) {
  i <- seq_len(n)
  d <- data.frame(
    Sample_ID = sprintf("%05d", i),
    Long_ID = paste0("12345678901234", sprintf("%04d", i %% 10000L)),
    Gene_ID = sprintf("SYNTH_G%04d", i),
    Annotation_ZH = rep(c("\u5408\u6210\u793a\u4f8b\uff1a\u6ce8\u91ca A",
                         "\u4e2d\u6587 English \u6df7\u6392", NA, "NA", ""), length.out = n),
    Annotation_EN = rep(c("Synthetic annotation A", "A&B < C", "=1+1",
                         "line one\nline two", "ordinary text"), length.out = n),
    Value = (i %% 41L - 20L) / 8,
    Count = as.integer(i %% 13L),
    Group = factor(rep(c("Control", "\u5904\u7406"), length.out = n)),
    Flag = rep(c(TRUE, FALSE, NA), length.out = n),
    Date = as.Date("2026-01-01") + i %% 90L,
    Timestamp = as.POSIXct("2026-01-01 00:00:00", tz = "UTC") + i * 60,
    stringsAsFactors = FALSE
  )
  d$Value[i %% 17L == 0L] <- NA_real_
  d$Value[i %% 29L == 0L] <- NaN
  d$Count[i %% 19L == 0L] <- NA_integer_
  d$Date[i %% 23L == 0L] <- as.Date(NA)
  d$Timestamp[i %% 31L == 0L] <- as.POSIXct(NA, tz = "UTC")
  id83 <- data.frame(Channel = sprintf("TEST_ID_%03d", 1:83),
                     Count = as.integer((1:83) %% 7L),
                     Meaning = "Synthetic category, not a biological signature")
  readme <- data.frame(
    Item = c("Data", "\u6570\u636e", "NA", "Fonts", "\u5b57\u4f53", "Version"),
    Explanation = c("Synthetic data only; no biological conclusions.",
                    "\u4ec5\u4e3a\u5408\u6210\u6d4b\u8bd5\u6570\u636e\uff0c\u975e\u5b9e\u9a8c\u7ed3\u679c\u3002",
                    "Missing values are blank; literal NA is text.",
                    "Font names are stored, not embedded; rendering may substitute fonts.",
                    "\u4e0d\u5b89\u88c5\u6216\u5d4c\u5165\u5b57\u4f53\uff0c\u663e\u793a\u4f9d\u8d56\u76ee\u6807\u7535\u8111\u3002",
                    "0.1.1"), stringsAsFactors = FALSE)
  list(variant_info = d, id83 = id83, Readme_ZH_EN = readme)
}
